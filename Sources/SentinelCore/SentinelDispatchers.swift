import Foundation

final class SentinelSinkRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var sinks: [TelemetrySink]

    init(sinks: [TelemetrySink]) {
        self.sinks = sinks
    }

    func register(_ sink: TelemetrySink) {
        lock.lock()
        sinks.append(sink)
        lock.unlock()
    }

    func snapshot() -> [TelemetrySink] {
        lock.lock()
        let current = sinks
        lock.unlock()
        return current
    }
}

final class SentinelProbeRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var probes: [EnvironmentProbe]

    init(probes: [EnvironmentProbe]) {
        self.probes = probes
    }

    func register(_ probe: EnvironmentProbe) {
        lock.lock()
        probes.append(probe)
        lock.unlock()
    }

    func mergedSnapshot() -> [String: TelemetryValue] {
        lock.lock()
        let current = probes
        lock.unlock()

        return current.reduce(into: [String: TelemetryValue]()) { partialResult, probe in
            partialResult.merge(probe.snapshot(), uniquingKeysWith: { _, new in new })
        }
    }
}
