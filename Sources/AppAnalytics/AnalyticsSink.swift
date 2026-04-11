import Foundation

public protocol AnalyticsSink: Sendable {
    func track(_ event: AnalyticsEvent)
}
