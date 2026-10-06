// File: test/native/main.swift
// Eseguire con swiftc ios/Shared/RecordingPCMConverter.swift test/native/main.swift -o /tmp/wavnote-pcm-test
import Foundation
import AVFoundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL: \(message)") }
}
for (inputRate, outputRate) in [(48000.0, 44100.0), (44100.0, 48000.0), (16000.0, 44100.0), (44100.0, 44100.0)] {
    for chunk in [1024, 4800] {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1)!
        let converter = try RecordingPCMConverter(from: inputFormat, to: outputFormat)
        // Due segmenti sulla stessa istanza: pausa/resume non riusa la coda precedente.
        for segment in 0..<2 {
            var samples = [Float]()
            let total = chunk * 40 + 137
            var position = 0
            let collect: (AVAudioPCMBuffer) throws -> Void = { output in
                samples.append(contentsOf: UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
            }
            while position < total {
                let length = min(chunk, total - position)
                // Capacità volutamente superiore ai dati validi, come nei buffer di un tap.
                let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(chunk + 512))!
                input.frameLength = AVAudioFrameCount(length)
                for index in 0..<length {
                    input.floatChannelData![0][index] = Float(0.25 * sin(2 * Double.pi * 997 * Double(position + index) / inputRate))
                }
                try converter.convert(input, consume: collect)
                position += length
            }
            try converter.finish(consume: collect)
            let expected = Int((Double(total) * outputRate / inputRate).rounded())
            check(abs(samples.count - expected) <= 1, "\(inputRate)->\(outputRate), chunk \(chunk), segmento \(segment): \(samples.count) frame invece di \(expected)")
            let jumps = zip(samples.dropFirst(), samples).filter { abs($0 - $1) > 0.1 }.count
            check(jumps == 0, "\(inputRate)->\(outputRate): \(jumps) discontinuità")
            let n = samples.count
            var ss = 0.0, cc = 0.0, cs = 0.0, xs = 0.0, xc = 0.0, energy = 0.0
            // Esclude soltanto i transitori del filtro alle estremità.
            for index in 100..<(n - 100) {
                let phase = 2 * Double.pi * 997 * Double(index) / outputRate
                let s = sin(phase), c = cos(phase), x = Double(samples[index])
                ss += s*s; cc += c*c; cs += c*s; xs += x*s; xc += x*c; energy += x*x
            }
            let determinant = ss*cc-cs*cs
            let a = (xs*cc-xc*cs)/determinant, b = (xc*ss-xs*cs)/determinant
            let residual = sqrt(max(0, energy-a*xs-b*xc)/Double(n-200))
            check(residual < 0.0001, "\(inputRate)->\(outputRate): tono corrotto, residuo RMS \(residual)")
        }
        print("Verificato \(Int(inputRate))->\(Int(outputRate)) Hz, blocchi \(chunk)")
    }
}
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
let emptyConverter = try RecordingPCMConverter(from: format, to: format)
let empty = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
var emptyFrames: Int64 = 0
try emptyConverter.convert(empty) { emptyFrames += Int64($0.frameLength) }
try emptyConverter.finish { emptyFrames += Int64($0.frameLength) }
check(emptyFrames == 0, "Un buffer vuoto non deve produrre audio")

enum WriteFailure: Error { case expected }
let failingConverter = try RecordingPCMConverter(from: format, to: format)
empty.frameLength = 1024
var propagated = false
do { try failingConverter.convert(empty) { _ in throw WriteFailure.expected } }
catch WriteFailure.expected { propagated = true }
check(propagated, "Gli errori di scrittura devono propagarsi al chiamante")

// Taglio reale di un segnale costante: il vecchio taglio lascia bordi a ±0.5.
let trimDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: trimDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: trimDir) }
for rate in [16000.0, 44100.0, 48000.0] {
    let stereo = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
    let sourceURL = trimDir.appendingPathComponent("source.wav")
    do {
        let file = try AVAudioFile(forWriting: sourceURL, settings: stereo.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: AVAudioFrameCount(rate))!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            buffer.floatChannelData![0][i] = 0.5
            buffer.floatChannelData![1][i] = -0.5
        }
        try file.write(from: buffer)
    }
    for milliseconds in [1, 8, 250] {
        let url = trimDir.appendingPathComponent("trim.wav")
        try? FileManager.default.removeItem(at: url)
        try PCMTrim.extract(inputPath: sourceURL.path, startTimeMs: 100, durationMs: milliseconds,
                            outputPath: url.path, format: "wav")
        let file = try AVAudioFile(forReading: url)
        let expected = Int64(Double(milliseconds) * rate / 1000)
        check(file.length == expected, "Trim: durata invariata a \(rate) Hz, \(milliseconds) ms")
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        for channel in 0..<2 {
            let samples = buffer.floatChannelData![channel]
            check(samples[0] == 0 && samples[Int(file.length)-1] == 0, "Trim: entrambi i bordi a zero, canale \(channel)")
            let jumps = (1..<Int(file.length)).map { abs(samples[$0]-samples[$0-1]) }
            check((jumps.max() ?? 0) < 0.08, "Trim: nessun salto brusco anche su blocchi multipli")
            if milliseconds == 250 {
                check(abs(samples[Int(file.length)/2]) == 0.5, "Trim: contenuto centrale invariato")
            }
        }
    }
    let joinedURL = trimDir.appendingPathComponent("joined.wav")
    try? FileManager.default.removeItem(at: joinedURL)
    try PCMTrim.overwrite(originalPath: sourceURL.path, insertionPath: sourceURL.path,
                          startTimeMs: 250, overwriteDurationMs: 250, outputPath: joinedURL.path)
    let joined = try AVAudioFile(forReading: joinedURL)
    check(joined.length == Int64(rate * 1.75), "Giunzione: durata preservata")
    let data = AVAudioPCMBuffer(pcmFormat: joined.processingFormat, frameCapacity: AVAudioFrameCount(joined.length))!
    try joined.read(into: data)
    for boundary in [Int(rate * 0.25), Int(rate * 1.25)] {
        check(data.floatChannelData![0][boundary-1] == 0 && data.floatChannelData![0][boundary] == 0,
              "Giunzione: entrambi i lati sfumati")
    }
}

// Export AAC e sostituzione in-place: durata e file leggibile dopo la chiusura.
let sourcePath = trimDir.appendingPathComponent("source.wav").path
let aacPath = trimDir.appendingPathComponent("trim.m4a").path
try PCMTrim.extract(inputPath: sourcePath, startTimeMs: 100, durationMs: 250,
                    outputPath: aacPath, format: "m4a")
let aac = try AVAudioFile(forReading: URL(fileURLWithPath: aacPath))
check(abs(Double(aac.length) / aac.processingFormat.sampleRate - 0.25) < 0.001,
      "Trim AAC: durata preservata")
try PCMTrim.extract(inputPath: sourcePath, startTimeMs: 100, durationMs: 250,
                    outputPath: sourcePath, format: "wav")
let replaced = try AVAudioFile(forReading: URL(fileURLWithPath: sourcePath))
check(replaced.length == 12000, "Trim in-place: sorgente letto prima della sostituzione")

if failures > 0 { print("\(failures) verifiche fallite"); exit(1) }
print("Tutti i test nativi superati")
