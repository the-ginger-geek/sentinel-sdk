package com.thegingergeek.sentinel;

import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;
import java.util.function.Consumer;

public final class SentinelClient {
    public enum TelemetryLevel {
        DEBUG("debug"), INFO("info"), WARNING("warning"), ERROR("error"), CRITICAL("critical");

        private final String value;

        TelemetryLevel(String value) {
            this.value = value;
        }

        public String value() {
            return value;
        }
    }

    public enum AnalyticsKind {
        SCREEN("screen"), ACTION("action"), CONVERSION("conversion"), STATE("state");

        private final String value;

        AnalyticsKind(String value) {
            this.value = value;
        }

        public String value() {
            return value;
        }
    }

    public enum EndpointResolutionMode {
        EXPLICIT_URL("explicit_url"),
        ENV_URL("env_url"),
        DERIVED_FIREBASE("derived_firebase");

        private final String value;

        EndpointResolutionMode(String value) {
            this.value = value;
        }

        public String value() {
            return value;
        }
    }

    public interface HttpTransport {
        int post(String url, String apiKey, String jsonBody) throws IOException;
    }

    public static final class EndpointConfig {
        public String baseUrl;
        public String ingestUrl;
        public String projectId;
        public String region;
        public String functionName;
        public Map<String, String> environment;

        public EndpointConfig() {}
    }

    public static final class EndpointResolution {
        public final String url;
        public final EndpointResolutionMode mode;

        public EndpointResolution(String url, EndpointResolutionMode mode) {
            this.url = url;
            this.mode = mode;
        }
    }

    private final String baseUrl;
    private final String apiKey;
    private final String projectSlug;
    private final HttpTransport transport;
    private volatile String userId;

    public SentinelClient(String baseUrl, String apiKey, String projectSlug) {
        this(baseUrl, apiKey, projectSlug, null, new DefaultHttpTransport());
    }

    public SentinelClient(String baseUrl, String apiKey, String projectSlug, HttpTransport transport) {
        this(baseUrl, apiKey, projectSlug, null, transport);
    }

    public SentinelClient(String baseUrl, String apiKey, String projectSlug, String userId, HttpTransport transport) {
        if (isBlank(baseUrl)) throw new IllegalArgumentException("baseUrl is required");
        if (isBlank(apiKey)) throw new IllegalArgumentException("apiKey is required");
        if (isBlank(projectSlug)) throw new IllegalArgumentException("projectSlug is required");
        if (transport == null) throw new IllegalArgumentException("transport is required");

        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
        this.projectSlug = projectSlug;
        this.userId = userId;
        this.transport = transport;
    }

    // New constructor: shared endpoint resolution contract with backward compatibility.
    public SentinelClient(EndpointConfig endpointConfig, String apiKey, String projectSlug) {
        this(endpointConfig, apiKey, projectSlug, null, new DefaultHttpTransport(), null);
    }

    public SentinelClient(EndpointConfig endpointConfig, String apiKey, String projectSlug, HttpTransport transport) {
        this(endpointConfig, apiKey, projectSlug, null, transport, null);
    }

    public SentinelClient(
        EndpointConfig endpointConfig,
        String apiKey,
        String projectSlug,
        String userId,
        HttpTransport transport,
        Consumer<String> diagnostics
    ) {
        if (isBlank(apiKey)) throw new IllegalArgumentException("apiKey is required");
        if (isBlank(projectSlug)) throw new IllegalArgumentException("projectSlug is required");

        EndpointResolution resolution = resolveEndpoint(endpointConfig);
        if (diagnostics != null) {
            diagnostics.accept("Sentinel endpoint resolution mode: " + resolution.mode.value());
        }

        this.baseUrl = resolution.url;
        this.apiKey = apiKey;
        this.projectSlug = projectSlug;
        this.userId = userId;
        this.transport = transport == null ? new DefaultHttpTransport() : transport;
    }

    public static SentinelClient fromEnv() {
        return fromEnv(System.getenv(), null, null);
    }

    public static SentinelClient fromEnv(Map<String, String> env) {
        return fromEnv(env, null, null);
    }

    public static SentinelClient fromEnv(Map<String, String> env, HttpTransport transport, Consumer<String> diagnostics) {
        Map<String, String> sourceEnv = env == null ? System.getenv() : env;
        String apiKey = firstNonEmpty(sourceEnv.get("SENTINEL_API_KEY"));
        String projectSlug = firstNonEmpty(sourceEnv.get("SENTINEL_PROJECT_SLUG"));

        if (isBlank(apiKey) || isBlank(projectSlug)) {
            StringBuilder missing = new StringBuilder();
            if (isBlank(apiKey)) {
                missing.append("SENTINEL_API_KEY");
            }
            if (isBlank(projectSlug)) {
                if (missing.length() > 0) missing.append(", ");
                missing.append("SENTINEL_PROJECT_SLUG");
            }
            throw new IllegalArgumentException(
                "Missing required Sentinel configuration: " + missing + ". " +
                "Required fields: SENTINEL_API_KEY and SENTINEL_PROJECT_SLUG. " +
                "Endpoint resolution supports: baseUrl/ingestUrl, SENTINEL_INGEST_URL, or derived Firebase mode. " +
                "Cross-project deployments should prefer SENTINEL_INGEST_URL."
            );
        }

        EndpointConfig endpointConfig = new EndpointConfig();
        endpointConfig.environment = sourceEnv;
        return new SentinelClient(endpointConfig, apiKey, projectSlug, null, transport, diagnostics);
    }

    public static EndpointResolution resolveEndpoint(EndpointConfig endpointConfig) {
        EndpointConfig config = endpointConfig == null ? new EndpointConfig() : endpointConfig;
        Map<String, String> env = config.environment == null ? System.getenv() : config.environment;

        String explicitUrl = firstNonEmpty(config.baseUrl, config.ingestUrl);
        if (explicitUrl != null) {
            return new EndpointResolution(explicitUrl, EndpointResolutionMode.EXPLICIT_URL);
        }

        String envUrl = firstNonEmpty(env.get("SENTINEL_INGEST_URL"));
        if (envUrl != null) {
            return new EndpointResolution(envUrl, EndpointResolutionMode.ENV_URL);
        }

        String projectId = firstNonEmpty(config.projectId, env.get("SENTINEL_FIREBASE_PROJECT_ID"), env.get("SENTINEL_PROJECT_ID"));
        if (projectId != null) {
            String region = firstNonEmpty(config.region, env.get("SENTINEL_FIREBASE_REGION"));
            String functionName = firstNonEmpty(config.functionName, env.get("SENTINEL_FIREBASE_FUNCTION"));
            if (region == null) region = "us-central1";
            if (functionName == null) functionName = "ingestEvent";

            String derived = "https://" + region + "-" + projectId + ".cloudfunctions.net/" + functionName;
            return new EndpointResolution(derived, EndpointResolutionMode.DERIVED_FIREBASE);
        }

        throw new IllegalArgumentException(endpointResolutionGuidance());
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getUserId() {
        return this.userId;
    }

    public int log(TelemetryLevel level, String name, String message, Map<String, Object> metadata) throws IOException {
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("name", name);
        event.put("level", level.value());
        event.put("message", message);
        event.put("metadata", metadata == null ? new LinkedHashMap<>() : metadata);
        event.put("timestamp", isoNow());
        return send("telemetry", event);
    }

    public int recordError(Throwable error, String name, Map<String, Object> metadata) throws IOException {
        Map<String, Object> eventMetadata = new LinkedHashMap<>();
        if (metadata != null) {
            eventMetadata.putAll(metadata);
        }
        eventMetadata.put("error_type", error.getClass().getName());
        eventMetadata.put("error_description", error.getMessage());

        return log(TelemetryLevel.ERROR, name == null ? "error" : name, error.getMessage(), eventMetadata);
    }

    public int track(String name, AnalyticsKind kind, Map<String, Object> properties) throws IOException {
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("name", name);
        event.put("kind", kind.value());
        event.put("properties", properties == null ? new LinkedHashMap<>() : properties);
        event.put("timestamp", isoNow());
        return send("analytics", event);
    }

    public int screen(String name, Map<String, Object> properties) throws IOException {
        return track(name, AnalyticsKind.SCREEN, properties);
    }

    private int send(String stream, Map<String, Object> event) throws IOException {
        String currentUserId = this.userId;
        if (currentUserId != null && !currentUserId.isEmpty()) {
            event.put("user_hash", currentUserId);
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stream", stream);
        payload.put("source", projectSlug);
        payload.put("event", event);

        String jsonBody = JsonEncoder.encode(payload);
        return transport.post(baseUrl, apiKey, jsonBody);
    }

    private static String endpointResolutionGuidance() {
        return "Unable to resolve Sentinel ingest endpoint. " +
            "Set one of: baseUrl/ingestUrl in SDK config, or SENTINEL_INGEST_URL in env. " +
            "For derived mode set projectId (or SENTINEL_FIREBASE_PROJECT_ID / SENTINEL_PROJECT_ID) with optional region/functionName. " +
            "Cross-project deployments should prefer SENTINEL_INGEST_URL.";
    }

    private static String firstNonEmpty(String... values) {
        for (String value : values) {
            if (!isBlank(value)) {
                return value.trim();
            }
        }
        return null;
    }

    private static boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private static String isoNow() {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date());
    }

    private static final class DefaultHttpTransport implements HttpTransport {
        @Override
        public int post(String url, String apiKey, String jsonBody) throws IOException {
            HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setRequestMethod("POST");
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setRequestProperty("Authorization", "Bearer " + apiKey);

            byte[] bodyBytes = jsonBody.getBytes(StandardCharsets.UTF_8);
            connection.setFixedLengthStreamingMode(bodyBytes.length);

            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(bodyBytes);
            }

            int status = connection.getResponseCode();
            connection.disconnect();
            return status;
        }
    }
}
