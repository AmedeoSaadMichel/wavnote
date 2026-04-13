// File: ios/Runner/AudioTrimmerPlugin.swift
import Flutter
import AVFoundation
import Logging

class AudioTrimmerPlugin: NSObject, FlutterPlugin {

    private let logger = Logger(label: "com.wavnote.audio_trimmer")


  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wavnote/audio_trimmer",
      binaryMessenger: registrar.messenger()
    )
    let instance = AudioTrimmerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
      return
    }
    switch call.method {
    case "trimAudio":
      trimAudio(args: args, result: result)
    case "concatenateAudio":
      concatenateAudio(args: args, result: result)
    case "overwriteAudio":
      overwriteAudio(args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Trim

  private func trimAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let filePath = args["filePath"] as? String,
      let startTimeMs = args["startTimeMs"] as? Int,
      let durationMs = args["durationMs"] as? Int,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "trimAudio: missing params", details: nil))
      return
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
    let startTime = CMTime(value: CMTimeValue(startTimeMs), timescale: 1000)
    let trimDuration = CMTime(value: CMTimeValue(durationMs), timescale: 1000)
    let timeRange = CMTimeRange(start: startTime, duration: trimDuration)

    guard let exportSession = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let format = (args["format"] as? String) ?? "m4a"
    let fileType: AVFileType = format == "wav" ? .wav : .m4a
    let tempPath = outputPath + ".tmp"

    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = fileType
    exportSession.timeRange = timeRange

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
          }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          result(nil)
        } catch {
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Unknown export error",
          details: nil
        ))
      }
    }
  }

  // MARK: - Overwrite

  private func overwriteAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let originalPath = args["originalPath"] as? String,
      let insertionPath = args["insertionPath"] as? String,
      let startTimeMs = args["startTimeMs"] as? Int,
      let overwriteDurationMs = args["overwriteDurationMs"] as? Int,
      let outputPath = args["outputPath"] as? String,
      let format = args["format"] as? String
    else {
      self.logger.error("🔁 [OVERWRITE-iOS] ❌ INVALID_ARGS — args=\(args)")
      result(FlutterError(code: "INVALID_ARGS", message: "overwriteAudio: missing params", details: nil))
      return
    }

    self.logger.debug("🔁 [OVERWRITE-iOS] ▶️ START")
    self.logger.debug("🔁 [OVERWRITE-iOS]   originalPath   = \(originalPath)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   insertionPath  = \(insertionPath)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   startTimeMs    = \(startTimeMs)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   overwriteDurMs = \(overwriteDurationMs)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   outputPath     = \(outputPath)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   format         = \(format)")

    let fileManager = FileManager.default

    let originalExists = fileManager.fileExists(atPath: originalPath)
    let insertionExists = fileManager.fileExists(atPath: insertionPath)
    self.logger.debug("🔁 [OVERWRITE-iOS]   originalExists  = \(originalExists)")
    self.logger.debug("🔁 [OVERWRITE-iOS]   insertionExists = \(insertionExists)")

    guard originalExists else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Original file not found: \(originalPath)", details: nil))
      return
    }
    guard insertionExists else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Insertion file not found: \(insertionPath)", details: nil))
      return
    }

    let tempDir = NSTemporaryDirectory()
    let ext = format == "wav" ? "wav" : "m4a"
    let headPath = tempDir + "overwrite_head.\(ext)"
    let tailPath = tempDir + "overwrite_tail.\(ext)"

    try? fileManager.removeItem(atPath: headPath)
    try? fileManager.removeItem(atPath: tailPath)

    let originalAsset = AVURLAsset(url: URL(fileURLWithPath: originalPath))

    // Carica durata in modo asincrono per evitare kCMTimeIndefinite
    originalAsset.loadValuesAsynchronously(forKeys: ["duration"]) {
      let rawDurationSeconds = CMTimeGetSeconds(originalAsset.duration)
      let originalDurationMs: Int
      if rawDurationSeconds.isNaN || rawDurationSeconds.isInfinite || rawDurationSeconds < 0 {
        self.logger.warning("🔁 [OVERWRITE-iOS] ⚠️ Durata originale non valida (\(rawDurationSeconds))")
        originalDurationMs = 0
      } else {
        originalDurationMs = Int(rawDurationSeconds * 1000)
      }

      let tailStartTimeMs = startTimeMs + overwriteDurationMs
      self.logger.debug("🔁 [OVERWRITE-iOS]   originalDurationMs = \(originalDurationMs)")
      self.logger.debug("🔁 [OVERWRITE-iOS]   tailStartTimeMs    = \(tailStartTimeMs)")
      self.logger.debug("🔁 [OVERWRITE-iOS]   hasTail            = \(tailStartTimeMs < originalDurationMs)")

      let group = DispatchGroup()
      var headSuccess = false
      var tailSuccess = true

      // Estrai HEAD (0 → startTime)
      group.enter()
      self.exportSegmentiOS(
        asset: originalAsset,
        startTimeMs: 0,
        durationMs: startTimeMs,
        outputPath: headPath,
        format: format
      ) { success in
        self.logger.debug("🔁 [OVERWRITE-iOS]   headExport = \(success)")
        if success { headSuccess = true }
        group.leave()
      }

      // Estrai TAIL (tailStartTimeMs → fine)
      if tailStartTimeMs < originalDurationMs {
        group.enter()
        self.exportSegmentiOS(
          asset: originalAsset,
          startTimeMs: tailStartTimeMs,
          durationMs: originalDurationMs - tailStartTimeMs,
          outputPath: tailPath,
          format: format
        ) { success in
          self.logger.debug("🔁 [OVERWRITE-iOS]   tailExport = \(success)")
          if !success { tailSuccess = false }
          group.leave()
        }
      } else {
        self.logger.debug("🔁 [OVERWRITE-iOS]   ℹ️ Nessun tail (overwrite va oltre la fine)")
      }

      group.notify(queue: .main) {
        self.logger.debug("🔁 [OVERWRITE-iOS]   headSuccess=\(headSuccess) tailSuccess=\(tailSuccess)")

        if !headSuccess || !tailSuccess {
          result(FlutterError(code: "TRIM_FAILED", message: "Head/tail trim failed", details: nil))
          return
        }

        let headExists2  = fileManager.fileExists(atPath: headPath)
        let tailExists2  = fileManager.fileExists(atPath: tailPath)
        let insExists2   = fileManager.fileExists(atPath: insertionPath)
        self.logger.debug("🔁 [OVERWRITE-iOS]   headExists=\(headExists2) insExists=\(insExists2) tailExists=\(tailExists2)")

        var assetsToCombine: [String] = []
        if headExists2  { assetsToCombine.append(headPath) }
        if insExists2   { assetsToCombine.append(insertionPath) }
        else { self.logger.warning("🔁 [OVERWRITE-iOS] ⚠️ insertionPath sparito!") }
        if tailExists2  { assetsToCombine.append(tailPath) }

        self.logger.debug("🔁 [OVERWRITE-iOS]   assetsToCombine = \(assetsToCombine)")

        self.concatenateMultipleiOS(
          assetPaths: assetsToCombine,
          outputPath: outputPath,
          format: format,
          result: { res in
            try? fileManager.removeItem(atPath: headPath)
            try? fileManager.removeItem(atPath: tailPath)
            if let err = res as? FlutterError {
              self.logger.error("🔁 [OVERWRITE-iOS] ❌ concatenate error: \(err.message ?? "?")")
            } else {
              self.logger.info("🔁 [OVERWRITE-iOS] ✅ COMPLETATO → \(outputPath)")
            }
            result(res)
          }
        )
      }
    }
  }

  // Helper: esporta segmento
  private func exportSegmentiOS(
    asset: AVAsset,
    startTimeMs: Int,
    durationMs: Int,
    outputPath: String,
    format: String,
    completion: @escaping (Bool) -> Void
  ) {
    self.logger.debug("✂️ [SEGMENT-iOS] startMs=\(startTimeMs) durMs=\(durationMs) → \(outputPath)")
    if durationMs <= 0 {
      self.logger.debug("✂️ [SEGMENT-iOS] ℹ️ durationMs<=0, skip")
      completion(true)
      return
    }
    let startTime = CMTime(value: CMTimeValue(startTimeMs), timescale: 1000)
    let duration  = CMTime(value: CMTimeValue(durationMs),  timescale: 1000)
    let timeRange = CMTimeRange(start: startTime, duration: duration)

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
      self.logger.error("✂️ [SEGMENT-iOS] ❌ Impossibile creare AVAssetExportSession")
      completion(false)
      return
    }
    exportSession.outputURL      = URL(fileURLWithPath: outputPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a
    exportSession.timeRange      = timeRange
    exportSession.exportAsynchronously {
      let ok = exportSession.status == .completed
      self.logger.debug("✂️ [SEGMENT-iOS] status=\(exportSession.status.rawValue) err=\(exportSession.error?.localizedDescription ?? "none")")
      completion(ok)
    }
  }

  // Helper: concatena più file
  private func concatenateMultipleiOS(
    assetPaths: [String],
    outputPath: String,
    format: String,
    result: @escaping FlutterResult
  ) {
    self.logger.debug("🔗 [CONCAT-iOS] Concateno \(assetPaths.count) file → \(outputPath)")
    for (i, p) in assetPaths.enumerated() { self.logger.debug("🔗 [CONCAT-iOS]   [\(i)] \(p)") }

    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition track", details: nil))
      return
    }

    var cursor = CMTime.zero
    for (i, path) in assetPaths.enumerated() {
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      // Carica tracce in modo sincrono con semaforo
      let sem = DispatchSemaphore(value: 0)
      asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { sem.signal() }
      sem.wait()

      let duration = asset.duration
      let tracks   = asset.tracks(withMediaType: .audio)
      self.logger.debug("🔗 [CONCAT-iOS]   [\(i)] durSec=\(CMTimeGetSeconds(duration)) audioTracks=\(tracks.count)")

      guard let srcTrack = tracks.first else {
        self.logger.warning("🔗 [CONCAT-iOS]   [\(i)] ⚠️ Nessuna traccia, salto")
        continue
      }
      do {
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcTrack, at: cursor)
        cursor = CMTimeAdd(cursor, duration)
        self.logger.info("🔗 [CONCAT-iOS]   [\(i)] ✅ cursor=\(CMTimeGetSeconds(cursor))s")
      } catch {
        self.logger.error("🔗 [CONCAT-iOS]   [\(i)] ❌ INSERT_ERROR: \(error)")
        result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
        return
      }
    }

    self.logger.debug("🔗 [CONCAT-iOS] Durata totale = \(CMTimeGetSeconds(cursor))s")

    let concatPreset = format == "wav" ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: concatPreset) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let tempPath = outputPath + ".concat.tmp"
    exportSession.outputURL      = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          self.logger.info("🔗 [CONCAT-iOS] ✅ COMPLETATO → \(outputPath)")
          result(nil)
        } catch {
          self.logger.error("🔗 [CONCAT-iOS] ❌ FILE_ERROR: \(error)")
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        let errMsg = exportSession.error?.localizedDescription ?? "Unknown"
        self.logger.error("🔗 [CONCAT-iOS] ❌ EXPORT_FAILED: \(errMsg)")
        result(FlutterError(code: "EXPORT_FAILED", message: errMsg, details: nil))
      }
    }
  }

  // MARK: - Concatenate

  private func concatenateAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let basePath = args["basePath"] as? String,
      let appendPath = args["appendPath"] as? String,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "concatenateAudio: missing params", details: nil))
      return
    }

    let format = (args["format"] as? String) ?? "m4a"
    let fileType: AVFileType = format == "wav" ? .wav : .m4a

    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition track", details: nil))
      return
    }

    let assets: [AVURLAsset] = [
      AVURLAsset(url: URL(fileURLWithPath: basePath)),
      AVURLAsset(url: URL(fileURLWithPath: appendPath)),
    ]

    var cursor = CMTime.zero
    for asset in assets {
      let duration = asset.duration
      guard let srcTrack = asset.tracks(withMediaType: .audio).first else { continue }
      do {
        try track.insertTimeRange(
          CMTimeRange(start: .zero, duration: duration),
          of: srcTrack,
          at: cursor
        )
        cursor = CMTimeAdd(cursor, duration)
      } catch {
        result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
        return
      }
    }

    // AVAssetExportPresetPassthrough non funziona con AVMutableComposition —
    // una composition virtuale richiede ri-codifica; usiamo AVAssetExportPresetAppleM4A.
    let concatPreset = format == "wav" ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A
    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: concatPreset
    ) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let tempPath = outputPath + ".concat.tmp"
    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = fileType

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
          }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          result(nil)
        } catch {
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Unknown export error",
          details: nil
        ))
      }
    }
  }
}
