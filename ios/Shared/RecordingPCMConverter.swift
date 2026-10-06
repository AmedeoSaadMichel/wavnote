// File: ios/Shared/RecordingPCMConverter.swift
import Foundation
import AVFoundation

/// Conversione incrementale condivisa da iOS e macOS, indipendente da Flutter.
/// Ogni buffer del tap viene fornito una sola volta; l'uscita viene consumata
/// prima di riutilizzarla. finish scarica la coda e prepara un nuovo segmento.
final class RecordingPCMConverter {
    private let converter: AVAudioConverter
    private var output: AVAudioPCMBuffer?
    private let lock = NSLock()

    init(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "RecordingPCMConverter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Formato audio non convertibile"])
        }
        self.converter = converter
    }

    @discardableResult
    func convert(_ input: AVAudioPCMBuffer,
                 consume: (AVAudioPCMBuffer) throws -> Void) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        guard input.frameLength > 0 else { return 0 }
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 64
        try ensureCapacity(capacity)
        var supplied = false
        return try process(consume: consume) { _, status in
            guard !supplied else {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return input
        }
    }

    @discardableResult
    func finish(consume: (AVAudioPCMBuffer) throws -> Void) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        try ensureCapacity(1024)
        let frames = try process(consume: consume) { _, status in
            status.pointee = .endOfStream
            return nil
        }
        converter.reset()
        return frames
    }

    private func ensureCapacity(_ capacity: AVAudioFrameCount) throws {
        if let output, output.frameCapacity >= capacity { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                          frameCapacity: capacity) else {
            throw NSError(domain: "RecordingPCMConverter", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Allocazione buffer audio fallita"])
        }
        output = buffer
    }

    private func process(consume: (AVAudioPCMBuffer) throws -> Void,
                         supply: @escaping AVAudioConverterInputBlock) throws -> Int64 {
        guard let output else { return 0 }
        var frames: Int64 = 0
        while true {
            output.frameLength = 0
            var error: NSError?
            let status = converter.convert(to: output, error: &error, withInputFrom: supply)
            if let error { throw error }
            if status == .error {
                throw NSError(domain: "RecordingPCMConverter", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Conversione audio fallita"])
            }
            if output.frameLength > 0 {
                try consume(output)
                frames += Int64(output.frameLength)
            }
            // haveData indica che l'uscita era piena: scarica anche i residui.
            if status != .haveData || output.frameLength == 0 { return frames }
        }
    }
}
