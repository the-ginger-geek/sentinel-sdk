import Foundation
import SentinelCore

public enum AnalyticsEventKind: String, Sendable, Equatable {
    case screen
    case action
    case conversion
    case state
}

public struct AnalyticsEvent: Sendable, Equatable {
    public let name: String
    public let kind: AnalyticsEventKind
    public let properties: [String: TelemetryValue]
    public let timestamp: Date

    public init(
        name: String,
        kind: AnalyticsEventKind,
        properties: [String: TelemetryValue] = .empty,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.kind = kind
        self.properties = properties
        self.timestamp = timestamp
    }
}
