// File: ios/Shared/PCMTrim.swift
import Foundation
import AVFoundation

/// Taglio e giunzioni con rampe di 5 ms, senza aggiungere o rimuovere campioni.
enum PCMTrim {
    static func extract(inputPath: String, startTimeMs: Int, durationMs: Int,
                        outputPath: String, format: String) throws {
        try writeAtomically(outputPath: outputPath) { temporaryPath in
            let source = try AVAudioFile(forReading: URL(fileURLWithPath: inputPath))
            let rate = source.processingFormat.sampleRate
            let start = min(source.length, max(0, Int64(Double(startTimeMs) * rate / 1000)))
            let count = min(source.length - start, max(0, Int64(Double(durationMs) * rate / 1000)))
            // Il trim lavora in PCM; per M4A manteniamo l'export AAC già usato dall'app.
            let pcmURL = format == "wav" ? URL(fileURLWithPath: temporaryPath) :
                URL(fileURLWithPath: temporaryPath + ".wav")
            defer { if format != "wav" { try? FileManager.default.removeItem(at: pcmURL) } }
            try autoreleasepool {
                let output = try AVAudioFile(forWriting: pcmURL, settings: format == "wav" ? source.fileFormat.settings : source.processingFormat.settings)
                try copy(source, start: start, count: count, to: output)
            }
            if format != "wav" {
                let asset = AVURLAsset(url: pcmURL)
                guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                    throw NSError(domain: "PCMTrim", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Export M4A non disponibile"])
                }
                session.outputURL = URL(fileURLWithPath: temporaryPath)
                session.outputFileType = .m4a
                let finished = DispatchSemaphore(value: 0)
                session.exportAsynchronously { finished.signal() }
                finished.wait()
                guard session.status == .completed else {
                    throw session.error ?? NSError(domain: "PCMTrim", code: 2)
                }
            }
        }
    }

    static func overwrite(originalPath: String, insertionPath: String, startTimeMs: Int,
                          overwriteDurationMs: Int, outputPath: String) throws {
        try writeAtomically(outputPath: outputPath) { temporaryPath in
            let original = try AVAudioFile(forReading: URL(fileURLWithPath: originalPath))
            let insertion = try AVAudioFile(forReading: URL(fileURLWithPath: insertionPath))
            let output = try AVAudioFile(forWriting: URL(fileURLWithPath: temporaryPath), settings: original.fileFormat.settings)
            let rate = original.processingFormat.sampleRate
            let start = min(original.length, max(0, Int64(Double(startTimeMs) * rate / 1000)))
            let tail = min(original.length, start + max(0, Int64(Double(overwriteDurationMs) * rate / 1000)))
            try copy(original, start: 0, count: start, to: output)
            try copy(insertion, start: 0, count: insertion.length, to: output)
            try copy(original, start: tail, count: original.length - tail, to: output)
        }
    }

    // Chiude il writer prima di pubblicare il file, anche se input e output coincidono.
    private static func writeAtomically(outputPath: String, write: (String) throws -> Void) throws {
        let destination = URL(fileURLWithPath: outputPath)
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + "." + destination.pathExtension)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try autoreleasepool { try write(temporary.path) }
        if FileManager.default.fileExists(atPath: outputPath) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }

    private static func copy(_ source: AVAudioFile, start: Int64, count: Int64,
                             to output: AVAudioFile) throws {
        guard count > 0 else { return }
        source.framePosition = start
        let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 4096)!
        let converter = source.processingFormat.isEqual(output.processingFormat) ? nil :
            try RecordingPCMConverter(from: source.processingFormat, to: output.processingFormat)
        var position: Int64 = 0
        while position < count {
            try source.read(into: buffer, frameCount: AVAudioFrameCount(min(4096, count - position)))
            guard buffer.frameLength > 0 else { break }
            // La posizione è relativa al segmento, non al singolo blocco di lettura.
            applyFade(buffer, position: position, totalFrames: count)
            if let converter {
                try converter.convert(buffer) { try output.write(from: $0) }
            } else {
                try output.write(from: buffer)
            }
            position += Int64(buffer.frameLength)
        }
        if let converter { try converter.finish { try output.write(from: $0) } }
    }

    static func applyFade(_ buffer: AVAudioPCMBuffer, position: Int64, totalFrames: Int64) {
        guard let channels = buffer.floatChannelData, totalFrames > 0 else { return }
        let ramp = min(Int64((buffer.format.sampleRate * 0.005).rounded()), totalFrames / 2)
        let denominator = Double(max(1, ramp - 1))
        for index in 0..<Int(buffer.frameLength) {
            let frame = position + Int64(index)
            let gain = Float(min(1, max(0, Double(min(frame, totalFrames - 1 - frame)) / denominator)))
            for channel in 0..<Int(buffer.format.channelCount) {
                channels[channel][index * buffer.stride] *= gain
            }
        }
    }
}
