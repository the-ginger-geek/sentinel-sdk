import test from "node:test";
import assert from "node:assert/strict";
import {
  SentinelClient,
  createSentinelClient,
  createSentinelClientFromEnv,
  createFirebaseFunctionsSentinelClient,
  FirebaseFunctionsSentinelClient,
  resolveIngestEndpoint,
  toFirebaseFunctionsIngestUrl,
} from "../src/index.js";

test("log sends telemetry payload with auth header", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return { ok: true, status: 200 };
  };

  const client = new SentinelClient({
    baseUrl: "https://example.com/ingestEvent",
    apiKey: "test-key",
    projectSlug: "web-app",
    fetchImpl,
  });

  await client.log({
    level: "info",
    name: "app_started",
    metadata: { channel: "react" },
    timestamp: "2026-04-11T08:00:00.000Z",
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://example.com/ingestEvent");
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].init.headers.Authorization, "Bearer test-key");

  const payload = JSON.parse(calls[0].init.body);
  assert.equal(payload.stream, "telemetry");
  assert.equal(payload.source, "web-app");
  assert.equal(payload.event.name, "app_started");
  assert.equal(payload.event.level, "info");
  assert.equal(payload.event.metadata.channel, "react");
});

test("track sends analytics payload", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return { ok: true, status: 200 };
  };

  const client = new SentinelClient({
    baseUrl: "https://example.com/ingestEvent",
    apiKey: "test-key",
    projectSlug: "web-app",
    fetchImpl,
  });

  await client.track({
    name: "upgrade_tapped",
    kind: "conversion",
    properties: { plan: "pro" },
    timestamp: "2026-04-11T08:01:00.000Z",
  });

  assert.equal(calls.length, 1);
  const payload = JSON.parse(calls[0].init.body);
  assert.equal(payload.stream, "analytics");
  assert.equal(payload.source, "web-app");
  assert.equal(payload.event.kind, "conversion");
  assert.equal(payload.event.properties.plan, "pro");
});

test("screen is tracked as analytics screen kind", async () => {
  const calls = [];
  const fetchImpl = async (_url, init) => {
    calls.push(init);
    return { ok: true, status: 200 };
  };

  const client = createSentinelClient({
    baseUrl: "https://example.com/ingestEvent",
    apiKey: "test-key",
    projectSlug: "web-app",
    fetchImpl,
  });

  await client.screen("dashboard", { tab: "home" });

  const payload = JSON.parse(calls[0].body);
  assert.equal(payload.stream, "analytics");
  assert.equal(payload.event.kind, "screen");
  assert.equal(payload.event.name, "dashboard");
  assert.equal(payload.event.properties.tab, "home");
});

test("recordError enriches telemetry metadata", async () => {
  const calls = [];
  const fetchImpl = async (_url, init) => {
    calls.push(init);
    return { ok: true, status: 200 };
  };

  const client = new SentinelClient({
    baseUrl: "https://example.com/ingestEvent",
    apiKey: "test-key",
    projectSlug: "web-app",
    fetchImpl,
  });

  await client.recordError(new Error("boom"), {
    name: "api_failure",
    metadata: { flow: "checkout" },
    timestamp: "2026-04-11T08:02:00.000Z",
  });

  const payload = JSON.parse(calls[0].body);
  assert.equal(payload.stream, "telemetry");
  assert.equal(payload.event.level, "error");
  assert.equal(payload.event.name, "api_failure");
  assert.equal(payload.event.metadata.flow, "checkout");
  assert.equal(payload.event.metadata.error_description, "boom");
  assert.ok(payload.event.metadata.error_type.includes("Error"));
});

test("constructor validates required config", () => {
  assert.throws(() => new SentinelClient({ apiKey: "k", projectSlug: "p", fetchImpl: async () => ({}) }), /baseUrl/);
  assert.throws(() => new SentinelClient({ baseUrl: "u", projectSlug: "p", fetchImpl: async () => ({}) }), /apiKey/);
  assert.throws(() => new SentinelClient({ baseUrl: "u", apiKey: "k", fetchImpl: async () => ({}) }), /projectSlug/);
});

test("firebase helper builds expected Cloud Functions URL", () => {
  assert.equal(
    toFirebaseFunctionsIngestUrl({ projectId: "sentinel-8997b" }),
    "https://us-central1-sentinel-8997b.cloudfunctions.net/ingestEvent",
  );
  assert.equal(
    toFirebaseFunctionsIngestUrl({
      projectId: "sentinel-8997b",
      region: "europe-west1",
      functionName: "customIngest",
    }),
    "https://europe-west1-sentinel-8997b.cloudfunctions.net/customIngest",
  );
});

test("resolve endpoint uses explicit URL before env and derived", () => {
  const resolution = resolveIngestEndpoint({
    baseUrl: "https://explicit.example.com/ingestEvent",
    projectId: "sentinel-8997b",
    env: { SENTINEL_INGEST_URL: "https://env.example.com/ingestEvent" },
  });

  assert.equal(resolution.mode, "explicit_url");
  assert.equal(resolution.url, "https://explicit.example.com/ingestEvent");
});

test("resolve endpoint uses SENTINEL_INGEST_URL before derived mode", () => {
  const resolution = resolveIngestEndpoint({
    projectId: "sentinel-8997b",
    env: { SENTINEL_INGEST_URL: "https://env.example.com/ingestEvent" },
  });

  assert.equal(resolution.mode, "env_url");
  assert.equal(resolution.url, "https://env.example.com/ingestEvent");
});

test("resolve endpoint supports derived alias SENTINEL_PROJECT_ID", () => {
  const resolution = resolveIngestEndpoint({
    env: {
      SENTINEL_PROJECT_ID: "sentinel-8997b",
      SENTINEL_FIREBASE_REGION: "europe-west1",
      SENTINEL_FIREBASE_FUNCTION: "ingestEvent",
    },
  });

  assert.equal(resolution.mode, "derived_firebase");
  assert.equal(
    resolution.url,
    "https://europe-west1-sentinel-8997b.cloudfunctions.net/ingestEvent",
  );
});

test("resolve endpoint throws actionable error when unresolved", () => {
  assert.throws(
    () => resolveIngestEndpoint({ env: {} }),
    /baseUrl\/ingestUrl|SENTINEL_INGEST_URL|SENTINEL_FIREBASE_PROJECT_ID|cross-project/i,
  );
});

test("firebase client sends to firebase functions endpoint", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return { ok: true, status: 200 };
  };

  const client = createFirebaseFunctionsSentinelClient({
    projectId: "sentinel-8997b",
    apiKey: "firebase-key",
    projectSlug: "web-app",
    fetchImpl,
  });

  await client.track({
    name: "firebase_event",
    kind: "action",
    properties: { via: "helper" },
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://us-central1-sentinel-8997b.cloudfunctions.net/ingestEvent");
  assert.equal(calls[0].init.headers.Authorization, "Bearer firebase-key");
});

test("firebase client supports env bootstrap", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return { ok: true, status: 200 };
  };

  const client = FirebaseFunctionsSentinelClient.fromEnv({
    env: {
      SENTINEL_INGEST_URL: "https://custom-ingest.example.com/ingestEvent",
      SENTINEL_API_KEY: "env-key",
      SENTINEL_PROJECT_SLUG: "server-app",
    },
    fetchImpl,
  });

  await client.log({ level: "info", name: "env_bootstrap" });

  assert.equal(calls[0].url, "https://custom-ingest.example.com/ingestEvent");
  assert.equal(calls[0].init.headers.Authorization, "Bearer env-key");
  const payload = JSON.parse(calls[0].init.body);
  assert.equal(payload.source, "server-app");
});

test("generic fromEnv helper resolves and sends using shared precedence", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return { ok: true, status: 200 };
  };

  const client = createSentinelClientFromEnv({
    env: {
      SENTINEL_INGEST_URL: "https://env-priority.example.com/ingestEvent",
      SENTINEL_API_KEY: "env-key",
      SENTINEL_PROJECT_SLUG: "generic-app",
      SENTINEL_FIREBASE_PROJECT_ID: "ignored-project",
    },
    fetchImpl,
  });

  await client.track({ name: "generic_event" });
  assert.equal(calls[0].url, "https://env-priority.example.com/ingestEvent");
});

test("generic fromEnv helper reports actionable missing required fields", () => {
  assert.throws(
    () => createSentinelClientFromEnv({ env: { SENTINEL_INGEST_URL: "https://env.example.com/ingestEvent" } }),
    /SENTINEL_API_KEY|SENTINEL_PROJECT_SLUG|Cross-project/i,
  );
});
