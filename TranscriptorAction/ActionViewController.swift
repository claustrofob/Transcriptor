import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import TranscriptorKit

@MainActor
class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await extractText()

            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                extensionContext?.completeRequest(returningItems: nil)
                return
            }

            guard let container = try? HistoryStore.makeContainer() else {
                extensionContext?.completeRequest(returningItems: nil)
                return
            }

            let actionView = ActionView(
                sourceText: text,
                onDone: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            )
            .modelContainer(container)

            embedSwiftUIView(actionView)
        }
    }

    // MARK: - Embedding

    private func embedSwiftUIView<V: View>(_ rootView: V) {
        let hostingController = UIHostingController(rootView: rootView)
        // The host app owns the sheet and renders this view from another process. Touches on
        // pixels drawn by the extension go to the extension; touches on transparent areas reach
        // the host, where the sheet's pull-to-dismiss lives. UIHostingController paints an opaque
        // systemBackground by default, which swallowed every drag. The host's sheet provides the
        // background, so keep ours clear.
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)
    }

    // MARK: - Text extraction

    /// The first shared plain text, or else the first shared URL as a string.
    private func extractText() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        for provider in providers {
            for type in [UTType.plainText, .url] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                switch try? await provider.loadItem(forTypeIdentifier: type.identifier) {
                case let text as String: return text
                case let url as URL: return url.absoluteString
                default: continue
                }
            }
        }
        return nil
    }
}
