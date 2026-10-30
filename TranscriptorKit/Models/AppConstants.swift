import Foundation

public enum AppConstants {
    public static let appGroupID = "group.com.claustrofob.Transcriptor"
    public static let keychainServiceName = "com.claustrofob.Transcriptor.apikey"
    public static let keychainAccessGroup = "group.com.claustrofob.Transcriptor"
    public static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    public static let claudeMessagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let claudeAPIVersion = "2026-10-21"
    public static let claudeFallbackBeta = "server-side-fallback-2026-07-01"
}
