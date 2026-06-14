package studio.unicom.acr

import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.serialization.json.Json
import studio.unicom.acr.format.AudioSource
import studio.unicom.acr.format.Format
import studio.unicom.acr.output.CallMetadataJson
import studio.unicom.acr.output.DaysRetention
import studio.unicom.acr.output.NoRetention
import studio.unicom.acr.output.Retention
import studio.unicom.acr.service.ManualRecordingService

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "studio.unicom.acr/native"
        private const val REQUEST_CODE_PICK_DIRECTORY = 1001
        private val JSON_FORMAT = Json { ignoreUnknownKeys = true }

        private fun inferMimeType(filename: String): String {
            val lower = filename.lowercase()
            return when {
                lower.endsWith(".oga") || lower.endsWith(".ogg") || lower.endsWith(".opus") -> "audio/ogg"
                lower.endsWith(".m4a") || lower.endsWith(".aac") || lower.endsWith(".mp4") -> "audio/mp4"
                lower.endsWith(".flac") -> "audio/flac"
                lower.endsWith(".wav") || lower.endsWith(".wave") -> "audio/x-wav"
                lower.endsWith(".amr_nb") -> "audio/amr-nb"
                lower.endsWith(".amr") || lower.endsWith(".amr_wb") -> "audio/amr-wb"
                else -> "application/octet-stream"
            }
        }
    }

    private lateinit var prefs: Preferences
    private var pendingResult: MethodChannel.Result? = null
    private val manualRecorder = lazy { ManualRecordingService(this) }
    private val channel by lazy { MethodChannel(getFlutterEngine()!!.dartExecutor.binaryMessenger, CHANNEL) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = Preferences(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPreferences" -> getPreferences(result)
                "setPreference" -> setPreference(call, result)
                "getRecordings" -> getRecordings(result)
                "deleteRecording" -> deleteRecording(call, result)
                "pickOutputDirectory" -> pickOutputDirectory(result)
                "getRecordingState" -> getRecordingState(result)
                "startManualRecording" -> startManualRecording(call, result)
                "stopManualRecording" -> stopManualRecording(result)
                "pauseManualRecording" -> pauseManualRecording(result)
                "resumeManualRecording" -> resumeManualRecording(result)
                "getManualRecordingState" -> getManualRecordingState(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getPreferences(result: MethodChannel.Result) {
        try {
            val map = mutableMapOf<String, Any?>()
            map["call_recording"] = prefs.isCallRecordingEnabled
            map["format_name"] = prefs.format?.name
            map["audio_source"] = prefs.audioSource?.name
            map["filename_template"] = prefs.filenameTemplate?.toString()
            map["min_duration"] = prefs.minDuration
            map["output_retention"] = when (val r = prefs.outputRetention) {
                is DaysRetention -> r.days.toInt()
                is NoRetention -> 0
                null -> 0
            }
            map["record_dialing_state"] = prefs.recordDialingState
            map["record_telecom_apps"] = prefs.recordTelecomApps
            map["write_metadata"] = prefs.writeMetadata
            map["notification_open_dir"] = prefs.notificationOpenDir
            map["force_direct_boot"] = prefs.forceDirectBoot
            map["debug_mode"] = prefs.isDebugMode

            // Format-specific params
            val format = prefs.format
            if (format != null) {
                map["bit_rate"] = prefs.getFormatParam(format)?.toInt()
                map["sample_rate"] = prefs.getFormatSampleRate(format)?.toInt()
            }
            map["output_dir"] = prefs.outputDir?.toString()

            result.success(map)
        } catch (e: Exception) {
            result.error("PREFERENCES_ERROR", e.message, null)
        }
    }

    private fun setPreference(call: MethodCall, result: MethodChannel.Result) {
        try {
            val key = call.argument<String>("key") ?: throw IllegalArgumentException("Missing key")
            val value = call.argument<Any>("value")

            when (key) {
                "call_recording" -> prefs.isCallRecordingEnabled = value as Boolean
                "format_name" -> prefs.format = (value as? String)?.let { Format.getByName(it) }
                "audio_source" -> prefs.audioSource = (value as? String)?.let { AudioSource.getByName(it) }
                "filename_template" -> {
                    val templateStr = value as? String
                    prefs.filenameTemplate = if (templateStr.isNullOrEmpty()) null
                    else studio.unicom.acr.template.Template(templateStr)
                }
                "min_duration" -> prefs.minDuration = (value as Int)
                "output_retention" -> {
                    val days = (value as? Int) ?: 0
                    prefs.outputRetention = if (days <= 0) null else Retention.fromRawPreferenceValue(days.toUInt())
                }
                "record_rules" -> {
                    val json = value as? String
                    if (!json.isNullOrEmpty()) {
                        prefs.recordRules = Json.decodeFromString(json)
                    }
                }
                "record_dialing_state" -> prefs.recordDialingState = value as Boolean
                "record_telecom_apps" -> prefs.recordTelecomApps = value as Boolean
                "write_metadata" -> prefs.writeMetadata = value as Boolean
                "notification_open_dir" -> prefs.notificationOpenDir = value as Boolean
                "force_direct_boot" -> prefs.forceDirectBoot = value as Boolean
                "debug_mode" -> prefs.isDebugMode = value as Boolean

                // Shared settings with Flutter UI
                "bit_rate" -> {
                    val format = prefs.format ?: throw IllegalStateException("No format selected")
                    prefs.setFormatParam(format, (value as Int).toUInt())
                }
                "sample_rate" -> {
                    val format = prefs.format ?: throw IllegalStateException("No format selected")
                    prefs.setFormatSampleRate(format, (value as Int).toUInt())
                }
                "recording_path" -> {
                    val path = value as? String
                    prefs.outputDir = if (path.isNullOrEmpty()) null else Uri.parse(path)
                }

                else -> throw IllegalArgumentException("Unknown preference key: $key")
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("PREFERENCES_ERROR", e.message, null)
        }
    }

    private fun getRecordings(result: MethodChannel.Result) {
        try {
            val files = mutableListOf<Map<String, Any?>>()
            val outputDir = prefs.outputDir
            if (outputDir == null) {
                result.success(files)
                return
            }

            val docDir = DocumentFile.fromTreeUri(this, outputDir)
            if (docDir != null && docDir.exists()) {
                collectRecordings(docDir.listFiles().filter { it.isFile && it.name != null }, files, false)
            }

            val defaultDir = prefs.defaultOutputDir
            if (defaultDir.exists()) {
                collectRecordings(
                    (defaultDir.listFiles() ?: emptyArray()).filter { it.isFile }.map { SafFile(it.name, it.toURI().toString(), it.length(), it.lastModified(), null) },
                    files, true
                )
            }

            files.sortByDescending { it["date"] as? Long ?: 0 }
            result.success(files)
        } catch (e: Exception) {
            result.error("RECORDINGS_ERROR", e.message, null)
        }
    }

    private data class SafFile(val name: String, val uri: String, val size: Long, val date: Long, val rawMimeType: String?)

    private fun collectRecordings(
        items: List<Any>,
        files: MutableList<Map<String, Any?>>,
        isDefaultDir: Boolean,
    ) {
        // Group files by base name (without extension)
        val groups = mutableMapOf<String, MutableList<SafFile>>()
        for (item in items) {
            val f = when (item) {
                is DocumentFile -> SafFile(item.name!!, item.uri.toString(), item.length(), item.lastModified(), item.type)
                is SafFile -> item
                else -> continue
            }
            val base = f.name.substringBeforeLast('.')
            groups.getOrPut(base) { mutableListOf() }.add(f)
        }

        for ((_, group) in groups) {
            // Find JSON metadata file
            val jsonFile = group.find { it.name.endsWith(".json") }
            if (jsonFile == null) continue

            // Parse metadata from JSON
            val metadata = try {
                val jsonText = if (isDefaultDir) {
                    java.io.File(jsonFile.uri.removePrefix("file://")).readText()
                } else {
                    contentResolver.openInputStream(Uri.parse(jsonFile.uri))?.use { String(it.readBytes()) }
                }
                if (jsonText != null) JSON_FORMAT.decodeFromString<CallMetadataJson>(jsonText) else null
            } catch (_: Exception) { null }

            // Find audio file (not .json/.log/.txt)
            val audioFile = group.find { f ->
                val n = f.name
                !n.endsWith(".json") && !n.endsWith(".log") && !n.endsWith(".txt")
            }
            if (audioFile == null) continue

            // MIME type from metadata (source of truth) or SAF or extension fallback
            val mimeType = metadata?.output?.format?.mimeTypeContainer
                ?: audioFile.rawMimeType
                ?: inferMimeType(audioFile.name)

            val isManual = metadata?.packageName == "manual"
            val direction = metadata?.direction?.name

            files.add(mapOf(
                "uri" to audioFile.uri,
                "name" to audioFile.name,
                "size" to audioFile.size,
                "date" to (metadata?.timestampUnixMs ?: audioFile.date),
                "mimeType" to mimeType,
                "isManual" to isManual,
                "direction" to direction,
            ))
        }
    }

    private fun deleteRecording(call: MethodCall, result: MethodChannel.Result) {
        try {
            val uriStr = call.argument<String>("uri") ?: throw IllegalArgumentException("Missing uri")
            val uri = Uri.parse(uriStr)
            val docFile = DocumentFile.fromSingleUri(this, uri)
            var deleted = docFile?.delete() ?: false
            // Also delete companion files (JSON metadata, logs)
            val name = docFile?.name ?: uri.lastPathSegment ?: ""
            val baseName = name.substringBeforeLast('.')
            if (baseName.isNotEmpty()) {
                val parent = docFile?.parentFile
                val companions = listOf("$baseName.json", "$baseName.log", "$baseName.logcat")
                parent?.listFiles()?.filter { it.name in companions }?.forEach { it.delete() }
            }
            result.success(deleted)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    @Deprecated("Use registerForActivityResult when FlutterActivity extends ComponentActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DIRECTORY) {
            val result = pendingResult ?: return
            pendingResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                prefs.outputDir = data.data
                result.success(data.data.toString())
            } else {
                result.success(null)
            }
        }
    }

    private fun pickOutputDirectory(result: MethodChannel.Result) {
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
    }

    private fun startManualRecording(call: MethodCall, result: MethodChannel.Result) {
        try {
            val ok = manualRecorder.value.start()
            if (ok) {
                manualRecorder.value.onStateChanged = { state, duration ->
                    runOnUiThread {
                        channel.invokeMethod("onRecordingStateChanged", mapOf(
                            "state" to state.name,
                            "duration" to duration,
                            "isManual" to true,
                        ))
                    }
                }
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun stopManualRecording(result: MethodChannel.Result) {
        try {
            val ok = manualRecorder.isInitialized() && manualRecorder.value.stop()
            result.success(ok)
        } catch (e: Exception) {
            result.error("STOP_FAILED", e.message, null)
        }
    }

    private fun pauseManualRecording(result: MethodChannel.Result) {
        try {
            val ok = manualRecorder.isInitialized() && manualRecorder.value.pause()
            result.success(ok)
        } catch (e: Exception) {
            result.error("PAUSE_FAILED", e.message, null)
        }
    }

    private fun resumeManualRecording(result: MethodChannel.Result) {
        try {
            val ok = manualRecorder.isInitialized() && manualRecorder.value.resume()
            result.success(ok)
        } catch (e: Exception) {
            result.error("RESUME_FAILED", e.message, null)
        }
    }

    private fun getManualRecordingState(result: MethodChannel.Result) {
        if (!manualRecorder.isInitialized()) {
            result.success(mapOf("state" to "IDLE", "duration" to 0L, "isManual" to true))
            return
        }
        val s = manualRecorder.value
        result.success(mapOf(
            "state" to s.state.name,
            "duration" to s.currentDurationMs,
            "isManual" to true,
        ))
    }

    private fun getRecordingState(result: MethodChannel.Result) {
        val state = prefs.recordingState
        result.success(mapOf(
            "isRecording" to state["isRecording"],
            "callInfo" to mapOf("phoneNumber" to state["phoneNumber"]),
            "filename" to null,
            "duration" to 0L,
        ))
    }
}
