import AppAnalytics
import Foundation
import SentinelCore
import SentinelHTTPTransport

let transport = SentinelHTTPTransport(
    baseURL: URL(string: "https://ingest.example.com/v1/events")!,
    apiKey: "example-api-key",
    projectSlug: "smoke-client"
)

Sentinel.shared.register(sink: transport.telemetrySink)
AppAnalytics.shared.register(sink: transport.analyticsSink)

Sentinel.shared.log(level: .info, name: "smoke_start", metadata: ["platform": "macOS"])
AppAnalytics.shared.track("smoke_track", kind: .action, properties: ["source": "example"])

print("SentinelSDK smoke integration wired")
