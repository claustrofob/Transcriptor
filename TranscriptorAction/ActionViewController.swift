import UIKit
import SwiftUI
import SwiftData
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

            let container: ModelContainer
            do {
                container = try HistoryStore.makeContainer()
            } catch {
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

            let hostingController = UIHostingController(rootView: actionView)

            // Enable interactive dismiss gesture
            hostingController.isModalInPresentation = false
            if let sheetController = hostingController.sheetPresentationController {
                sheetController.prefersGrabberVisible = true
                sheetController.detents = [.medium(), .large()]
            }

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractiveDismiss()
    }

    /// Walk the entire view controller hierarchy to find every presentation controller
    /// and allow interactive dismiss. Action Extensions are wrapped by the system in
    /// additional container controllers, so we must traverse upward.
    private func enableInteractiveDismiss() {
        // Walk up parent chain — set isModalInPresentation = false on every VC
        var vc: UIViewController? = self
        while let current = vc {
            current.isModalInPresentation = false
            if let pc = current.presentationController {
                pc.delegate = self
            }
            vc = current.parent
        }

        // Also try the presenting controller's presentation controller
        if let presenting = presentingViewController {
            presenting.isModalInPresentation = false
            presenting.presentationController?.delegate = self
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

// MARK: - Interactive dismiss support

extension ActionViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        true
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        extensionContext?.completeRequest(returningItems: nil)
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
