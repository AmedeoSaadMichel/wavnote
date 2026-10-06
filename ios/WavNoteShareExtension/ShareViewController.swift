import UIKit
import MobileCoreServices

/// Receives all selected audio attachments without launching the containing app
/// through unsupported extension APIs. Files survive until WavNote imports them.
final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let done = UIButton(type: .system)
    private var started = false
    private var imported = 0
    private var failures = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        preferredContentSize = CGSize(width: 420, height: 300)
        let title = UILabel()
        title.text = "Importa in WavNote"
        title.font = .preferredFont(forTextStyle: .title2)
        status.numberOfLines = 0
        status.text = "Preparazione delle registrazioni…"
        done.setTitle("Fine", for: .normal)
        done.isEnabled = false
        done.addTarget(self, action: #selector(finish), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, status, progress, done])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        importNext(providers, index: 0)
    }

    private func importNext(_ providers: [NSItemProvider], index: Int) {
        guard index < providers.count else {
            progress.progress = 1
            status.text = "Registrazioni ricevute: \(imported).\nApri WavNote per completare l’importazione in Tutte le registrazioni."
            if !failures.isEmpty {
                status.text! += "\nNon ricevute: \(failures.count).\n" + failures.prefix(3).joined(separator: "\n")
            }
            if providers.isEmpty { status.text = "Nessun file audio da importare." }
            done.isEnabled = true
            return
        }
        status.text = "Ricezione \(index + 1) di \(providers.count)…"
        progress.progress = Float(index) / Float(providers.count)
        let provider = providers[index]
        let audioType = provider.registeredTypeIdentifiers.first {
            UTTypeConformsTo($0 as CFString, kUTTypeAudio)
        }
        let preferredExtension = audioType.flatMap { UTTypeCopyPreferredTagWithClass($0 as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as String? }
        let complete: (URL?, Error?) -> Void = { url, error in
            var failure: String?
            if let url = url {
                do { try SharedAudioInbox.enqueue(url, suggestedName: provider.suggestedName, fileExtension: preferredExtension) }
                catch { failure = error.localizedDescription }
            } else { failure = error?.localizedDescription ?? "File audio non disponibile." }
            DispatchQueue.main.async {
                if let failure = failure { self.failures.append(failure) }
                else { self.imported += 1 }
                self.importNext(providers, index: index + 1)
            }
        }
        if let audioType = audioType {
            // Copy inside the completion handler: Apple removes its temporary
            // file as soon as this callback returns.
            provider.loadFileRepresentation(forTypeIdentifier: audioType, completionHandler: complete)
        } else if provider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
            provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { item, error in
                complete(item as? URL, error)
            }
        } else {
            complete(nil, NSError(domain: "WavNoteShare", code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Formato audio non supportato."]))
        }
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
