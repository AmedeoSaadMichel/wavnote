// File: macos/Runner/RecordingFileActions.swift
import Cocoa
import FlutterMacOS
import AVFoundation
import UniformTypeIdentifiers

final class RecordingFileActions {
    private weak var controller: FlutterViewController?
    private let channel: FlutterMethodChannel
    private var sharePicker: NSSharingServicePicker?

    init(controller: FlutterViewController) {
        self.controller = controller
        channel = FlutterMethodChannel(name: "wavnote/file_actions", binaryMessenger: controller.engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "pickVoiceMemos" {
            guard let window = controller?.view.window else {
                result(FlutterError(code: "NO_WINDOW", message: "Nessuna finestra disponibile.", details: nil)); return
            }
            let folder = (call.arguments as? [String: Any])?["folder"] as? Bool ?? false
            let panel = NSOpenPanel()
            panel.canChooseDirectories = folder
            panel.canChooseFiles = !folder
            panel.allowsMultipleSelection = !folder
            if #available(macOS 11.0, *) {
                panel.allowedContentTypes = folder ? [.folder] : [.audio]
            } else if !folder {
                panel.allowedFileTypes = ["m4a", "wav", "flac"]
            }
            panel.beginSheetModal(for: window) { response in
                guard response == .OK else { result([]); return }
                let urls = panel.urls
                DispatchQueue.global(qos: .userInitiated).async {
                    let entries = self.stageVoiceMemos(urls)
                    DispatchQueue.main.async { result(entries) }
                }
            }
            return
        }
        guard call.method == "share" || call.method == "reveal" else {
            result(FlutterMethodNotImplemented); return
        }
        guard let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String,
              FileManager.default.fileExists(atPath: path) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Il file della registrazione non è disponibile.", details: nil)); return
        }
        let url = URL(fileURLWithPath: path)
        if call.method == "reveal" {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            guard let view = controller?.view else {
                result(FlutterError(code: "NO_WINDOW", message: "Impossibile aprire il pannello.", details: nil)); return
            }
            let picker = NSSharingServicePicker(items: [url])
            sharePicker = picker
            picker.show(relativeTo: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1),
                        of: view, preferredEdge: .minY)
        }
        result(nil)
    }

    private func stageVoiceMemos(_ urls: [URL]) -> [[String: Any]] {
        var entries = [[String: Any]]()
        let manager = FileManager.default
        for selected in urls {
            let scoped = selected.startAccessingSecurityScopedResource()
            defer { if scoped { selected.stopAccessingSecurityScopedResource() } }
            var isDirectory: ObjCBool = false
            manager.fileExists(atPath: selected.path, isDirectory: &isDirectory)
            let files: [URL]
            if isDirectory.boolValue {
                files = (manager.enumerator(at: selected, includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])?.allObjects as? [URL] ?? [])
                    .filter { ["m4a", "wav", "flac"].contains($0.pathExtension.lowercased()) }
                    .sorted { $0.path < $1.path }
            } else { files = [selected] }
            for source in files {
                var temporary: URL?
                do {
                    let directory = manager.temporaryDirectory.appendingPathComponent("wavnote-import-" + UUID().uuidString)
                    temporary = directory
                    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                    let target = directory.appendingPathComponent(source.lastPathComponent)
                    var copyError: Error?
                    var coordinationError: NSError?
                    NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                        do { try manager.copyItem(at: readable, to: target) } catch { copyError = error }
                    }
                    if let error = coordinationError { throw error }
                    if let error = copyError { throw error }
                    let audio = try AVAudioFile(forReading: target)
                    let rate = audio.processingFormat.sampleRate
                    guard rate > 0, audio.length > 0 else { throw NSError(domain: "WavNoteImport", code: 1) }
                    let attributes = try manager.attributesOfItem(atPath: source.path)
                    let date = attributes[.creationDate] as? Date ?? Date()
                    entries.append(["path": target.path, "name": source.deletingPathExtension().lastPathComponent,
                        "durationMs": Int(Double(audio.length) / rate * 1000), "sampleRate": Int(rate),
                        "createdAtMs": Int(date.timeIntervalSince1970 * 1000)])
                } catch {
                    if let temporary = temporary { try? manager.removeItem(at: temporary) }
                    entries.append(["name": source.lastPathComponent, "error": error.localizedDescription])
                }
            }
        }
        return entries
    }
}
