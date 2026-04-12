import test from "node:test";
import assert from "node:assert/strict";
import { SentinelClient, createSentinelClient } from "../src/index.js";

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
