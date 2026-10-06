import Foundation
import AVFoundation

/// Durable handoff between the share extension and Flutter. Each audio file is
/// published atomically and removed only after the recording is saved in SQLite.
enum SharedAudioInbox {
    static let groupIdentifier = "group.com.amedeosaadmichel.wavnote"

    static func directory() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            throw NSError(domain: "WavNoteShare", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "La condivisione WavNote non è configurata. Verifica App Groups nella build."])
        }
        let inbox = container.appendingPathComponent("SharedAudioInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    static func enqueue(_ source: URL, suggestedName: String?, fileExtension: String? = nil, in destination: URL? = nil) throws {
        let manager = FileManager.default
        let ext = (source.pathExtension.isEmpty ? fileExtension ?? "" : source.pathExtension).lowercased()
        guard ["m4a", "wav", "flac"].contains(ext) else {
            throw NSError(domain: "WavNoteShare", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Scegli M4A (audio renderizzato) nelle opzioni di condivisione di Memo Vocali."])
        }
        let inbox = try destination ?? directory()
        let id = UUID().uuidString
        let pending = inbox.appendingPathComponent(".pending-" + id, isDirectory: true)
        try manager.createDirectory(at: pending, withIntermediateDirectories: true)
        do {
            let audioURL = pending.appendingPathComponent("audio." + ext)
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            try manager.copyItem(at: source, to: audioURL)
            let attributes = try manager.attributesOfItem(atPath: source.path)
            let name = (suggestedName?.isEmpty == false ? suggestedName! : source.lastPathComponent) as NSString
            let displayName = ["m4a", "wav", "flac"].contains(name.pathExtension.lowercased()) ? name.deletingPathExtension : name as String
            let metadata: [String: Any] = [
                "entryId": id, "file": audioURL.lastPathComponent,
                "name": displayName,
                "createdAtMs": Int((attributes[.creationDate] as? Date ?? Date()).timeIntervalSince1970 * 1000)
            ]
            try JSONSerialization.data(withJSONObject: metadata).write(to: pending.appendingPathComponent("metadata.json"), options: .atomic)
            try manager.moveItem(at: pending, to: inbox.appendingPathComponent(id, isDirectory: true))
        } catch {
            try? manager.removeItem(at: pending)
            throw error
        }
    }

    static func pendingEntries(at location: URL? = nil) throws -> [[String: Any]] {
        let manager = FileManager.default
        let folders = try manager.contentsOfDirectory(at: location ?? directory(), includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]).filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return folders.map { folder in
            var entry: [String: Any] = ["entryId": folder.lastPathComponent, "name": "Memo vocale"]
            do {
                let data = try Data(contentsOf: folder.appendingPathComponent("metadata.json"))
                guard var metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let filename = metadata["file"] as? String,
                    ["audio.m4a", "audio.wav", "audio.flac"].contains(filename) else {
                    throw NSError(domain: "WavNoteShare", code: 3)
                }
                entry["name"] = metadata["name"]
                let source = folder.appendingPathComponent(filename)
                let audio = try AVAudioFile(forReading: source)
                let rate = audio.processingFormat.sampleRate
                guard rate > 0, audio.length > 0 else { throw NSError(domain: "WavNoteShare", code: 4) }
                // Read directly from the durable inbox. Dart copies it into the
                // app's library; only acknowledgement may delete the inbox file.
                metadata["entryId"] = folder.lastPathComponent
                metadata["path"] = source.path
                metadata["durationMs"] = Int(Double(audio.length) / rate * 1000)
                metadata["sampleRate"] = Int(rate)
                return metadata
            } catch {
                entry["error"] = error.localizedDescription
                return entry
            }
        }
    }

    static func acknowledge(_ ids: [String], in location: URL? = nil) throws {
        let inbox = try location ?? directory()
        for id in ids {
            guard UUID(uuidString: id) != nil else { continue }
            let folder = inbox.appendingPathComponent(id, isDirectory: true)
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
            }
        }
    }
}
