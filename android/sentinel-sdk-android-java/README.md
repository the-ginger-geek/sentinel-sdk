# Sentinel SDK — Android (Java)

Android-compatible Java client for Sentinel ingest. Provides telemetry logging and analytics tracking with the same event contract used by the iOS and JavaScript SDKs.

## Requirements

- Java 11+
- Android SDK (any recent version)

## Installation

Add the `sentinel-sdk-android-java` module to your project, or copy `SentinelClient.java` and `JsonEncoder.java` into your source tree under `com.thegingergeek.sentinel`.

## Quick Start

```java
import com.thegingergeek.sentinel.SentinelClient;
import java.util.Map;

SentinelClient client = new SentinelClient(
    "https://<your-ingest-endpoint>",
    "<api-key>",
    "<project-slug>"
);
```

## Endpoint Resolution

The Android SDK follows the same cross-SDK precedence:

1. Explicit `baseUrl` / `ingestUrl` in `EndpointConfig`
2. `SENTINEL_INGEST_URL`
3. Derived Firebase URL using `projectId` (or `SENTINEL_FIREBASE_PROJECT_ID` / `SENTINEL_PROJECT_ID`) + optional region/function

Derived format:

```text
https://{region}-{projectId}.cloudfunctions.net/{functionName}
```

Defaults:

- `region`: `us-central1`
- `functionName`: `ingestEvent`

Recommended for cross-project deployments:

```bash
SENTINEL_INGEST_URL=https://us-central1-<sentinel-ingest-project>.cloudfunctions.net/ingestEvent
SENTINEL_API_KEY=<api-key>
SENTINEL_PROJECT_SLUG=<project-slug>
```

Java setup:

```java
SentinelClient.EndpointConfig endpoint = new SentinelClient.EndpointConfig();
endpoint.environment = System.getenv();

SentinelClient client = new SentinelClient(
    endpoint,
    System.getenv("SENTINEL_API_KEY"),
    System.getenv("SENTINEL_PROJECT_SLUG")
);
```

## Telemetry

Log events at five severity levels:

```java
client.log(SentinelClient.TelemetryLevel.INFO, "app_started", null, Map.of("platform", "android"));
client.log(SentinelClient.TelemetryLevel.WARNING, "low_storage", "Less than 100MB", null);
client.log(SentinelClient.TelemetryLevel.DEBUG, "cache_hit", null, Map.of("key", "user_profile"));
```

Available levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

### Error Recording

Capture exceptions with automatic type and description extraction:

```java
try {
    riskyOperation();
} catch (Exception e) {
    client.recordError(e, "sync_failed", Map.of("retry", 3));
}
```

This logs at `ERROR` level and adds `error_type` and `error_description` to metadata.

## Analytics

Track user interactions and screen views:

```java
// Screen views
client.screen("home", Map.of("entry_point", "cold_start"));

// Actions, conversions, state changes
client.track("upgrade_tapped", SentinelClient.AnalyticsKind.CONVERSION, Map.of("plan", "pro"));
client.track("filter_applied", SentinelClient.AnalyticsKind.ACTION, Map.of("filter", "date"));
client.track("dark_mode_enabled", SentinelClient.AnalyticsKind.STATE, null);
```

Available kinds: `SCREEN`, `ACTION`, `CONVERSION`, `STATE`

## User Identification

Set a user ID to track affected users per issue group on the Sentinel dashboard:

```java
// Set after login
client.setUserId("user-123");

// Or clear on logout
client.setUserId(null);
```

The `userId` is sent as `user_hash` on every event. Use a stable identifier (e.g. Firebase UID, account ID). Thread-safe — can be updated at any time.

## Custom Transport

The default transport uses `HttpURLConnection`. Inject a custom `HttpTransport` for testing or to use a different HTTP client (e.g. OkHttp):

```java
SentinelClient client = new SentinelClient(
    "https://<your-ingest-endpoint>",
    "<api-key>",
    "<project-slug>",
    (url, apiKey, jsonBody) -> {
        // Your custom HTTP POST implementation
        return 200;
    }
);
```

## API

| Method | Stream | Signature |
|--------|--------|-----------|
| `log` | telemetry | `log(TelemetryLevel level, String name, String message, Map<String, Object> metadata)` |
| `recordError` | telemetry | `recordError(Throwable error, String name, Map<String, Object> metadata)` |
| `track` | analytics | `track(String name, AnalyticsKind kind, Map<String, Object> properties)` |
| `screen` | analytics | `screen(String name, Map<String, Object> properties)` |

All methods return the HTTP status code (`int`) and throw `IOException` on transport failure.

## Test

```bash
./run-tests.sh
```
