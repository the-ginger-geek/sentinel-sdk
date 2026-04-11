import Foundation
import Testing
@testable import AppAnalytics
import SentinelCore

private final class RecordingSink: AnalyticsSink, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

@Test
func analyticsTracksScreensAndActions() {
    let sink = RecordingSink()
    let analytics = AppAnalytics(sinks: [sink])

    analytics.screen("paywall", properties: ["entry_point": "settings"])
    analytics.track("upgrade_tapped", kind: .conversion, properties: ["plan": "pro"])

    #expect(sink.events.count == 2)
    #expect(sink.events[0].kind == .screen)
    #expect(sink.events[0].properties["entry_point"] == "settings")
    #expect(sink.events[1].kind == .conversion)
    #expect(sink.events[1].properties["plan"] == "pro")
}
