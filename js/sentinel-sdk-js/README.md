# Sentinel SDK — JavaScript

JavaScript SDK for React, React Native, web, and Node.js apps. Provides telemetry logging and analytics tracking with the same event contract used by the iOS and Android SDKs.

## Requirements

- Node.js 18+ (or any environment with global `fetch`)

## Install

```bash
npm install @the-ginger-geek/sentinel-sdk
```

## Quick Start

```javascript
import { SentinelClient } from "@the-ginger-geek/sentinel-sdk";

const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "<project-slug>",
});
```

## Telemetry

Log events at five severity levels:

```javascript
await sentinel.log({ level: "info", name: "app_started", metadata: { platform: "react" } });
await sentinel.log({ level: "warning", name: "low_storage", message: "Less than 100MB" });
await sentinel.log({ level: "debug", name: "cache_hit", metadata: { key: "user_profile" } });
```

Available levels: `"debug"`, `"info"`, `"warning"`, `"error"`, `"critical"`

### Error Recording

Capture errors with automatic type and description extraction:

```javascript
try {
  await riskyOperation();
} catch (error) {
  await sentinel.recordError(error, { name: "sync_failed", metadata: { retry: 3 } });
}
```

This logs at `"error"` level and adds `error_type` and `error_description` to metadata.

## Analytics

Track user interactions and screen views:

```javascript
// Screen views
await sentinel.screen("home", { entry_point: "cold_start" });

// Actions, conversions, state changes
await sentinel.track({ name: "upgrade_tapped", kind: "conversion", properties: { plan: "pro" } });
await sentinel.track({ name: "filter_applied", kind: "action", properties: { filter: "date" } });
await sentinel.track({ name: "dark_mode_enabled", kind: "state" });
```

Available kinds: `"screen"`, `"action"`, `"conversion"`, `"state"`

## React Integration

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

## Custom Fetch

Pass a custom `fetch` implementation for testing or environments without a global `fetch`:

```javascript
const sentinel = new SentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "my-app",
  fetchImpl: customFetchFunction,
});
```

## Environment Detection

The SDK automatically collects environment metadata on each telemetry event:

- `runtime` / `runtime_version` — Node.js runtime info (when available)
- `platform` — OS platform (when available)
- `user_agent` — browser user agent (when available)
- `has_window` — whether a browser `window` object exists

## Factory Function

An alternative constructor is available:

```javascript
import { createSentinelClient } from "@the-ginger-geek/sentinel-sdk";

const sentinel = createSentinelClient({
  baseUrl: "https://<your-ingest-endpoint>",
  apiKey: "<api-key>",
  projectSlug: "my-app",
});
```

## API

| Method | Stream | Description |
|--------|--------|-------------|
| `log({ level, name, message?, metadata?, timestamp? })` | telemetry | Log a telemetry event |
| `recordError(error, { name?, metadata?, timestamp? })` | telemetry | Log an error with automatic type extraction |
| `track({ name, kind?, properties?, timestamp? })` | analytics | Track an analytics event (defaults to `"action"`) |
| `screen(name, properties?)` | analytics | Track a screen view |

All methods are async and return the raw `fetch` Response.

## Test

```bash
npm test
```
