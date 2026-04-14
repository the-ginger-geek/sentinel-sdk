import AppAnalytics
import Foundation
import SentinelCore

public enum SentinelEndpointResolutionMode: String, Sendable {
    case explicitURL = "explicit_url"
    case envURL = "env_url"
    case derivedFirebase = "derived_firebase"
}

public struct SentinelEndpointResolution: Sendable {
    public let url: URL
    public let mode: SentinelEndpointResolutionMode

    public init(url: URL, mode: SentinelEndpointResolutionMode) {
        self.url = url
        self.mode = mode
    }
}

public struct SentinelEndpointConfiguration {
    public var baseURL: URL?
    public var ingestURL: URL?
    public var projectID: String?
    public var region: String?
    public var functionName: String?
    public var environment: [String: String]?
    public var infoDictionary: [String: Any]?

    public init(
        baseURL: URL? = nil,
        ingestURL: URL? = nil,
        projectID: String? = nil,
        region: String? = nil,
        functionName: String? = nil,
        environment: [String: String]? = nil,
        infoDictionary: [String: Any]? = nil
    ) {
        self.baseURL = baseURL
        self.ingestURL = ingestURL
        self.projectID = projectID
        self.region = region
        self.functionName = functionName
        self.environment = environment
        self.infoDictionary = infoDictionary
    }
}

public struct SentinelHTTPTransport {
    public let telemetrySink: TelemetrySink
    public let analyticsSink: AnalyticsSink

    private let client: Client

    public init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil) {
        self.init(baseURL: baseURL, apiKey: apiKey, projectSlug: projectSlug, userId: userId, session: .shared)
    }

    public init(
        apiKey: String,
        projectSlug: String,
        userId: String? = nil,
        baseURL: URL? = nil,
        ingestURL: URL? = nil,
        projectID: String? = nil,
        region: String? = nil,
        functionName: String? = nil,
        environment: [String: String]? = nil,
        infoDictionary: [String: Any]? = nil,
        diagnostics: ((String) -> Void)? = nil
    ) throws {
        let resolution = try Self.resolveIngestEndpoint(
            SentinelEndpointConfiguration(
                baseURL: baseURL,
                ingestURL: ingestURL,
                projectID: projectID,
                region: region,
                functionName: functionName,
                environment: environment,
                infoDictionary: infoDictionary
            )
        )

        diagnostics?("Sentinel endpoint resolution mode: \(resolution.mode.rawValue)")
        self.init(baseURL: resolution.url, apiKey: apiKey, projectSlug: projectSlug, userId: userId, session: .shared)
    }

    public static func resolveIngestEndpoint(_ config: SentinelEndpointConfiguration = .init()) throws -> SentinelEndpointResolution {
        if let explicit = config.baseURL ?? config.ingestURL {
            return SentinelEndpointResolution(url: explicit, mode: .explicitURL)
        }

        let environment = config.environment ?? ProcessInfo.processInfo.environment
        let infoDictionary = config.infoDictionary ?? Bundle.main.infoDictionary

        if let envURLString = firstNonEmpty(environment["SENTINEL_INGEST_URL"], infoDictionary?["SENTINEL_INGEST_URL"] as? String),
           let envURL = URL(string: envURLString)
        {
            return SentinelEndpointResolution(url: envURL, mode: .envURL)
        }

        let projectID = firstNonEmpty(
            config.projectID,
            environment["SENTINEL_FIREBASE_PROJECT_ID"],
            environment["SENTINEL_PROJECT_ID"],
            infoDictionary?["SENTINEL_FIREBASE_PROJECT_ID"] as? String,
            infoDictionary?["SENTINEL_PROJECT_ID"] as? String
        )

        if let projectID {
            let region = firstNonEmpty(
                config.region,
                environment["SENTINEL_FIREBASE_REGION"],
                infoDictionary?["SENTINEL_FIREBASE_REGION"] as? String
            ) ?? "us-central1"

            let functionName = firstNonEmpty(
                config.functionName,
                environment["SENTINEL_FIREBASE_FUNCTION"],
                infoDictionary?["SENTINEL_FIREBASE_FUNCTION"] as? String
            ) ?? "ingestEvent"

            guard let url = URL(string: "https://\(region)-\(projectID).cloudfunctions.net/\(functionName)") else {
                throw EndpointResolutionError.message(
                    "Unable to build a valid ingest URL from derived Firebase settings. " + resolutionGuidance
                )
            }

            return SentinelEndpointResolution(url: url, mode: .derivedFirebase)
        }

        throw EndpointResolutionError.message("Unable to resolve Sentinel ingest endpoint. " + resolutionGuidance)
    }

    init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil, session: URLSession) {
        let client = Client(baseURL: baseURL, apiKey: apiKey, projectSlug: projectSlug, userId: userId, session: session)
        self.client = client
        self.telemetrySink = TelemetryHTTPSink(client: client)
        self.analyticsSink = AnalyticsHTTPSink(client: client)
    }

    /// Update the user identifier sent on all subsequent events.
    /// Pass `nil` to clear (e.g. on logout).
    public func setUserId(_ userId: String?) {
        Task { await client.setUserId(userId) }
    }

    private actor Client {
        private let baseURL: URL
        private let apiKey: String
        private let projectSlug: String
        private var userId: String?
        private let session: URLSession

        init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil, session: URLSession = .shared) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.projectSlug = projectSlug
            self.userId = userId
            self.session = session
        }

        func setUserId(_ userId: String?) {
            self.userId = userId
        }

        func sendTelemetry(_ event: TelemetryEvent) async {
            var eventPayload: [String: Any] = [
                "name": event.name,
                "level": event.level.rawValue,
                "message": event.message as Any,
                "metadata": jsonObject(event.metadata),
                "timestamp": event.timestamp.ISO8601Format(),
            ]
            if let userId { eventPayload["user_hash"] = userId }
            await send(stream: "telemetry", source: projectSlug, event: eventPayload)
        }

        func sendAnalytics(_ event: AnalyticsEvent) async {
            var eventPayload: [String: Any] = [
                "name": event.name,
                "kind": event.kind.rawValue,
                "properties": jsonObject(event.properties),
                "timestamp": event.timestamp.ISO8601Format(),
            ]
            if let userId { eventPayload["user_hash"] = userId }
            await send(stream: "analytics", source: projectSlug, event: eventPayload)
        }

        private func send(stream: String, source: String, event: [String: Any]) async {
            let payload: [String: Any] = [
                "stream": stream,
                "source": source,
                "event": event,
            ]

            guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                return
            }

            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = body

            _ = try? await session.data(for: request)
        }

        private func jsonObject(_ values: [String: TelemetryValue]) -> [String: Any] {
            values.mapValues(jsonValue)
        }

        private func jsonValue(_ value: TelemetryValue) -> Any {
            switch value {
            case .string(let string):
                return string
            case .int(let int):
                return int
            case .double(let double):
                return double
            case .bool(let bool):
                return bool
            case .array(let array):
                return array.map(jsonValue)
            case .object(let object):
                return object.mapValues(jsonValue)
            case .null:
                return NSNull()
            }
        }
    }

    private struct TelemetryHTTPSink: TelemetrySink {
        let client: Client

        func record(_ event: TelemetryEvent) {
            Task {
                await client.sendTelemetry(event)
            }
        }
    }

    private struct AnalyticsHTTPSink: AnalyticsSink {
        let client: Client

        func track(_ event: AnalyticsEvent) {
            Task {
                await client.sendAnalytics(event)
            }
        }
    }
}

private enum EndpointResolutionError: Error {
    case message(String)
}

extension EndpointResolutionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private let resolutionGuidance = [
    "Accepted configuration paths:",
    "1) baseURL/ingestURL in SDK config (explicit URL)",
    "2) SENTINEL_INGEST_URL in environment or Info.plist",
    "3) Derived Firebase mode using projectID/SENTINEL_FIREBASE_PROJECT_ID/SENTINEL_PROJECT_ID with optional region/functionName",
    "Cross-project deployments should prefer SENTINEL_INGEST_URL.",
].joined(separator: " ")

private func firstNonEmpty(_ values: String?...) -> String? {
    for candidate in values {
        guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            continue
        }
        return value
    }
    return nil
}
