import Foundation

extension Optional where Wrapped == String {
    /// `nil` for a missing or empty string.
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
