// File: ios/Runner/RecordingFileActions.swift
import Flutter
import UIKit
import QuickLook
import UniformTypeIdentifiers
import AVFoundation

final class RecordingFileActions: NSObject, UIDocumentPickerDelegate {
    private var importResult: FlutterResult?
    private weak var controller: UIViewController?
    private let channel: FlutterMethodChannel

    init(controller: FlutterViewController) {
        self.controller = controller
        channel = FlutterMethodChannel(name: "wavnote/file_actions", binaryMessenger: controller.binaryMessenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "pendingSharedAudio" || call.method == "acknowledgeSharedAudio" {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let value: Any?
                    if call.method == "pendingSharedAudio" {
                        value = try SharedAudioInbox.pendingEntries()
                    } else {
                        let ids = (call.arguments as? [String: Any])?["ids"] as? [String] ?? []
                        try SharedAudioInbox.acknowledge(ids)
                        value = nil
                    }
                    DispatchQueue.main.async { result(value) }
                } catch {
                    DispatchQueue.main.async { result(FlutterError(code: "SHARED_AUDIO_FAILED", message: error.localizedDescription, details: nil)) }
                }
            }
            return
        }
        if call.method == "pickVoiceMemos" {
            guard importResult == nil, let presenter = controller, presenter.presentedViewController == nil else {
                result(FlutterError(code: "BUSY", message: "Un pannello è già aperto.", details: nil)); return
            }
            let folder = (call.arguments as? [String: Any])?["folder"] as? Bool ?? false
            let picker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                picker = UIDocumentPickerViewController(forOpeningContentTypes: folder ? [.folder] : [.audio], asCopy: false)
            } else {
                picker = UIDocumentPickerViewController(documentTypes: folder ? ["public.folder"] : ["public.audio"], in: .open)
            }
            picker.allowsMultipleSelection = !folder
            picker.delegate = self
            importResult = result
            presenter.present(picker, animated: true)
            return
        }
        guard call.method == "share" || call.method == "reveal" else {
            result(FlutterMethodNotImplemented); return
        }
        guard let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String,
              FileManager.default.fileExists(atPath: path) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Il file della registrazione non è disponibile.", details: nil)); return
        }
        guard var presenter = controller else {
            result(FlutterError(code: "NO_WINDOW", message: "Impossibile aprire il pannello.", details: nil)); return
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        let url = URL(fileURLWithPath: path)
        if call.method == "share" {
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = presenter.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY, width: 1, height: 1)
            presenter.present(sheet, animated: true) { result(nil) }
        } else {
            do {
                let location = try RecordingLocationViewController(fileURL: url)
                presenter.present(UINavigationController(rootViewController: location), animated: true) { result(nil) }
            } catch {
                result(FlutterError(code: "REVEAL_FAILED",
                    message: "Impossibile mostrare la posizione della registrazione.", details: nil))
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let callback = importResult
        importResult = nil
        callback?([])
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let callback = importResult else { return }
        importResult = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let entries = self.stageVoiceMemos(urls)
            DispatchQueue.main.async { callback(entries) }
        }
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


/// Cartella reale con scorrimento e indicazione persistente del file richiesto.
private final class RecordingLocationViewController: UITableViewController, QLPreviewControllerDataSource {
    private let fileURL: URL
    private let files: [URL]
    private let selectedIndex: Int
    private var previewURL: URL

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        previewURL = fileURL
        files = try FileManager.default.contentsOfDirectory(at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard let index = files.firstIndex(where: { $0.lastPathComponent == fileURL.lastPathComponent }) else {
            throw NSError(domain: "RecordingLocation", code: 1)
        }
        selectedIndex = index
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("Inizializzazione tramite URL richiesta") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Posizione della registrazione"
        navigationItem.prompt = fileURL.lastPathComponent
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
            target: self, action: #selector(close))
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.scrollToRow(at: IndexPath(row: selectedIndex, section: 0), at: .middle, animated: false)
    }

    @objc private func close() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { files.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let directory = fileURL.deletingLastPathComponent().standardizedFileURL.path
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].standardizedFileURL.path
        if directory == documents || directory.hasPrefix(documents + "/") {
            let relative = String(directory.dropFirst(documents.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "Sul dispositivo / WavNote" + (relative.isEmpty ? "" : " / " + relative)
        }
        return "Cartella: " + directory
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "file") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "file")
        let isTarget = indexPath.row == selectedIndex
        cell.textLabel?.text = files[indexPath.row].lastPathComponent
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = isTarget ? "Registrazione selezionata" : nil
        cell.imageView?.image = UIImage(systemName: isTarget ? "checkmark.circle.fill" : "waveform")
        cell.imageView?.tintColor = isTarget ? .systemBlue : .secondaryLabel
        cell.backgroundColor = isTarget ? UIColor.systemBlue.withAlphaComponent(0.15) : .secondarySystemGroupedBackground
        cell.accessibilityTraits = isTarget ? [.button, .selected] : [.button]
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        previewURL = files[indexPath.row]
        let preview = QLPreviewController()
        preview.dataSource = self
        navigationController?.pushViewController(preview, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { previewURL as NSURL }
}
