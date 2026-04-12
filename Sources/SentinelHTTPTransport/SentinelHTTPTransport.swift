import AppAnalytics
import Foundation
import SentinelCore

public struct SentinelHTTPTransport {
    public let telemetrySink: TelemetrySink
    public let analyticsSink: AnalyticsSink

    public init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil) {
        self.init(baseURL: baseURL, apiKey: apiKey, projectSlug: projectSlug, userId: userId, session: .shared)
    }

    init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil, session: URLSession) {
        let client = Client(baseURL: baseURL, apiKey: apiKey, projectSlug: projectSlug, userId: userId, session: session)
        self.telemetrySink = TelemetryHTTPSink(client: client)
        self.analyticsSink = AnalyticsHTTPSink(client: client)
    }

    private actor Client {
        private let baseURL: URL
        private let apiKey: String
        private let projectSlug: String
        private let userId: String?
        private let session: URLSession

        init(baseURL: URL, apiKey: String, projectSlug: String, userId: String? = nil, session: URLSession = .shared) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.projectSlug = projectSlug
            self.userId = userId
            self.session = session
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
