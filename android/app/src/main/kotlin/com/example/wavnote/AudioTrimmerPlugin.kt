// File: android/app/src/main/kotlin/com/example/wavnote/AudioTrimmerPlugin.kt
package com.example.wavnote

import android.media.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AudioTrimmerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "wavnote/audio_trimmer")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "trimAudio" -> {
        val filePath = call.argument<String>("filePath") ?: return result.error("INVALID_ARGS", "filePath missing", null)
        val durationMs = call.argument<Int>("durationMs") ?: return result.error("INVALID_ARGS", "durationMs missing", null)
        val format = call.argument<String>("format") ?: "m4a"
        val outputPath = call.argument<String>("outputPath") ?: return result.error("INVALID_ARGS", "outputPath missing", null)
        try {
          if (format == "wav") {
            trimWav(filePath, durationMs, outputPath)
          } else {
            trimMuxed(filePath, durationMs.toLong() * 1000L, outputPath, format)
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("TRIM_FAILED", e.message, null)
        }
      }
      "concatenateAudio" -> {
        val basePath = call.argument<String>("basePath") ?: return result.error("INVALID_ARGS", "basePath missing", null)
        val appendPath = call.argument<String>("appendPath") ?: return result.error("INVALID_ARGS", "appendPath missing", null)
        val outputPath = call.argument<String>("outputPath") ?: return result.error("INVALID_ARGS", "outputPath missing", null)
        val format = call.argument<String>("format") ?: "m4a"
        try {
          if (format == "wav") {
            concatenateWav(basePath, appendPath, outputPath)
          } else {
            concatenateMuxed(basePath, appendPath, outputPath, format)
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("CONCAT_FAILED", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  // ── Trim: MediaExtractor + MediaMuxer (M4A / FLAC) ──────────────────────────

  private fun trimMuxed(inputPath: String, endUs: Long, outputPath: String, format: String) {
    val tempPath = "$outputPath.tmp"
    val extractor = MediaExtractor()
    extractor.setDataSource(inputPath)

    val muxerFormat = if (format == "flac") MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
                      else MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
    val muxer = MediaMuxer(tempPath, muxerFormat)

    val trackMap = mutableMapOf<Int, Int>()
    for (i in 0 until extractor.trackCount) {
      val fmt = extractor.getTrackFormat(i)
      val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
      if (mime.startsWith("audio/")) {
        extractor.selectTrack(i)
        trackMap[i] = muxer.addTrack(fmt)
      }
    }

    muxer.start()
    val buffer = ByteBuffer.allocate(1024 * 1024)
    val info = MediaCodec.BufferInfo()

    for ((_, muxTrack) in trackMap) {
      extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
      while (true) {
        info.offset = 0
        info.size = extractor.readSampleData(buffer, 0)
        if (info.size < 0) break
        info.presentationTimeUs = extractor.sampleTime
        if (info.presentationTimeUs > endUs) break
        info.flags = extractor.sampleFlags
        muxer.writeSampleData(muxTrack, buffer, info)
        extractor.advance()
      }
    }

    muxer.stop()
    muxer.release()
    extractor.release()

    atomicReplace(tempPath, outputPath)
  }

  // ── Trim: WAV byte truncation ────────────────────────────────────────────────

  private fun trimWav(inputPath: String, durationMs: Int, outputPath: String) {
    val src = File(inputPath)
    val bytes = src.readBytes()
    val sampleRate = ByteBuffer.wrap(bytes, 24, 4).order(ByteOrder.LITTLE_ENDIAN).int
    val bitsPerSample = ByteBuffer.wrap(bytes, 34, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
    val channels = ByteBuffer.wrap(bytes, 22, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
    val dataOffset = findWavDataOffset(bytes)
    val bytesPerSample = bitsPerSample / 8
    val bytesPerSecond = sampleRate * channels * bytesPerSample
    val keepBytes = (bytesPerSecond * durationMs / 1000).toLong()
    val newDataSize = minOf(keepBytes, (bytes.size - dataOffset).toLong()).toInt()

    val tempPath = "$outputPath.tmp"
    FileOutputStream(tempPath).use { fos ->
      fos.write(bytes, 0, dataOffset + newDataSize)
    }
    updateWavHeader(tempPath, newDataSize)
    atomicReplace(tempPath, outputPath)
  }

  private fun findWavDataOffset(bytes: ByteArray): Int {
    var i = 12
    while (i < bytes.size - 8) {
      val id = String(bytes, i, 4, Charsets.US_ASCII)
      val size = ByteBuffer.wrap(bytes, i + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
      if (id == "data") return i + 8
      i += 8 + size
    }
    return 44
  }

  private fun updateWavHeader(path: String, dataSize: Int) {
    RandomAccessFile(path, "rw").use { raf ->
      raf.seek(4)
      val chunkSize = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(dataSize + 36).array()
      raf.write(chunkSize)
      val dataOffset = findWavDataOffset(File(path).readBytes())
      raf.seek((dataOffset - 4).toLong())
      val subChunk2Size = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(dataSize).array()
      raf.write(subChunk2Size)
    }
  }

  // ── Concatenate: MediaMuxer (M4A / FLAC) ─────────────────────────────────────

  private fun concatenateMuxed(basePath: String, appendPath: String, outputPath: String, format: String) {
    val tempPath = "$outputPath.concat.tmp"
    val muxerFormat = if (format == "flac") MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM
                      else MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
    val muxer = MediaMuxer(tempPath, muxerFormat)
    val buffer = ByteBuffer.allocate(1024 * 1024)
    val info = MediaCodec.BufferInfo()
    var timeOffsetUs = 0L
    var muxStarted = false

    for (inputPath in listOf(basePath, appendPath)) {
      val extractor = MediaExtractor()
      extractor.setDataSource(inputPath)
      var muxTrack = -1
      for (i in 0 until extractor.trackCount) {
        val fmt = extractor.getTrackFormat(i)
        val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("audio/")) {
          extractor.selectTrack(i)
          if (muxTrack == -1) muxTrack = muxer.addTrack(fmt)
          break
        }
      }
      if (muxTrack == -1) { extractor.release(); continue }
      if (!muxStarted) { muxer.start(); muxStarted = true }

      var lastPts = 0L
      extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
      while (true) {
        info.offset = 0
        info.size = extractor.readSampleData(buffer, 0)
        if (info.size < 0) break
        info.presentationTimeUs = extractor.sampleTime + timeOffsetUs
        lastPts = info.presentationTimeUs
        info.flags = extractor.sampleFlags
        muxer.writeSampleData(muxTrack, buffer, info)
        extractor.advance()
      }
      timeOffsetUs = lastPts + 1
      extractor.release()
    }

    muxer.stop()
    muxer.release()
    atomicReplace(tempPath, outputPath)
  }

  // ── Concatenate: WAV PCM splice ───────────────────────────────────────────────

  private fun concatenateWav(basePath: String, appendPath: String, outputPath: String) {
    val baseBytes = File(basePath).readBytes()
    val appendBytes = File(appendPath).readBytes()
    val baseDataOffset = findWavDataOffset(baseBytes)
    val appendDataOffset = findWavDataOffset(appendBytes)
    val baseDataSize = baseBytes.size - baseDataOffset
    val appendDataSize = appendBytes.size - appendDataOffset
    val totalDataSize = baseDataSize + appendDataSize

    val tempPath = "$outputPath.concat.tmp"
    FileOutputStream(tempPath).use { fos ->
      fos.write(baseBytes, 0, baseDataOffset + baseDataSize)
      fos.write(appendBytes, appendDataOffset, appendDataSize)
    }
    updateWavHeader(tempPath, totalDataSize)
    atomicReplace(tempPath, outputPath)
  }

  // ── Utility ──────────────────────────────────────────────────────────────────

  private fun atomicReplace(srcPath: String, dstPath: String) {
    val src = File(srcPath)
    val dst = File(dstPath)
    if (dst.exists()) dst.delete()
    src.renameTo(dst)
  }
}
