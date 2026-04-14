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

const required = (value, field) => {
  if (!value) {
    throw new Error(`${field} is required`);
  }
  return value;
};

const toFirebaseFunctionsIngestUrl = ({ projectId, region = "us-central1", functionName = "ingestEvent" } = {}) => {
  required(projectId, "projectId");
  required(region, "region");
  required(functionName, "functionName");
  return `https://${region}-${projectId}.cloudfunctions.net/${functionName}`;
};

const firstNonEmpty = (...values) => values.find((value) => typeof value === "string" && value.trim().length > 0);
const defaultEnv = () =>
  typeof process !== "undefined" && process && process.env && isObject(process.env) ? process.env : undefined;

const endpointResolutionError = () =>
  new Error(
    [
      "Unable to resolve Sentinel ingest endpoint.",
      "Set one of: baseUrl/ingestUrl in config, or SENTINEL_INGEST_URL in env.",
      "For Firebase derived mode provide projectId (or SENTINEL_FIREBASE_PROJECT_ID / SENTINEL_PROJECT_ID), optional region, optional functionName.",
      "Cross-project deployments should prefer SENTINEL_INGEST_URL.",
    ].join(" "),
  );

const missingRequiredError = (missingFields) =>
  new Error(
    [
      `Missing required Sentinel configuration: ${missingFields.join(", ")}.`,
      "Required fields: SENTINEL_API_KEY and SENTINEL_PROJECT_SLUG.",
      "Endpoint resolution supports: baseUrl/ingestUrl, SENTINEL_INGEST_URL, or derived Firebase mode.",
      "Cross-project deployments should prefer SENTINEL_INGEST_URL.",
    ].join(" "),
  );

const resolveIngestEndpoint = ({
  baseUrl,
  ingestUrl,
  projectId,
  region,
  functionName,
  env = defaultEnv(),
} = {}) => {
  const explicitUrl = firstNonEmpty(baseUrl, ingestUrl);
  if (explicitUrl) {
    return { url: explicitUrl, mode: "explicit_url" };
  }

  const envUrl = firstNonEmpty(env?.SENTINEL_INGEST_URL);
  if (envUrl) {
    return { url: envUrl, mode: "env_url" };
  }

  const resolvedProjectId = firstNonEmpty(projectId, env?.SENTINEL_FIREBASE_PROJECT_ID, env?.SENTINEL_PROJECT_ID);
  if (resolvedProjectId) {
    const resolvedRegion = firstNonEmpty(region, env?.SENTINEL_FIREBASE_REGION) || "us-central1";
    const resolvedFunction = firstNonEmpty(functionName, env?.SENTINEL_FIREBASE_FUNCTION) || "ingestEvent";
    return {
      url: toFirebaseFunctionsIngestUrl({
        projectId: resolvedProjectId,
        region: resolvedRegion,
        functionName: resolvedFunction,
      }),
      mode: "derived_firebase",
    };
  }

  throw endpointResolutionError();
};

export class SentinelClient {
  constructor({ baseUrl, apiKey, projectSlug, userId, fetchImpl } = {}) {
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
    this.userId = userId || null;
    this.fetch = resolvedFetch;
  }

  setUserId(userId) {
    this.userId = userId || null;
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
    if (this.userId) {
      event.user_hash = this.userId;
    }

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

export const createSentinelClientFromEnv = ({
  env = defaultEnv(),
  baseUrl,
  ingestUrl,
  projectId,
  region,
  functionName,
  apiKey,
  projectSlug,
  userId,
  fetchImpl,
  onDebug,
} = {}) => {
  const key = firstNonEmpty(apiKey, env?.SENTINEL_API_KEY);
  const slug = firstNonEmpty(projectSlug, env?.SENTINEL_PROJECT_SLUG);
  const missing = [];
  if (!key) missing.push("SENTINEL_API_KEY");
  if (!slug) missing.push("SENTINEL_PROJECT_SLUG");
  if (missing.length > 0) throw missingRequiredError(missing);
  const resolution = resolveIngestEndpoint({ baseUrl, ingestUrl, projectId, region, functionName, env });
  onDebug?.(`Sentinel endpoint resolution mode: ${resolution.mode}`);
  return new SentinelClient({
    baseUrl: resolution.url,
    apiKey: key,
    projectSlug: slug,
    userId,
    fetchImpl,
  });
};

export class FirebaseFunctionsSentinelClient extends SentinelClient {
  constructor({
    baseUrl,
    ingestUrl,
    projectId,
    region = "us-central1",
    functionName = "ingestEvent",
    apiKey,
    projectSlug,
    userId,
    fetchImpl,
    env = defaultEnv(),
    onDebug,
  } = {}) {
    const resolution = resolveIngestEndpoint({
      baseUrl,
      ingestUrl,
      projectId,
      region,
      functionName,
      env,
    });
    onDebug?.(`Sentinel endpoint resolution mode: ${resolution.mode}`);
    super({ baseUrl: resolution.url, apiKey, projectSlug, userId, fetchImpl });
    this.projectId = projectId;
    this.region = region;
    this.functionName = functionName;
    this.endpointResolutionMode = resolution.mode;
  }

  static fromEnv({ env = defaultEnv(), fetchImpl, onDebug } = {}) {
    const apiKey = firstNonEmpty(env?.SENTINEL_API_KEY);
    const projectSlug = firstNonEmpty(env?.SENTINEL_PROJECT_SLUG);
    const missing = [];
    if (!apiKey) missing.push("SENTINEL_API_KEY");
    if (!projectSlug) missing.push("SENTINEL_PROJECT_SLUG");
    if (missing.length > 0) throw missingRequiredError(missing);
    const region = firstNonEmpty(env?.SENTINEL_FIREBASE_REGION) || "us-central1";
    const functionName = firstNonEmpty(env?.SENTINEL_FIREBASE_FUNCTION) || "ingestEvent";
    const projectId = firstNonEmpty(env?.SENTINEL_FIREBASE_PROJECT_ID, env?.SENTINEL_PROJECT_ID);

    return new FirebaseFunctionsSentinelClient({
      baseUrl: env?.SENTINEL_INGEST_URL,
      projectId,
      region,
      functionName,
      apiKey,
      projectSlug,
      fetchImpl,
      env,
      onDebug,
    });
  }
}

export const createFirebaseFunctionsSentinelClient = (config) =>
  new FirebaseFunctionsSentinelClient(config);

export { toFirebaseFunctionsIngestUrl, resolveIngestEndpoint };
