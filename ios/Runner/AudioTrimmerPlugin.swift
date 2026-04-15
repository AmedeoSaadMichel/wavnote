// File: ios/Runner/AudioTrimmerPlugin.swift
import Flutter
import AVFoundation
import Logging

class AudioTrimmerPlugin: NSObject, FlutterPlugin {

  // Uso lazy così la logger prende il FlutterLogHandler iniettato dopo la registrazione
  private lazy var logger = Logger(label: "com.wavnote.audio_trimmer")

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
    case "overwriteAudio":
      overwriteAudio(args: args, result: result)
    case "concatenateAudio":
      concatenateAudio(args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Trim

  private func trimAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let inputPath = args["inputPath"] as? String,
      let startTimeMs = args["startTimeMs"] as? Int,
      let durationMs = args["durationMs"] as? Int,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "trimAudio: missing params", details: nil))
      return
    }

    let format = (args["format"] as? String) ?? "m4a"
    
    if format == "wav" {
        pcmExtractSegment(inputPath: inputPath, startTimeMs: startTimeMs, durationMs: durationMs, outputPath: outputPath) { res in
            if let err = res as? FlutterError {
                result(err)
            } else {
                result(nil)
            }
        }
    } else {
        let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
        exportSegmentiOS(asset: asset, startTimeMs: startTimeMs, durationMs: durationMs, outputPath: outputPath, format: format) { success in
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "TRIM_FAILED", message: "Export session failed", details: nil))
            }
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
    
    guard originalExists else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Original file not found: \(originalPath)", details: nil))
      return
    }
    guard insertionExists else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Insertion file not found: \(insertionPath)", details: nil))
      return
    }

    if format == "wav" {
        pcmOverwrite(
            originalPath: originalPath,
            insertionPath: insertionPath,
            startTimeMs: startTimeMs,
            overwriteDurationMs: overwriteDurationMs,
            outputPath: outputPath
        ) { res in
            if let err = res as? FlutterError {
                self.logger.error("🔁 [OVERWRITE-iOS] ❌ ERROR: \(err.message ?? "")")
                result(err)
            } else {
                self.logger.info("🔁 [OVERWRITE-iOS] ✅ COMPLETATO → \(outputPath)")
                result(nil)
            }
        }
        return
    }

    // Modalità legacy per M4A usando AVAssetExportSession
    let originalAsset = AVURLAsset(url: URL(fileURLWithPath: originalPath))
    
    let sem = DispatchSemaphore(value: 0)
    originalAsset.loadValuesAsynchronously(forKeys: ["duration"]) { sem.signal() }
    sem.wait()

    var originalDurationMs: Int
    if originalAsset.statusOfValue(forKey: "duration", error: nil) == .loaded {
      let durationSec = CMTimeGetSeconds(originalAsset.duration)
      originalDurationMs = durationSec.isNaN ? 0 : Int(durationSec * 1000)
    } else {
      originalDurationMs = 0
    }

    let tailStartTimeMs = startTimeMs + overwriteDurationMs

    let headPath = outputPath + ".head.m4a"
    let tailPath = outputPath + ".tail.m4a"
    try? fileManager.removeItem(atPath: headPath)
    try? fileManager.removeItem(atPath: tailPath)

    let group = DispatchGroup()
    var headSuccess = false
    var tailSuccess = true

    group.enter()
    self.exportSegmentiOS(asset: originalAsset, startTimeMs: 0, durationMs: startTimeMs, outputPath: headPath, format: format) { success in
      if success { headSuccess = true }
      group.leave()
    }

    if tailStartTimeMs < originalDurationMs {
      group.enter()
      self.exportSegmentiOS(asset: originalAsset, startTimeMs: tailStartTimeMs, durationMs: originalDurationMs - tailStartTimeMs, outputPath: tailPath, format: format) { success in
        if !success { tailSuccess = false }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      if !headSuccess || !tailSuccess {
        result(FlutterError(code: "TRIM_FAILED", message: "Head/tail trim failed", details: nil))
        return
      }

      var assetsToCombine: [String] = []
      if fileManager.fileExists(atPath: headPath) { assetsToCombine.append(headPath) }
      if fileManager.fileExists(atPath: insertionPath) { assetsToCombine.append(insertionPath) }
      if fileManager.fileExists(atPath: tailPath) { assetsToCombine.append(tailPath) }

      self.concatenateMultipleiOS(assetPaths: assetsToCombine, outputPath: outputPath, format: format) { res in
        try? fileManager.removeItem(atPath: headPath)
        try? fileManager.removeItem(atPath: tailPath)
        result(res)
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
    
    if format == "wav" {
        pcmConcatenate(paths: [basePath, appendPath], outputPath: outputPath) { err in
            if let e = err {
                result(FlutterError(code: "FILE_ERROR", message: e.localizedDescription, details: nil))
            } else {
                result(nil)
            }
        }
        return
    }

    concatenateMultipleiOS(assetPaths: [basePath, appendPath], outputPath: outputPath, format: format, result: result)
  }

  // MARK: - AVAssetExportSession (Legacy M4A)

  private func exportSegmentiOS(
    asset: AVAsset,
    startTimeMs: Int,
    durationMs: Int,
    outputPath: String,
    format: String,
    completion: @escaping (Bool) -> Void
  ) {
    if durationMs <= 0 {
      completion(true)
      return
    }
    let startTime = CMTime(value: CMTimeValue(startTimeMs), timescale: 1000)
    let duration  = CMTime(value: CMTimeValue(durationMs),  timescale: 1000)
    let preset = format == "wav" ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
      completion(false)
      return
    }
    exportSession.timeRange = CMTimeRange(start: startTime, duration: duration)
    exportSession.outputURL = URL(fileURLWithPath: outputPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a

    exportSession.exportAsynchronously {
      DispatchQueue.main.async { completion(exportSession.status == .completed) }
    }
  }

  private func concatenateMultipleiOS(
    assetPaths: [String],
    outputPath: String,
    format: String,
    result: @escaping FlutterResult
  ) {
    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition track", details: nil))
      return
    }

    var cursor = CMTime.zero
    for path in assetPaths {
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      let sem = DispatchSemaphore(value: 0)
      asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { sem.signal() }
      sem.wait()

      guard let srcTrack = asset.tracks(withMediaType: .audio).first else { continue }
      do {
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: srcTrack, at: cursor)
        cursor = CMTimeAdd(cursor, asset.duration)
      } catch {
        result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
        return
      }
    }

    let concatPreset = format == "wav" ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: concatPreset) else {
      result(FlutterError(code: "EXPORT_FAILED", message: "Could not create export session", details: nil))
      return
    }

    let tempPath = outputPath + ".concat.tmp"
    exportSession.outputURL = URL(fileURLWithPath: tempPath)
    exportSession.outputFileType = format == "wav" ? .wav : .m4a

    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        if exportSession.status == .completed {
          do {
            let fm = FileManager.default
            if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
            try fm.moveItem(atPath: tempPath, toPath: outputPath)
            result(nil)
          } catch {
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
          }
        } else {
            result(FlutterError(code: "EXPORT_FAILED", message: exportSession.error?.localizedDescription ?? "Unknown", details: nil))
        }
      }
    }
  }

  // MARK: - PCM Processing (WAV Lossless)

  private func pcmOverwrite(
    originalPath: String,
    insertionPath: String,
    startTimeMs: Int,
    overwriteDurationMs: Int,
    outputPath: String,
    completion: @escaping (Any?) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let origFile = try AVAudioFile(forReading: URL(fileURLWithPath: originalPath))
        let insFile = try AVAudioFile(forReading: URL(fileURLWithPath: insertionPath))
        
        let sampleRate = origFile.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition((Double(startTimeMs) / 1000.0) * sampleRate)
        let overwriteFrames = AVAudioFramePosition((Double(overwriteDurationMs) / 1000.0) * sampleRate)
        
        let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: outputPath), settings: origFile.fileFormat.settings)
        let chunkFrames: AVAudioFrameCount = 65536
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: origFile.processingFormat, frameCapacity: chunkFrames) else {
            DispatchQueue.main.async { completion(FlutterError(code: "BUFFER_ERROR", message: "Could not allocate PCM buffer", details: nil)) }
            return
        }
        
        // 1. Write HEAD
        origFile.framePosition = 0
        var remainingHead = startFrame
        while remainingHead > 0 {
            let toRead = min(chunkFrames, AVAudioFrameCount(remainingHead))
            buffer.frameLength = toRead
            try origFile.read(into: buffer, frameCount: toRead)
            if buffer.frameLength == 0 { break }
            try outFile.write(from: buffer)
            remainingHead -= Int64(buffer.frameLength)
        }
        
        // 2. Write INSERTION
        insFile.framePosition = 0
        let needsConversion = !insFile.processingFormat.isEqual(outFile.processingFormat)
        
        guard let insBuffer = AVAudioPCMBuffer(pcmFormat: insFile.processingFormat, frameCapacity: chunkFrames) else {
            DispatchQueue.main.async { completion(FlutterError(code: "BUFFER_ERROR", message: "Could not allocate insertion buffer", details: nil)) }
            return
        }
        
        let converter = needsConversion ? AVAudioConverter(from: insFile.processingFormat, to: outFile.processingFormat) : nil
        var remainingIns = insFile.length
        
        while remainingIns > 0 {
            let toRead = min(chunkFrames, AVAudioFrameCount(remainingIns))
            insBuffer.frameLength = toRead
            try insFile.read(into: insBuffer, frameCount: toRead)
            if insBuffer.frameLength == 0 { break }
            
            if !needsConversion {
                try outFile.write(from: insBuffer)
            } else if let conv = converter, let convBuf = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: toRead) {
                var inputDone = false
                var convError: NSError? = nil
                conv.convert(to: convBuf, error: &convError) { _, status in
                    if !inputDone { inputDone = true; status.pointee = .haveData; return insBuffer }
                    status.pointee = .endOfStream; return nil
                }
                if convError == nil { try outFile.write(from: convBuf) }
            }
            remainingIns -= Int64(insBuffer.frameLength)
        }
        
        // 3. Write TAIL
        let tailStartFrame = startFrame + overwriteFrames
        if tailStartFrame < origFile.length {
            origFile.framePosition = tailStartFrame
            var remainingTail = origFile.length - tailStartFrame
            while remainingTail > 0 {
                let toRead = min(chunkFrames, AVAudioFrameCount(remainingTail))
                buffer.frameLength = toRead
                try origFile.read(into: buffer, frameCount: toRead)
                if buffer.frameLength == 0 { break }
                try outFile.write(from: buffer)
                remainingTail -= Int64(buffer.frameLength)
            }
        }
        
        DispatchQueue.main.async { completion(nil) }
      } catch {
        DispatchQueue.main.async { completion(FlutterError(code: "PCM_ERROR", message: error.localizedDescription, details: nil)) }
      }
    }
  }

  private func pcmConcatenate(paths: [String], outputPath: String, completion: @escaping (Error?) -> Void) {
      DispatchQueue.global(qos: .userInitiated).async {
          do {
              guard let firstFile = try? AVAudioFile(forReading: URL(fileURLWithPath: paths.first!)) else {
                  throw NSError(domain: "AudioTrimmer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base file"])
              }
              let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: outputPath), settings: firstFile.fileFormat.settings)
              let chunkFrames: AVAudioFrameCount = 65536
              
              for path in paths {
                  guard let inFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)),
                        let buffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: chunkFrames) else { continue }
                  var remaining = inFile.length
                  while remaining > 0 {
                      let toRead = min(chunkFrames, AVAudioFrameCount(remaining))
                      buffer.frameLength = toRead
                      try inFile.read(into: buffer, frameCount: toRead)
                      if inFile.processingFormat.isEqual(outFile.processingFormat) {
                          try outFile.write(from: buffer)
                      } else {
                          guard let conv = AVAudioConverter(from: inFile.processingFormat, to: outFile.processingFormat),
                                let convBuf = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: toRead) else { break }
                          var inputDone = false
                          var convError: NSError? = nil
                          conv.convert(to: convBuf, error: &convError) { _, status in
                              if !inputDone { inputDone = true; status.pointee = .haveData; return buffer }
                              status.pointee = .endOfStream; return nil
                          }
                          if convError == nil { try outFile.write(from: convBuf) }
                      }
                      remaining -= Int64(toRead)
                  }
              }
              DispatchQueue.main.async { completion(nil) }
          } catch {
              DispatchQueue.main.async { completion(error) }
          }
      }
  }

  private func pcmExtractSegment(
      inputPath: String,
      startTimeMs: Int,
      durationMs: Int,
      outputPath: String,
      completion: @escaping (Any?) -> Void
  ) {
      DispatchQueue.global(qos: .userInitiated).async {
          do {
              let inFile = try AVAudioFile(forReading: URL(fileURLWithPath: inputPath))
              let sampleRate = inFile.fileFormat.sampleRate
              let startFrame = AVAudioFramePosition((Double(startTimeMs) / 1000.0) * sampleRate)
              let totalFramesToRead = AVAudioFrameCount((Double(durationMs) / 1000.0) * sampleRate)
              
              inFile.framePosition = startFrame
              
              let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: outputPath), settings: inFile.fileFormat.settings)
              let chunkFrames: AVAudioFrameCount = 65536
              guard let buffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: chunkFrames) else {
                  DispatchQueue.main.async { completion(FlutterError(code: "BUFFER_ERROR", message: "Failed to allocate buffer", details: nil)) }
                  return
              }
              
              var remaining = Int64(totalFramesToRead)
              while remaining > 0 {
                  let toRead = min(chunkFrames, AVAudioFrameCount(remaining))
                  buffer.frameLength = toRead
                  try inFile.read(into: buffer, frameCount: toRead)
                  if buffer.frameLength == 0 { break }
                  try outFile.write(from: buffer)
                  remaining -= Int64(buffer.frameLength)
              }
              DispatchQueue.main.async { completion(nil) }
          } catch {
              DispatchQueue.main.async { completion(FlutterError(code: "PCM_ERROR", message: error.localizedDescription, details: nil)) }
          }
      }
  }

}
