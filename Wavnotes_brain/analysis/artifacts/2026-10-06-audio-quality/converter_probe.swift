// File: Wavnotes_brain/analysis/artifacts/2026-10-06-audio-quality/converter_probe.swift
// Diagnostica offline: nessun accesso a microfono, altoparlante o file utente.
import Foundation
import AVFoundation

let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : NSTemporaryDirectory() + "wavnote-audio-diagnosis"
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for (inputRate, outputRate) in [(48000.0,44100.0),(44100.0,48000.0),(16000.0,44100.0)] {
    for mode in ["current", "single_supply"] {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1)!
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
        let chunk = 1024
        let iterations = 200
        var samples = [Float]()
        var callbacks = 0
        var duplicateSupplies = 0
        var errors = 0
        for block in 0..<iterations {
            let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(chunk))!
            input.frameLength = AVAudioFrameCount(chunk)
            for frame in 0..<chunk {
                input.floatChannelData![0][frame] = Float(0.25 * sin(2 * Double.pi * 997 * Double(block * chunk + frame) / inputRate))
            }
            let capacity = mode == "current" ? chunk : Int(ceil(Double(chunk) * outputRate / inputRate)) + 64
            let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(capacity))!
            var supplied = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                callbacks += 1
                if supplied && mode == "single_supply" {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                if supplied { duplicateSupplies += 1 }
                supplied = true
                inputStatus.pointee = .haveData
                return input
            }
            if error != nil || status == .error { errors += 1 }
            samples.append(contentsOf: UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
        }
        let path = "\(directory)/\(Int(inputRate))-\(Int(outputRate))-\(mode).f32"
        try samples.withUnsafeBytes { bytes in try Data(bytes).write(to: URL(fileURLWithPath: path)) }
        let expected = Double(chunk * iterations) * outputRate / inputRate
        print("\(Int(inputRate))->\(Int(outputRate)) mode=\(mode) callbacks=\(callbacks) repeated_buffers=\(duplicateSupplies) frames=\(samples.count) expected=\(Int(expected)) duration_ratio=\(Double(samples.count)/expected) errors=\(errors)")
    }
}
