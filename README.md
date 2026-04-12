# SentinelSDK

`SentinelSDK` is the public client SDK suite for app-side Sentinel integrations. It provides telemetry logging and analytics tracking across multiple platforms with a unified event contract.

## SDKs

| Platform | Location | Language |
|----------|----------|----------|
| Apple (iOS, macOS, tvOS, watchOS) | `Sources/` | Swift |
| Android | `android/sentinel-sdk-android-java/` | Java |
| React / Web / Node.js | `js/sentinel-sdk-js/` | JavaScript |

## Event Envelope

All SDKs send the same top-level payload shape:

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

### Telemetry Event

```json
{
  "name": "event_name",
  "level": "debug | info | warning | error | critical",
  "message": "optional message",
  "metadata": { "key": "value" },
  "timestamp": "2026-01-15T12:00:00Z"
}
```

### Analytics Event

```json
{
  "name": "event_name",
  "kind": "screen | action | conversion | state",
  "properties": { "key": "value" },
  "timestamp": "2026-01-15T12:00:00Z"
}
```

---

## iOS / macOS (Swift)

### Requirements

- Swift 5.9+
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+

### Installation

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

### Quick Start

```swift
import SentinelCore
import AppAnalytics
import SentinelHTTPTransport
import Foundation

let transport = SentinelHTTPTransport(
    baseURL: URL(string: "https://<your-ingest-endpoint>")!,
    apiKey: "<api-key>",
    projectSlug: "<project-slug>",
    userId: "<user-id-or-hash>"
)

Sentinel.shared.register(sink: transport.telemetrySink)
AppAnalytics.shared.register(sink: transport.analyticsSink)
```

### Telemetry

```swift
// Log events at various levels
Sentinel.shared.log(level: .info, name: "app_started", metadata: ["platform": "ios"])
Sentinel.shared.log(level: .warning, name: "low_storage", message: "Less than 100MB remaining")

// Record errors
do {
    try riskyOperation()
} catch {
    Sentinel.shared.record(error: error, name: "sync_failed", metadata: ["retry": 3])
}
```

Available levels: `.debug`, `.info`, `.warning`, `.error`, `.critical`

### Analytics

```swift
// Track screens
AppAnalytics.shared.screen("home", properties: ["entry_point": "cold_start"])

// Track actions, conversions, and state changes
AppAnalytics.shared.track("upgrade_tapped", kind: .conversion, properties: ["plan": "pro"])
AppAnalytics.shared.track("filter_applied", kind: .action, properties: ["filter": "date"])
```

Available kinds: `.screen`, `.action`, `.conversion`, `.state`

### Architecture

The Swift SDK uses a sink-based pattern:

- **`SentinelCore`** — core telemetry dispatcher with `TelemetrySink` protocol and environment probes
- **`AppAnalytics`** — analytics dispatcher with `AnalyticsSink` protocol
- **`SentinelHTTPTransport`** — provides HTTP-backed sinks for both telemetry and analytics (actor-based, async)

Register custom sinks to route events to additional destinations (e.g. console, file, third-party services).

### User Identification

Pass a `userId` when creating the transport to track affected users per issue group on the dashboard:

```swift
let transport = SentinelHTTPTransport(
    baseURL: URL(string: "https://<your-ingest-endpoint>")!,
    apiKey: "<api-key>",
    projectSlug: "ios-app",
    userId: currentUser.id  // or a hashed identifier
)
```

The `userId` is sent as `user_hash` on every event. Use a stable identifier (e.g. Firebase UID, account ID, or a SHA-256 hash of the user's email).

---

## Android (Java)

### Requirements

- Java 11+
- Android SDK (any recent version)

### Installation

Add the `sentinel-sdk-android-java` module to your project, or copy `SentinelClient.java` and `JsonEncoder.java` into your source tree.

### Quick Start

```java
import com.thegingergeek.sentinel.SentinelClient;
import java.util.Map;

SentinelClient client = new SentinelClient(
    "https://<your-ingest-endpoint>",
    "<api-key>",
    "<project-slug>"
);

// Set user ID for affected-user tracking
client.setUserId("<user-id-or-hash>");
```

### Telemetry

```java
// Log events at various levels
client.log(SentinelClient.TelemetryLevel.INFO, "app_started", null, Map.of("platform", "android"));
client.log(SentinelClient.TelemetryLevel.WARNING, "low_storage", "Less than 100MB", null);

// Record errors
try {
    riskyOperation();
} catch (Exception e) {
    client.recordError(e, "sync_failed", Map.of("retry", 3));
}
```

Available levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

### Analytics

```java
// Track screens
client.screen("home", Map.of("entry_point", "cold_start"));

// Track actions, conversions, and state changes
client.track("upgrade_tapped", SentinelClient.AnalyticsKind.CONVERSION, Map.of("plan", "pro"));
client.track("filter_applied", SentinelClient.AnalyticsKind.ACTION, Map.of("filter", "date"));
```

Available kinds: `SCREEN`, `ACTION`, `CONVERSION`, `STATE`

### User Identification

Set a user ID to track affected users per issue group on the dashboard:

```java
// At construction
SentinelClient client = new SentinelClient(
    "https://<your-ingest-endpoint>",
    "<api-key>",
    "android-app",
    "user-123",              // userId
    new DefaultHttpTransport()
);

// Or update later (e.g. after login)
client.setUserId("user-123");
```

The `userId` is sent as `user_hash` on every event. Use a stable identifier (e.g. Firebase UID, account ID).

### Custom Transport

Inject a custom `HttpTransport` for testing or custom networking:

```java
SentinelClient client = new SentinelClient(
    "https://<your-ingest-endpoint>",
    "<api-key>",
    "<project-slug>",
    (url, apiKey, jsonBody) -> {
        // Custom HTTP implementation
        return 200;
    }
);
```

---

## React / Web / Node.js (JavaScript)

### Requirements

- Node.js 18+ (or any environment with `fetch`)

### Installation

```bash
npm install @the-ginger-geek/sentinel-sdk
```

### Quick Start

```javascript
import { SentinelClient } from "@the-ginger-geek/sentinel-sdk";

const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "<project-slug>",
  userId: "<user-id-or-hash>",
});
```

### Telemetry

```javascript
// Log events at various levels
await sentinel.log({ level: "info", name: "app_started", metadata: { platform: "react" } });
await sentinel.log({ level: "warning", name: "low_storage", message: "Less than 100MB" });

// Record errors
try {
  await riskyOperation();
} catch (error) {
  await sentinel.recordError(error, { name: "sync_failed", metadata: { retry: 3 } });
}
```

Available levels: `"debug"`, `"info"`, `"warning"`, `"error"`, `"critical"`

### Analytics

```javascript
// Track screens
await sentinel.screen("home", { entry_point: "cold_start" });

// Track actions, conversions, and state changes
await sentinel.track({ name: "upgrade_tapped", kind: "conversion", properties: { plan: "pro" } });
await sentinel.track({ name: "filter_applied", kind: "action", properties: { filter: "date" } });
```

Available kinds: `"screen"`, `"action"`, `"conversion"`, `"state"`

### React Integration

```jsx
import { useEffect } from "react";
import { SentinelClient } from "@the-ginger-geek/sentinel-sdk";

const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "my-react-app",
});

function App() {
  useEffect(() => {
    sentinel.screen("app_loaded", { entry_point: "direct" });
  }, []);

  const handleUpgrade = async () => {
    await sentinel.track({ name: "upgrade_tapped", kind: "conversion", properties: { plan: "pro" } });
  };

  return <button onClick={handleUpgrade}>Upgrade</button>;
}
```

### Custom Fetch

Pass a custom `fetch` implementation for testing or environments without a global `fetch`:

```javascript
const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "my-app",
  fetchImpl: customFetchFunction,
});
```

### User Identification

Pass a `userId` at construction or update it later (e.g. after login):

```javascript
const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "my-react-app",
  userId: currentUser.id,
});

// Or update later
sentinel.setUserId("user-456");
```

The `userId` is sent as `user_hash` on every event. Use a stable identifier (e.g. Firebase UID, account ID, or a hashed email).

### Environment Detection

The JS SDK automatically collects environment metadata on each telemetry event:
- `runtime` / `runtime_version` — Node.js runtime info (when available)
- `platform` — OS platform (when available)
- `user_agent` — browser user agent (when available)
- `has_window` — whether a browser `window` object exists

---

## API Reference

All SDKs expose the same four methods:

| Method | Stream | Description |
|--------|--------|-------------|
| `log` | telemetry | Log a telemetry event with level, name, optional message and metadata |
| `recordError` | telemetry | Convenience for logging errors — captures error type and description |
| `track` | analytics | Track an analytics event with name, kind, and optional properties |
| `screen` | analytics | Convenience for `track` with `kind: screen` |

## Development

Run all SDK tests:

```bash
./scripts/test-all.sh
```

Or run each SDK independently:

```bash
# Swift
swift test

# JavaScript
cd js/sentinel-sdk-js && node --test

# Android
cd android/sentinel-sdk-android-java && ./run-tests.sh
```

## Notes

- `SentinelHTTPTransport` does not mutate backend contracts; it forwards the same event shape currently used by app integrations.
- Adapters for vendor SDKs (Firebase, Sentry, Crashlytics) remain in the private `sentinel` repository.
- All SDKs maintain protocol compatibility: same event envelope, same field names, same ISO 8601 timestamp format.
