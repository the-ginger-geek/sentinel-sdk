import Foundation

public protocol TelemetrySink: Sendable {
    func record(_ event: TelemetryEvent)
}
