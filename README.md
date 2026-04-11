# SentinelSDK

`SentinelSDK` is the public Swift package for app-side Sentinel integrations.

It provides:
- `SentinelCore` for telemetry logging
- `AppAnalytics` for analytics events
- `SentinelHTTPTransport` for HTTP delivery to Sentinel ingest

## Requirements

- Swift 5.9+
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+

## Installation

Add dependency in `Package.swift`:

```swift
.package(url: "https://github.com/the-ginger-geek/sentinel-sdk.git", from: "1.0.0")
```

Add products to your target:

```swift
.product(name: "SentinelCore", package: "sentinel-sdk"),
.product(name: "AppAnalytics", package: "sentinel-sdk"),
.product(name: "SentinelHTTPTransport", package: "sentinel-sdk"),
```

## Quick Start

```swift
import AppAnalytics
import Foundation
import SentinelCore
import SentinelHTTPTransport

let transport = SentinelHTTPTransport(
    baseURL: URL(string: "https://<your-ingest-endpoint>")!,
    apiKey: "<api-key>",
    projectSlug: "<project-slug>"
)

Sentinel.shared.register(sink: transport.telemetrySink)
AppAnalytics.shared.register(sink: transport.analyticsSink)

Sentinel.shared.log(level: .info, name: "app_started", metadata: ["platform": "ios"])
AppAnalytics.shared.screen("home", properties: ["entry_point": "cold_start"])
```

## Event Envelope

The HTTP transport sends this top-level payload shape:

```json
{
  "stream": "telemetry | analytics",
  "source": "<project-slug>",
  "event": { "...": "stream-specific event payload" }
}
```

Auth header:

```text
Authorization: Bearer <api-key>
```

## Development

```bash
swift build
swift test
```

## Notes

- `SentinelHTTPTransport` does not mutate backend contracts; it forwards the same event shape currently used by app integrations.
- Adapters for vendor SDKs (Firebase, Sentry, Crashlytics) remain in the private `sentinel` repository.
