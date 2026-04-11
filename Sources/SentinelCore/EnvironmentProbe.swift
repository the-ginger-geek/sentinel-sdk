import Foundation

public protocol EnvironmentProbe: Sendable {
    func snapshot() -> [String: TelemetryValue]
}
