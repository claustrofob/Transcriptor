import SwiftUI
import UIKit

extension View {
    /// Dismisses the keyboard on any tap outside a text input while this view is on screen.
    /// Unlike `onTapGesture` on a `Form`, this also catches taps on empty space between sections,
    /// and it doesn't cancel touches, so buttons, pickers and segmented controls keep working.
    public func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissTapInstaller())
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        InstallerView()
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    /// Attaches the tap recognizer to the window while in the hierarchy, and removes it when the view leaves
    /// (e.g. when switching to another tab). The recognizer only receives touches while the keyboard is shown,
    /// so it never interferes with menus and other controls otherwise.
    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private var isKeyboardVisible = false

        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func keyboardWillShow() {
            isKeyboardVisible = true
        }

        @objc private func keyboardWillHide() {
            isKeyboardVisible = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)
        }

        @objc private func handleTap() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard isKeyboardVisible else { return false }
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
