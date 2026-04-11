import Foundation

public final class Sentinel: @unchecked Sendable {
    public static let shared = Sentinel()

    private let sinks: SentinelSinkRegistry
    private let probes: SentinelProbeRegistry

    public init(
        sinks: [TelemetrySink] = [],
        probes: [EnvironmentProbe] = [DefaultEnvironmentProbe()]
    ) {
        self.sinks = SentinelSinkRegistry(sinks: sinks)
        self.probes = SentinelProbeRegistry(probes: probes)
    }

    public func register(sink: TelemetrySink) {
        sinks.register(sink)
    }

    public func register(probe: EnvironmentProbe) {
        probes.register(probe)
    }

    public func log(
        level: TelemetryLevel,
        name: String,
        message: String? = nil,
        metadata: [String: TelemetryValue] = .empty
    ) {
        let event = TelemetryEvent(level: level, name: name, message: message, metadata: metadata)
        record(event)
    }

    public func record(
        error: any Error,
        name: String = "error",
        metadata: [String: TelemetryValue] = .empty
    ) {
        var payload = metadata
        payload["error_type"] = .string(String(reflecting: type(of: error)))
        payload["error_description"] = .string(error.localizedDescription)

        let event = TelemetryEvent(
            level: .error,
            name: name,
            message: error.localizedDescription,
            metadata: payload
        )

        record(event)
    }

    public func probeEnvironment() -> [String: TelemetryValue] {
        probes.mergedSnapshot()
    }

    public func diagnosticEvent(name: String = "environment_probe") -> TelemetryEvent {
        TelemetryEvent(
            level: .info,
            name: name,
            metadata: probeEnvironment()
        )
    }

    private func record(_ event: TelemetryEvent) {
        var metadata = probeEnvironment()
        metadata.merge(event.metadata, uniquingKeysWith: { _, eventValue in eventValue })

        let enrichedEvent = TelemetryEvent(
            level: event.level,
            name: event.name,
            message: event.message,
            metadata: metadata,
            timestamp: event.timestamp
        )

        for sink in sinks.snapshot() {
            sink.record(enrichedEvent)
        }
    }
}
