// File: macos/Runner/AudioTrimmerPlugin.swift
// Trim e concatenazione audio per macOS — identico alla versione iOS.

import Cocoa
import FlutterMacOS
import AVFoundation
import Logging

class AudioTrimmerPlugin: NSObject, FlutterPlugin {

    private let logger = Logger(label: "com.wavnote.macos.audio_trimmer")


  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wavnote/audio_trimmer",
      binaryMessenger: registrar.messenger
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
      self.logger.debug("✂️ [NATIVE-macOS] trimAudio: INVALID_ARGS — args=\(args)")
      result(FlutterError(code: "INVALID_ARGS", message: "trimAudio: missing params", details: nil))
      return
    }
    self.logger.debug("✂️ [NATIVE-macOS] trimAudio: filePath=\(filePath) startTime=\(startTimeMs) durationMs=\(durationMs) outputPath=\(outputPath)")

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
          self.logger.debug("✂️ [NATIVE-macOS] trimAudio: COMPLETED → \(outputPath)")
          result(nil)
        } catch {
          self.logger.error("✂️ [NATIVE-macOS] trimAudio: FILE_ERROR → \(error)")
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        self.logger.error("✂️ [NATIVE-macOS] trimAudio: EXPORT_FAILED → \(exportSession.error?.localizedDescription ?? "Unknown")")
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Unknown export error",
          details: nil
        ))
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

  // MARK: - Overwrite

  private func overwriteAudio(args: [String: Any], result: @escaping FlutterResult) {
    // 1. Estrai parametri
    guard
      let originalPath = args["originalPath"] as? String,
      let insertionPath = args["insertionPath"] as? String,
      let startTimeMs = args["startTimeMs"] as? Int,
      let overwriteDurationMs = args["overwriteDurationMs"] as? Int,
      let outputPath = args["outputPath"] as? String,
      let format = args["format"] as? String
    else {
      self.logger.error("🔁 [OVERWRITE] ❌ INVALID_ARGS — args=\(args)")
      result(FlutterError(code: "INVALID_ARGS", message: "overwriteAudio: missing params", details: nil))
      return
    }

    self.logger.debug("🔁 [OVERWRITE] ▶️ START")
    self.logger.debug("🔁 [OVERWRITE]   originalPath   = \(originalPath)")
    self.logger.debug("🔁 [OVERWRITE]   insertionPath  = \(insertionPath)")
    self.logger.debug("🔁 [OVERWRITE]   startTimeMs    = \(startTimeMs)")
    self.logger.debug("🔁 [OVERWRITE]   overwriteDurMs = \(overwriteDurationMs)")
    self.logger.debug("🔁 [OVERWRITE]   outputPath     = \(outputPath)")
    self.logger.debug("🔁 [OVERWRITE]   format         = \(format)")

    let fileManager = FileManager.default

    // Verifica esistenza file sorgente
    let originalExists = fileManager.fileExists(atPath: originalPath)
    let insertionExists = fileManager.fileExists(atPath: insertionPath)
    self.logger.debug("🔁 [OVERWRITE]   originalExists  = \(originalExists)")
    self.logger.debug("🔁 [OVERWRITE]   insertionExists = \(insertionExists)")

    guard originalExists else {
      self.logger.error("🔁 [OVERWRITE] ❌ File originale non trovato!")
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Original file does not exist: \(originalPath)", details: nil))
      return
    }
    guard insertionExists else {
      self.logger.error("🔁 [OVERWRITE] ❌ File insertion non trovato: \(insertionPath)")
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Insertion file does not exist: \(insertionPath)", details: nil))
      return
    }

    let tempDir = NSTemporaryDirectory()
    let ext = format == "wav" ? "wav" : "m4a"
    let headPath = tempDir + "head.\(ext)"
    let tailPath = tempDir + "tail.\(ext)"

    // Rimuovi file temporanei vecchi se esistono
    try? fileManager.removeItem(atPath: headPath)
    try? fileManager.removeItem(atPath: tailPath)

    let originalAsset = AVURLAsset(url: URL(fileURLWithPath: originalPath))

    // FIX: Carica la durata in modo asincrono prima di procedere
    // (AVURLAsset.duration può essere kCMTimeIndefinite se letto sincronicamente)
    originalAsset.loadValuesAsynchronously(forKeys: ["duration"]) {
      let durationStatus = originalAsset.statusOfValue(forKey: "duration", error: nil)
      let rawDurationSeconds = CMTimeGetSeconds(originalAsset.duration)

      self.logger.debug("🔁 [OVERWRITE]   durationStatus    = \(durationStatus.rawValue)")
      self.logger.debug("🔁 [OVERWRITE]   rawDurationSeconds= \(rawDurationSeconds)")

      // Gestisci durata non valida (nan/infinito/negativo)
      let originalDurationMs: Int
      if rawDurationSeconds.isNaN || rawDurationSeconds.isInfinite || rawDurationSeconds < 0 {
        self.logger.warning("🔁 [OVERWRITE] ⚠️ Durata originale non valida (\(rawDurationSeconds)) — uso fallback 0")
        originalDurationMs = 0
      } else {
        originalDurationMs = Int(rawDurationSeconds * 1000)
      }

      let tailStartTimeMs = startTimeMs + overwriteDurationMs

      self.logger.debug("🔁 [OVERWRITE]   originalDurationMs = \(originalDurationMs)")
      self.logger.debug("🔁 [OVERWRITE]   tailStartTimeMs    = \(tailStartTimeMs)")
      self.logger.debug("🔁 [OVERWRITE]   hasTail            = \(tailStartTimeMs < originalDurationMs)")

      let group = DispatchGroup()
      var headSuccess = false
      var tailSuccess = true

      // 2. Taglia Head (0 -> startTime)
      group.enter()
      self.exportSegment(
        asset: originalAsset,
        startTimeMs: 0,
        durationMs: startTimeMs,
        outputPath: headPath,
        format: format
      ) { success in
        self.logger.debug("🔁 [OVERWRITE]   headExport success = \(success)")
        if success { headSuccess = true }
        group.leave()
      }

      // 3. Taglia Tail (tailStartTimeMs -> fine)
      if tailStartTimeMs < originalDurationMs {
        group.enter()
        self.exportSegment(
          asset: originalAsset,
          startTimeMs: tailStartTimeMs,
          durationMs: originalDurationMs - tailStartTimeMs,
          outputPath: tailPath,
          format: format
        ) { success in
          self.logger.debug("🔁 [OVERWRITE]   tailExport success = \(success)")
          if !success { tailSuccess = false }
          group.leave()
        }
      } else {
        self.logger.debug("🔁 [OVERWRITE]   ℹ️ Nessun tail da estrarre (overwrite va oltre la fine)")
      }

      // 4. Attendi il completamento dei tagli
      group.notify(queue: .main) {
        self.logger.debug("🔁 [OVERWRITE]   headSuccess = \(headSuccess), tailSuccess = \(tailSuccess)")

        if !headSuccess || !tailSuccess {
          self.logger.error("🔁 [OVERWRITE] ❌ TRIM_FAILED")
          result(FlutterError(code: "TRIM_FAILED", message: "Head or tail trim failed", details: nil))
          return
        }

        let headExists2 = fileManager.fileExists(atPath: headPath)
        let tailExists2 = fileManager.fileExists(atPath: tailPath)
        let insertionExists2 = fileManager.fileExists(atPath: insertionPath)
        self.logger.debug("🔁 [OVERWRITE]   headPath exists    = \(headExists2)  (\(headPath))")
        self.logger.debug("🔁 [OVERWRITE]   insertionPath exists= \(insertionExists2)  (\(insertionPath))")
        self.logger.debug("🔁 [OVERWRITE]   tailPath exists    = \(tailExists2)  (\(tailPath))")

        // 5. Concatena Head + Insertion + Tail
        var assetsToCombine: [String] = []
        if headExists2 {
          assetsToCombine.append(headPath)
        }
        // FIX: verifica esistenza insertion prima di aggiungerlo
        if insertionExists2 {
          assetsToCombine.append(insertionPath)
        } else {
          self.logger.warning("🔁 [OVERWRITE] ⚠️ insertionPath sparito prima della concatenazione!")
        }
        if tailExists2 {
          assetsToCombine.append(tailPath)
        }

        self.logger.debug("🔁 [OVERWRITE]   assetsToCombine = \(assetsToCombine)")

        self.concatenateMultiple(
          assetPaths: assetsToCombine,
          outputPath: outputPath,
          format: format,
          result: { res in
            // 6. Pulisci e restituisci
            try? fileManager.removeItem(atPath: headPath)
            try? fileManager.removeItem(atPath: tailPath)
            if let err = res as? FlutterError {
              self.logger.error("🔁 [OVERWRITE] ❌ concatenateMultiple error: \(err.message ?? "?")")
            } else {
              self.logger.info("🔁 [OVERWRITE] ✅ COMPLETATO → \(outputPath)")
            }
            result(res)
          }
        )
      }
    }
  }

  // Helper per esportare un segmento
  private func exportSegment(
    asset: AVAsset,
    startTimeMs: Int,
    durationMs: Int,
    outputPath: String,
    format: String,
    completion: @escaping (Bool) -> Void
  ) {
    self.logger.debug("✂️ [SEGMENT] startMs=\(startTimeMs) durMs=\(durationMs) → \(outputPath)")

    if durationMs <= 0 {
      self.logger.debug("✂️ [SEGMENT] ℹ️ durationMs<=0, skip (nessun segmento da estrarre)")
      completion(true) // Niente da tagliare, non viene creato il file
      return
    }

    let startTime = CMTime(value: CMTimeValue(startTimeMs), timescale: 1000)
    let duration = CMTime(value: CMTimeValue(durationMs), timescale: 1000)
    let timeRange = CMTimeRange(start: startTime, duration: duration)

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
      self.logger.error("✂️ [SEGMENT] ❌ Impossibile creare AVAssetExportSession")
      completion(false)
      return
    }

    exportSession.outputURL = URL(fileURLWithPath: outputPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a
    exportSession.timeRange = timeRange

    exportSession.exportAsynchronously {
      let status = exportSession.status
      let errMsg = exportSession.error?.localizedDescription ?? "nessuno"
      self.logger.debug("✂️ [SEGMENT] status=\(status.rawValue) error=\(errMsg) → \(outputPath)")
      completion(status == .completed)
    }
  }
    
  // Helper per concatenare più file
  private func concatenateMultiple(
    assetPaths: [String],
    outputPath: String,
    format: String,
    result: @escaping FlutterResult
  ) {
    self.logger.debug("🔗 [CONCAT] Concateno \(assetPaths.count) file → \(outputPath)")
    for (i, p) in assetPaths.enumerated() {
      self.logger.debug("🔗 [CONCAT]   [\(i)] \(p)")
    }

    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      self.logger.error("🔗 [CONCAT] ❌ Impossibile creare traccia composizione")
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition track", details: nil))
      return
    }

    var cursor = CMTime.zero
    for (i, path) in assetPaths.enumerated() {
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))

      // FIX: carica tracce in modo sincrono con loadValuesAsynchronously
      // per garantire che .tracks sia disponibile
      let semaphore = DispatchSemaphore(value: 0)
      asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) {
        semaphore.signal()
      }
      semaphore.wait()

      let duration = asset.duration
      let durationSec = CMTimeGetSeconds(duration)
      let tracks = asset.tracks(withMediaType: .audio)
      self.logger.debug("🔗 [CONCAT]   [\(i)] durSec=\(durationSec) audioTracks=\(tracks.count)")

      guard let srcTrack = tracks.first else {
        self.logger.warning("🔗 [CONCAT]   [\(i)] ⚠️ Nessuna traccia audio trovata, salto: \(path)")
        continue
      }
      do {
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcTrack, at: cursor)
        cursor = CMTimeAdd(cursor, duration)
        self.logger.info("🔗 [CONCAT]   [\(i)] ✅ inserito, cursor ora = \(CMTimeGetSeconds(cursor))s")
      } catch {
        self.logger.error("🔗 [CONCAT]   [\(i)] ❌ INSERT_ERROR: \(error)")
        result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
        return
      }
    }

    self.logger.debug("🔗 [CONCAT] Durata totale composizione = \(CMTimeGetSeconds(cursor))s")

    let concatPreset = format == "wav" ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: concatPreset) else {
      self.logger.error("🔗 [CONCAT] ❌ Impossibile creare AVAssetExportSession")
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let tempPath = outputPath + ".concat.tmp"
    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        do {
          let fm = FileManager.default
          if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
          }
          try fm.moveItem(atPath: tempPath, toPath: outputPath)
          self.logger.info("🔗 [CONCAT] ✅ COMPLETATO → \(outputPath)")
          result(nil)
        } catch {
          self.logger.error("🔗 [CONCAT] ❌ FILE_ERROR: \(error)")
          result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        let errMsg = exportSession.error?.localizedDescription ?? "Unknown export error"
        self.logger.error("🔗 [CONCAT] ❌ EXPORT_FAILED: \(errMsg)")
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: errMsg,
          details: nil
        ))
      }
    }
  }
}
