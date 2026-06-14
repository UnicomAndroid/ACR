/*
 * SPDX-FileCopyrightText: 2026 easterNday
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.service

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import studio.unicom.acr.output.OutputFile

/**
 * Manual (in-app) recording service using the same AudioRecord + MediaCodec
 * pipeline as call recording. Creates a RecorderThread with null Call.
 */
class ManualRecordingService(private val context: Context) {
    companion object {
        private const val TAG = "ManualRecordingService"
    }
    enum class State { IDLE, RECORDING, PAUSED, STOPPING, ERROR }

    @Volatile var state: State = State.IDLE; private set
    @Volatile var currentDurationMs: Long = 0L; private set
    var onStateChanged: ((State, Long) -> Unit)? = null

    private var recorderThread: RecorderThread? = null
    private var recordingStartTime: Long = 0L
    private var totalPausedMs: Long = 0L
    private var pauseStartTime: Long = 0L
    @Volatile private var monitorRunning = false

    private val listener = object : RecorderThread.OnRecordingCompletedListener {
        override fun onRecordingStateChanged(thread: RecorderThread) {
            if (thread.isPaused) state = State.PAUSED
            else state = State.RECORDING
            updateState()
        }
        override fun onRecordingCompleted(
            thread: RecorderThread, file: OutputFile?,
            additionalFiles: List<OutputFile>, status: RecorderThread.Status,
        ) {
            monitorRunning = false
            state = State.IDLE; currentDurationMs = 0L; updateState()
            Log.i(TAG, "Manual recording completed: $status")
        }
    }

    fun start(): Boolean {
        if (state != State.IDLE) return false
        try {
            val thread = RecorderThread(
                context = context, listener = listener, parentCall = null,
                isManual = true,
                manualAudioSources = listOf(MediaRecorder.AudioSource.MIC, MediaRecorder.AudioSource.DEFAULT),
            )
            recorderThread = thread
            recordingStartTime = System.currentTimeMillis()
            totalPausedMs = 0L
            state = State.RECORDING
            monitorRunning = true
            startMonitor()
            thread.start()
            Log.i(TAG, "Manual recording started")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start manual recording", e)
            state = State.ERROR; return false
        }
    }

    fun pause(): Boolean {
        if (state != State.RECORDING) return false
        recorderThread?.let { it.isPaused = true }
        pauseStartTime = System.currentTimeMillis()
        state = State.PAUSED
        updateState(); return true
    }

    fun resume(): Boolean {
        if (state != State.PAUSED) return false
        recorderThread?.let { it.isPaused = false }
        totalPausedMs += System.currentTimeMillis() - pauseStartTime
        state = State.RECORDING
        updateState(); return true
    }

    fun stop(): Boolean {
        if (state == State.IDLE || state == State.STOPPING) return false
        monitorRunning = false
        state = State.STOPPING; updateState()
        recorderThread?.cancel(); return true
    }

    private fun startMonitor() {
        Thread {
            while (monitorRunning) {
                if (state == State.RECORDING)
                    currentDurationMs = System.currentTimeMillis() - recordingStartTime - totalPausedMs
                updateState()
                try { Thread.sleep(100) } catch (_: InterruptedException) { break }
            }
        }.start()
    }

    private fun updateState() {
        onStateChanged?.invoke(state, currentDurationMs)
    }
}
