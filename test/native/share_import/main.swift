import Foundation
import AVFoundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

let manager = FileManager.default
let root = manager.temporaryDirectory.appendingPathComponent("wavnote-share-test-" + UUID().uuidString)
let inbox = root.appendingPathComponent("inbox")
try manager.createDirectory(at: inbox, withIntermediateDirectories: true)
defer { try? manager.removeItem(at: root) }

let source = root.appendingPathComponent("Source.wav")
let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
buffer.frameLength = 4800
for index in 0..<4800 { buffer.floatChannelData![0][index] = 0 }
do {
    let writer = try AVAudioFile(forWriting: source, settings: format.settings)
    try writer.write(from: buffer)
}

try SharedAudioInbox.enqueue(source, suggestedName: "Guitar take.2", in: inbox)
try SharedAudioInbox.enqueue(source, suggestedName: "Guitar take.2", in: inbox)
let entries = try SharedAudioInbox.pendingEntries(at: inbox)
check(entries.count == 2, "Both same-name recordings must survive")
check(entries[0]["name"] as? String == "Guitar take.2", "Preserve periods in names without an audio extension")
check(entries[0]["durationMs"] as? Int == 100, "Read real audio duration")
check(entries[0]["sampleRate"] as? Int == 48000, "Read real sample rate")
check(entries[0]["entryId"] as? String != entries[1]["entryId"] as? String, "Use independent stable IDs")
check(manager.fileExists(atPath: source.path), "Do not modify the original")
let first = entries[0]["entryId"] as! String
try SharedAudioInbox.acknowledge(["../Source.wav", first], in: inbox)
let remaining = try SharedAudioInbox.pendingEntries(at: inbox)
check(remaining.count == 1, "Acknowledge only the saved item")
check(manager.fileExists(atPath: source.path), "Reject traversal IDs")
check(remaining[0]["entryId"] as? String == entries[1]["entryId"] as? String, "Retries keep the same ID")

let broken = root.appendingPathComponent("Broken.m4a")
try Data([0, 1, 2]).write(to: broken)
try SharedAudioInbox.enqueue(broken, suggestedName: "Broken.m4a", in: inbox)
let withBroken = try SharedAudioInbox.pendingEntries(at: inbox)
check(withBroken.count == 2, "A bad file must not abort the rest of the inbox")
check(withBroken.filter { $0["error"] != nil }.count == 1, "Report the bad file")
let published = try manager.contentsOfDirectory(atPath: inbox.path)
check(published.allSatisfy { !$0.hasPrefix(".pending-") }, "No partially published entries")
print("Shared audio inbox: same-name batches, audio metadata, durable retry, acknowledgement, traversal rejection and partial failures passed.")
