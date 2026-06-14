/*
 * SPDX-FileCopyrightText: 2026 Andrew Gunnerson
 * SPDX-FileCopyrightText: 2026 easterNday
 * SPDX-License-Identifier: GPL-3.0-only
 */

package studio.unicom.acr.service

import android.util.Log
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * RMS-based silence detector for PCM audio data.
 *
 * Replaces the previous pure-zero detection with a configurable RMS threshold
 * approach. Audio frames are sampled at regular intervals; each frame's RMS
 * level is compared against a dBFS threshold. If the proportion of silent
 * frames exceeds [silenceRatio], the recording is considered pure silence.
 */
class SilenceDetector(
    private val sampleRate: Int,
    private val channels: Int = 1,
    private val bitsPerSample: Int = 16,
    private val silenceThresholdDb: Double = DEFAULT_THRESHOLD_DB,
    private val frameIntervalMs: Long = DEFAULT_FRAME_INTERVAL_MS,
    private val silenceRatio: Double = DEFAULT_SILENCE_RATIO,
) {
    companion object {
        private const val TAG = "SilenceDetector"
        const val DEFAULT_THRESHOLD_DB = -40.0
        const val DEFAULT_FRAME_INTERVAL_MS = 100L
        const val DEFAULT_SILENCE_RATIO = 0.90
        private const val PCM16_MAX = 32767.0
    }

    var totalFrames: Long = 0
        private set
    var silentFrames: Long = 0
        private set

    private var frameSampleCount: Long = 0
    private var frameSumSquares: Double = 0.0
    private val samplesPerFrame: Int =
        (sampleRate * channels * frameIntervalMs / 1000).toInt()

    fun process(buffer: java.nio.ByteBuffer, offset: Int = 0, byteLength: Int = buffer.limit() - offset) {
        val numSamples = byteLength / (bitsPerSample / 8)
        var sampleOffset = offset

        for (i in 0 until numSamples) {
            val sample = buffer.getShort(sampleOffset).toDouble()
            sampleOffset += 2

            frameSumSquares += sample * sample
            frameSampleCount++

            if (frameSampleCount >= samplesPerFrame) {
                finishFrame()
            }
        }
    }

    fun finish(): SilenceResult {
        if (frameSampleCount > 0) finishFrame()

        val isPureSilence = if (totalFrames > 0) {
            silentFrames.toDouble() / totalFrames.toDouble() >= silenceRatio
        } else {
            true
        }

        Log.d(TAG, "Silence: ${silentFrames}/${totalFrames} silent frames, " +
            "threshold=${silenceThresholdDb}dBFS, result=${if (isPureSilence) "SILENT" else "HAS_AUDIO"}")

        return SilenceResult(isPureSilence, totalFrames, silentFrames,
            if (totalFrames > 0) silentFrames.toDouble() / totalFrames else 1.0,
            silenceThresholdDb)
    }

    fun reset() {
        totalFrames = 0; silentFrames = 0; frameSampleCount = 0; frameSumSquares = 0.0
    }

    private fun finishFrame() {
        totalFrames++
        val rms = sqrt(frameSumSquares / frameSampleCount)
        val dbfs = if (rms > 0.0) 20.0 * log10(rms / PCM16_MAX) else Double.NEGATIVE_INFINITY
        if (dbfs < silenceThresholdDb) silentFrames++
        frameSampleCount = 0; frameSumSquares = 0.0
    }
}

data class SilenceResult(
    val isPureSilence: Boolean,
    val totalFrames: Long,
    val silentFrames: Long,
    val silentRatio: Double,
    val thresholdDb: Double,
)
