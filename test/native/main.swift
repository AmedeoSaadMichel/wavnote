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

if failures > 0 { print("\(failures) verifiche fallite"); exit(1) }
print("Tutti i test nativi superati")
