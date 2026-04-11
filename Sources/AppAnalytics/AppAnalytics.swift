import Foundation
import SentinelCore

public final class AppAnalytics: @unchecked Sendable {
    public static let shared = AppAnalytics()

    private let sinks: AnalyticsSinkRegistry

    public init(sinks: [AnalyticsSink] = []) {
        self.sinks = AnalyticsSinkRegistry(sinks: sinks)
    }

    public func register(sink: AnalyticsSink) {
        sinks.register(sink)
    }

    public func screen(_ name: String, properties: [String: TelemetryValue] = .empty) {
        track(AnalyticsEvent(name: name, kind: .screen, properties: properties))
    }

    public func track(
        _ name: String,
        kind: AnalyticsEventKind = .action,
        properties: [String: TelemetryValue] = .empty
    ) {
        track(AnalyticsEvent(name: name, kind: kind, properties: properties))
    }

    private func track(_ event: AnalyticsEvent) {
        for sink in sinks.snapshot() {
            sink.track(event)
        }
    }
}
