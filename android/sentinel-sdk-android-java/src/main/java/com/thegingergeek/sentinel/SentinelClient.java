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

    public interface HttpTransport {
        int post(String url, String apiKey, String jsonBody) throws IOException;
    }

    private final String baseUrl;
    private final String apiKey;
    private final String projectSlug;
    private final HttpTransport transport;

    public SentinelClient(String baseUrl, String apiKey, String projectSlug) {
        this(baseUrl, apiKey, projectSlug, new DefaultHttpTransport());
    }

    public SentinelClient(String baseUrl, String apiKey, String projectSlug, HttpTransport transport) {
        if (baseUrl == null || baseUrl.isEmpty()) throw new IllegalArgumentException("baseUrl is required");
        if (apiKey == null || apiKey.isEmpty()) throw new IllegalArgumentException("apiKey is required");
        if (projectSlug == null || projectSlug.isEmpty()) throw new IllegalArgumentException("projectSlug is required");
        if (transport == null) throw new IllegalArgumentException("transport is required");

        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
        this.projectSlug = projectSlug;
        this.transport = transport;
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
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stream", stream);
        payload.put("source", projectSlug);
        payload.put("event", event);

        String jsonBody = JsonEncoder.encode(payload);
        return transport.post(baseUrl, apiKey, jsonBody);
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
