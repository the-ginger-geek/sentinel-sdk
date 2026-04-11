import Foundation

final class AnalyticsSinkRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var sinks: [AnalyticsSink]

    init(sinks: [AnalyticsSink]) {
        self.sinks = sinks
    }

    func register(_ sink: AnalyticsSink) {
        lock.lock()
        sinks.append(sink)
        lock.unlock()
    }

    func snapshot() -> [AnalyticsSink] {
        lock.lock()
        let current = sinks
        lock.unlock()
        return current
    }
}
