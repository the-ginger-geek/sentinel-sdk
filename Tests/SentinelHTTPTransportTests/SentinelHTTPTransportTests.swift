import Foundation
import Testing
@testable import SentinelHTTPTransport
import SentinelCore
import AppAnalytics

private final class RequestCapture {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    func snapshot() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func reset() {
        lock.lock()
        requests.removeAll()
        lock.unlock()
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let capture = RequestCapture()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.capture.append(request)

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.invalid")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func waitForRequestCount(_ expected: Int, timeoutNanoseconds: UInt64 = 1_000_000_000) async -> [URLRequest] {
    let started = DispatchTime.now().uptimeNanoseconds

    while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
        let requests = MockURLProtocol.capture.snapshot()
        if requests.count >= expected {
            return requests
        }

        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    return MockURLProtocol.capture.snapshot()
}

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while stream.hasBytesAvailable {
        let readCount = stream.read(&buffer, maxLength: buffer.count)
        guard readCount > 0 else { break }
        data.append(buffer, count: readCount)
    }

    return data.isEmpty ? nil : data
}

@Suite(.serialized)
struct SentinelHTTPTransportTests {
    @Test
    func endpointResolutionPrefersExplicitURL() throws {
        let resolution = try SentinelHTTPTransport.resolveIngestEndpoint(
            .init(
                baseURL: URL(string: "https://explicit.example.com/ingestEvent"),
                projectID: "sentinel-8997b",
                environment: ["SENTINEL_INGEST_URL": "https://env.example.com/ingestEvent"]
            )
        )

        #expect(resolution.mode == .explicitURL)
        #expect(resolution.url.absoluteString == "https://explicit.example.com/ingestEvent")
    }

    @Test
    func endpointResolutionPrefersIngestURL() throws {
        let resolution = try SentinelHTTPTransport.resolveIngestEndpoint(
            .init(
                ingestURL: URL(string: "https://ingest.example.com/ingestEvent")
            )
        )

        #expect(resolution.mode == .explicitURL)
        #expect(resolution.url.absoluteString == "https://ingest.example.com/ingestEvent")
    }

    @Test
    func endpointResolutionUsesEnvURLBeforeDerived() throws {
        let resolution = try SentinelHTTPTransport.resolveIngestEndpoint(
            .init(
                environment: [
                    "SENTINEL_INGEST_URL": "https://env.example.com/ingestEvent",
                    "SENTINEL_FIREBASE_PROJECT_ID": "sentinel-8997b",
                ]
            )
        )

        #expect(resolution.mode == .envURL)
        #expect(resolution.url.absoluteString == "https://env.example.com/ingestEvent")
    }

    @Test
    func endpointResolutionSupportsInfoDictionaryEnvURL() throws {
        let resolution = try SentinelHTTPTransport.resolveIngestEndpoint(
            .init(
                environment: [:],
                infoDictionary: ["SENTINEL_INGEST_URL": "https://plist.example.com/ingestEvent"]
            )
        )

        #expect(resolution.mode == .envURL)
        #expect(resolution.url.absoluteString == "https://plist.example.com/ingestEvent")
    }

    @Test
    func endpointResolutionSupportsDerivedAliasProjectID() throws {
        let resolution = try SentinelHTTPTransport.resolveIngestEndpoint(
            .init(
                environment: [
                    "SENTINEL_PROJECT_ID": "sentinel-8997b",
                    "SENTINEL_FIREBASE_REGION": "europe-west1",
                    "SENTINEL_FIREBASE_FUNCTION": "ingestEvent",
                ]
            )
        )

        #expect(resolution.mode == .derivedFirebase)
        #expect(resolution.url.absoluteString == "https://europe-west1-sentinel-8997b.cloudfunctions.net/ingestEvent")
    }

    @Test
    func endpointResolutionFailureIsActionable() {
        do {
            _ = try SentinelHTTPTransport.resolveIngestEndpoint(.init(environment: [:], infoDictionary: [:]))
            Issue.record("Expected endpoint resolution to fail")
        } catch {
            let description = (error as NSError).localizedDescription
            #expect(description.contains("baseURL/ingestURL"))
            #expect(description.contains("SENTINEL_INGEST_URL"))
            #expect(description.contains("SENTINEL_FIREBASE_PROJECT_ID"))
            #expect(description.contains("Cross-project deployments"))
        }
    }

    @Test
    func telemetrySinkSendsExpectedPayloadAndHeaders() async throws {
        MockURLProtocol.capture.reset()

        let session = makeSession()
        let transport = SentinelHTTPTransport(
            baseURL: URL(string: "https://ingest.example.com/v1/events")!,
            apiKey: "test-key",
            projectSlug: "tally-app",
            session: session
        )

        let event = TelemetryEvent(
            level: .error,
            name: "network_failure",
            message: "Request failed",
            metadata: ["status_code": 500, "retry": true, "tags": ["ios", "api"], "context": ["flow": "sync"]],
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        transport.telemetrySink.record(event)

        let requests = await waitForRequestCount(1)
        #expect(requests.count == 1)

        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(requestBodyData(request))
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(object?["stream"] as? String == "telemetry")
        #expect(object?["source"] as? String == "tally-app")

        let payloadEvent = object?["event"] as? [String: Any]
        #expect(payloadEvent?["name"] as? String == "network_failure")
        #expect(payloadEvent?["level"] as? String == "error")
        #expect(payloadEvent?["message"] as? String == "Request failed")

        let metadata = payloadEvent?["metadata"] as? [String: Any]
        #expect(metadata?["status_code"] as? Int == 500)
        #expect(metadata?["retry"] as? Bool == true)
        #expect((metadata?["tags"] as? [String])?.count == 2)

        let context = metadata?["context"] as? [String: Any]
        #expect(context?["flow"] as? String == "sync")
    }

    @Test
    func analyticsSinkSendsExpectedPayloadAndHeaders() async throws {
        MockURLProtocol.capture.reset()

        let session = makeSession()
        let transport = SentinelHTTPTransport(
            baseURL: URL(string: "https://ingest.example.com/v1/events")!,
            apiKey: "analytics-key",
            projectSlug: "ios-client",
            session: session
        )

        let event = AnalyticsEvent(
            name: "upgrade_tapped",
            kind: .conversion,
            properties: ["plan": "pro", "amount": 99],
            timestamp: Date(timeIntervalSince1970: 1_700_000_100)
        )

        transport.analyticsSink.track(event)

        let requests = await waitForRequestCount(1)
        #expect(requests.count == 1)

        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer analytics-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(requestBodyData(request))
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(object?["stream"] as? String == "analytics")
        #expect(object?["source"] as? String == "ios-client")

        let payloadEvent = object?["event"] as? [String: Any]
        #expect(payloadEvent?["name"] as? String == "upgrade_tapped")
        #expect(payloadEvent?["kind"] as? String == "conversion")

        let properties = payloadEvent?["properties"] as? [String: Any]
        #expect(properties?["plan"] as? String == "pro")
        #expect(properties?["amount"] as? Int == 99)
    }

    @Test
    func resolvedTransportUsesSameEndpointForTelemetryAndAnalytics() async throws {
        MockURLProtocol.capture.reset()

        let session = makeSession()
        let testTransport = SentinelHTTPTransport(
            baseURL: try SentinelHTTPTransport.resolveIngestEndpoint(
                .init(environment: ["SENTINEL_INGEST_URL": "https://resolved.example.com/ingestEvent"])
            ).url,
            apiKey: "test-key",
            projectSlug: "cross-sdk",
            session: session
        )

        testTransport.telemetrySink.record(
            TelemetryEvent(level: .info, name: "telemetry_a", timestamp: Date(timeIntervalSince1970: 1_700_000_500))
        )
        testTransport.analyticsSink.track(
            AnalyticsEvent(name: "analytics_b", kind: .action, timestamp: Date(timeIntervalSince1970: 1_700_000_501))
        )

        let requests = await waitForRequestCount(2)
        #expect(requests.count == 2)
        #expect(requests[0].url?.absoluteString == "https://resolved.example.com/ingestEvent")
        #expect(requests[1].url?.absoluteString == "https://resolved.example.com/ingestEvent")
    }
}
