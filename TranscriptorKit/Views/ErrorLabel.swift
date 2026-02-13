import SwiftUI

/// Standardized error label with warning icon.
public struct ErrorLabel: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
    }
}
