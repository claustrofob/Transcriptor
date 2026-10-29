import Foundation

public enum TranslationType: String, Codable, CaseIterable, Sendable {
    case word
    case expression
    case freeText

    public var displayName: String {
        switch self {
        case .word: "Word"
        case .expression: "Expression"
        case .freeText: "Free text"
        }
    }
}
