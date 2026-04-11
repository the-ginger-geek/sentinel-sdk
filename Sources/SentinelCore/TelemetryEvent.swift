import Foundation

public enum TelemetryLevel: String, Sendable, Equatable {
    case debug
    case info
    case warning
    case error
    case critical
}

public struct TelemetryEvent: Sendable, Equatable {
    public let level: TelemetryLevel
    public let name: String
    public let message: String?
    public let metadata: [String: TelemetryValue]
    public let timestamp: Date

    public init(
        level: TelemetryLevel,
        name: String,
        message: String? = nil,
        metadata: [String: TelemetryValue] = .empty,
        timestamp: Date = Date()
    ) {
        self.level = level
        self.name = name
        self.message = message
        self.metadata = metadata
        self.timestamp = timestamp
    }
}
