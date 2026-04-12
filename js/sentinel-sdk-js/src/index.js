const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

const toIso = (value) => {
  if (!value) return new Date().toISOString();
  if (value instanceof Date) return value.toISOString();
  return new Date(value).toISOString();
};

const defaultEnvironmentMetadata = () => {
  const metadata = {};

  if (typeof process !== "undefined") {
    if (process.release?.name) metadata.runtime = String(process.release.name);
    if (process.version) metadata.runtime_version = String(process.version);
    if (process.platform) metadata.platform = String(process.platform);
  }

  if (typeof navigator !== "undefined" && navigator.userAgent) {
    metadata.user_agent = navigator.userAgent;
  }

  if (typeof window !== "undefined") {
    metadata.has_window = true;
  }

  return metadata;
};

export class SentinelClient {
  constructor({ baseUrl, apiKey, projectSlug, fetchImpl } = {}) {
    if (!baseUrl) throw new Error("baseUrl is required");
    if (!apiKey) throw new Error("apiKey is required");
    if (!projectSlug) throw new Error("projectSlug is required");

    const resolvedFetch = fetchImpl ?? globalThis.fetch;
    if (typeof resolvedFetch !== "function") {
      throw new Error("fetch implementation is required");
    }

    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.projectSlug = projectSlug;
    this.fetch = resolvedFetch;
  }

  async log({ level, name, message = null, metadata = {}, timestamp } = {}) {
    if (!level) throw new Error("level is required");
    if (!name) throw new Error("name is required");

    const event = {
      name,
      level,
      message,
      metadata: {
        ...defaultEnvironmentMetadata(),
        ...(isObject(metadata) ? metadata : {}),
      },
      timestamp: toIso(timestamp),
    };

    return this.#send("telemetry", event);
  }

  async recordError(error, { name = "error", metadata = {}, timestamp } = {}) {
    const eventMetadata = {
      ...(isObject(metadata) ? metadata : {}),
      error_type: error?.name ?? "Error",
      error_description: error?.message ?? String(error),
    };

    return this.log({
      level: "error",
      name,
      message: error?.message ?? String(error),
      metadata: eventMetadata,
      timestamp,
    });
  }

  async track({ name, kind = "action", properties = {}, timestamp } = {}) {
    if (!name) throw new Error("name is required");

    const event = {
      name,
      kind,
      properties: isObject(properties) ? properties : {},
      timestamp: toIso(timestamp),
    };

    return this.#send("analytics", event);
  }

  async screen(name, properties = {}) {
    return this.track({ name, kind: "screen", properties });
  }

  async #send(stream, event) {
    const payload = {
      stream,
      source: this.projectSlug,
      event,
    };

    const response = await this.fetch(this.baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    return response;
  }
}

export const createSentinelClient = (config) => new SentinelClient(config);
