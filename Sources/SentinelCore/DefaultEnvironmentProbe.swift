import Foundation

public struct DefaultEnvironmentProbe: EnvironmentProbe {
    public init() {}

    public func snapshot() -> [String: TelemetryValue] {
        var values: [String: TelemetryValue] = [
            "process_name": .string(ProcessInfo.processInfo.processName),
            "os_version": .string(ProcessInfo.processInfo.operatingSystemVersionString),
            "is_low_power_mode_enabled": .bool(ProcessInfo.processInfo.isLowPowerModeEnabled),
            "temp_directory_writable": .bool(canWrite(to: FileManager.default.temporaryDirectory)),
        ]

        if let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty {
            values["bundle_identifier"] = .string(bundleID)
        }

        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, !appVersion.isEmpty {
            values["app_version"] = .string(appVersion)
        }

        if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, !buildNumber.isEmpty {
            values["build_number"] = .string(buildNumber)
        }

        return values
    }

    private func canWrite(to url: URL) -> Bool {
        let fileURL = url.appendingPathComponent("sentinel-kit.write-test.\(UUID().uuidString)")
        do {
            try Data("ok".utf8).write(to: fileURL)
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
}
