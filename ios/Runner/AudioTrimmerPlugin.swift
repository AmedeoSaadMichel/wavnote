// File: ios/Runner/AudioTrimmerPlugin.swift
import Flutter
import AVFoundation

class AudioTrimmerPlugin: NSObject, FlutterPlugin {

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
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Trim

  private func trimAudio(args: [String: Any], result: @escaping FlutterResult) {
    guard
      let filePath = args["filePath"] as? String,
      let durationMs = args["durationMs"] as? Int,
      let outputPath = args["outputPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "trimAudio: missing params", details: nil))
      return
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
    let trimDuration = CMTime(value: CMTimeValue(durationMs), timescale: 1000)
    let timeRange = CMTimeRange(start: .zero, duration: trimDuration)

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
