import UIKit
import SwiftUI
import UniformTypeIdentifiers
import TranscriptorKit

@MainActor
class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            let text = await extractText()

            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                extensionContext?.completeRequest(returningItems: nil)
                return
            }

            let actionView = ActionView(
                sourceText: text,
                onDone: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            )

            let hostingController = UIHostingController(rootView: actionView)
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
    }

    // MARK: - Text extraction

    private func extractText() async -> String? {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    do {
                        let result = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        if let text = result as? String {
                            return text
                        }
                    } catch {
                        continue
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    do {
                        let result = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                        if let url = result as? URL {
                            return url.absoluteString
                        }
                    } catch {
                        continue
                    }
                }
            }
        }

        return nil
    }
}
