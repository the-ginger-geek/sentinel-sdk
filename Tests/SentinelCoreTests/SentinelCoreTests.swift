import Foundation
import Testing
@testable import SentinelCore

private final class RecordingSink: TelemetrySink, @unchecked Sendable {
    private(set) var events: [TelemetryEvent] = []

    func record(_ event: TelemetryEvent) {
        events.append(event)
    }
}

private struct StaticProbe: EnvironmentProbe {
    let values: [String: TelemetryValue]

    func snapshot() -> [String: TelemetryValue] {
        values
    }
}

@Test
func sentinelRecordsErrorsWithContext() {
    let sink = RecordingSink()
    let sentinel = Sentinel(sinks: [sink], probes: [StaticProbe(values: ["env": "test"])])

    enum SampleError: Error {
        case failed
    }

    sentinel.record(error: SampleError.failed, name: "unit_error", metadata: ["flow": "signup"])

    #expect(sink.events.count == 1)
    #expect(sink.events[0].name == "unit_error")
    #expect(sink.events[0].metadata["flow"] == "signup")
    #expect(sink.events[0].metadata["env"] == "test")
    #expect(sink.events[0].metadata["error_type"] != nil)
    #expect(sink.events[0].metadata["error_description"] != nil)
}

@Test
func sentinelLogMergesProbeMetadataWithEventMetadata() {
    let sink = RecordingSink()
    let sentinel = Sentinel(
        sinks: [sink],
        probes: [StaticProbe(values: ["environment": "production", "app_version": "1.0.0"])])

    sentinel.log(level: .info, name: "app_started", metadata: ["app_version": "1.1.0", "release_channel": "stable"])

    #expect(sink.events.count == 1)
    #expect(sink.events[0].metadata["environment"] == "production")
    #expect(sink.events[0].metadata["app_version"] == "1.1.0")
    #expect(sink.events[0].metadata["release_channel"] == "stable")
}

@Test
func sentinelMergesEnvironmentProbes() {
    let sentinel = Sentinel(
        probes: [
            StaticProbe(values: ["env": "test"]),
            StaticProbe(values: ["region": "za"]),
        ]
    )

    let snapshot = sentinel.probeEnvironment()

    #expect(snapshot["env"] == "test")
    #expect(snapshot["region"] == "za")
}
