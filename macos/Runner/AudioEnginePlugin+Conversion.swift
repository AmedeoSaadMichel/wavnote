// File: macos/Runner/AudioEnginePlugin+Conversion.swift
import Cocoa
import FlutterMacOS
import AVFoundation
import Logging

extension AudioEnginePlugin {
    // MARK: - Helpers

    func concatenatePCMFiles(_ paths: [String], into outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: outputPath), settings: settings)
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

    func durationOf(path: String) -> Double {
        guard let f = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    // MARK: - WAV → Format Conversion

    func convertWAVToFormat(wavPath: String, outputPath: String, format: String, settings: [String: Any]?, completion: @escaping (Error?) -> Void) {
        switch format {
        case "m4a":
            convertWAVToM4A(wavPath: wavPath, outputPath: outputPath, completion: completion)
        case "flac":
            convertWAVToFLAC(wavPath: wavPath, outputPath: outputPath, settings: settings ?? [:], completion: completion)
        default:
            completion(nil)
        }
    }

    func convertWAVToM4A(wavPath: String, outputPath: String, completion: @escaping (Error?) -> Void) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: wavPath))
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(NSError(domain: "WavNote", code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create M4A export session"]))
            return
        }
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.exportAsynchronously {
            if session.status == .completed { completion(nil) }
            else { completion(session.error ?? NSError(domain: "WavNote", code: -11,
                userInfo: [NSLocalizedDescriptionKey: "M4A export failed"])) }
        }
    }

    func convertWAVToFLAC(wavPath: String, outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let inFile = try AVAudioFile(forReading: URL(fileURLWithPath: wavPath))
                let outputURL = URL(fileURLWithPath: outputPath)
                try? FileManager.default.removeItem(at: outputURL)
                let outFile = try AVAudioFile(forWriting: outputURL, settings: settings)
                guard let converter = AVAudioConverter(from: inFile.processingFormat, to: outFile.processingFormat) else {
                    DispatchQueue.main.async {
                        completion(NSError(domain: "WavNote", code: -12,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot create FLAC converter"]))
                    }
                    return
                }
                let chunkFrames: AVAudioFrameCount = 65536
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: chunkFrames),
                      let outputBuffer = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: chunkFrames) else {
                    DispatchQueue.main.async {
                        completion(NSError(domain: "WavNote", code: -13,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot create FLAC conversion buffers"]))
                    }
                    return
                }
                var remaining = inFile.length
                while remaining > 0 {
                    let toRead = min(chunkFrames, AVAudioFrameCount(remaining))
                    try inFile.read(into: inputBuffer, frameCount: toRead)
                    var convError: NSError? = nil
                    var inputDone = false
                    converter.convert(to: outputBuffer, error: &convError) { _, status in
                        if !inputDone { inputDone = true; status.pointee = .haveData; return inputBuffer }
                        status.pointee = .endOfStream; return nil
                    }
                    if let err = convError {
                        DispatchQueue.main.async { completion(err) }
                        return
                    }
                    try outFile.write(from: outputBuffer)
                    remaining -= Int64(toRead)
                }
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    // MARK: - Format Validation

    func buildRecordingSettings(format: String, sampleRate: Int, bitRate: Int) -> [String: Any] {
        switch format {
        case "wav":
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: NSNumber(value: false),
                AVLinearPCMIsFloatKey: NSNumber(value: false)
            ]
        case "flac":
            return [
                AVFormatIDKey: kAudioFormatFLAC,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16
            ]
        default: // "m4a"
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: bitRate
            ]
        }
    }

    func validateRecordingSettings(_ settings: [String: Any], format: String) -> Bool {
        guard let sampleRate = settings[AVSampleRateKey] as? Double else { return false }
        let channels = settings[AVNumberOfChannelsKey] as? Int ?? 1
        if format == "wav" { return true }
        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else { return false }
        guard let outputFormat = AVAudioFormat(settings: settings) else { return false }
        return AVAudioConverter(from: inputFormat, to: outputFormat) != nil
    }

}
