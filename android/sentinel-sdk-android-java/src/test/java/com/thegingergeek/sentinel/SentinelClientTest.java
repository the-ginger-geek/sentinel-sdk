package com.thegingergeek.sentinel;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

public final class SentinelClientTest {
    public static void main(String[] args) throws Exception {
        run("logSendsTelemetryPayloadWithBearerAuth", SentinelClientTest::logSendsTelemetryPayloadWithBearerAuth);
        run("trackSendsAnalyticsPayload", SentinelClientTest::trackSendsAnalyticsPayload);
        run("screenUsesScreenKind", SentinelClientTest::screenUsesScreenKind);
        run("recordErrorAddsErrorMetadata", SentinelClientTest::recordErrorAddsErrorMetadata);
        run("endpointResolutionPrefersExplicitURL", SentinelClientTest::endpointResolutionPrefersExplicitURL);
        run("endpointResolutionUsesEnvURLBeforeDerived", SentinelClientTest::endpointResolutionUsesEnvURLBeforeDerived);
        run("endpointResolutionSupportsDerivedProjectAlias", SentinelClientTest::endpointResolutionSupportsDerivedProjectAlias);
        run("endpointResolutionFailureIsActionable", SentinelClientTest::endpointResolutionFailureIsActionable);
        run("fromEnvMissingRequiredFieldsIsActionable", SentinelClientTest::fromEnvMissingRequiredFieldsIsActionable);
        run("constructorValidatesRequiredFields", SentinelClientTest::constructorValidatesRequiredFields);
        run("jsonEncoderEscapesSpecialCharacters", SentinelClientTest::jsonEncoderEscapesSpecialCharacters);

        System.out.println("All Android Java SDK tests passed");
    }

    private static void logSendsTelemetryPayloadWithBearerAuth() throws IOException {
        RecordingTransport transport = new RecordingTransport();
        SentinelClient client = new SentinelClient(
            "https://example.com/ingestEvent",
            "test-key",
            "android-app",
            transport
        );

        Map<String, Object> metadata = new LinkedHashMap<>();
        metadata.put("channel", "android-java");

        int status = client.log(SentinelClient.TelemetryLevel.INFO, "app_started", null, metadata);

        assertEquals(200, status, "status");
        assertEquals("https://example.com/ingestEvent", transport.url, "url");
        assertEquals("test-key", transport.apiKey, "api key");
        assertContains(transport.body, "\"stream\":\"telemetry\"");
        assertContains(transport.body, "\"source\":\"android-app\"");
        assertContains(transport.body, "\"name\":\"app_started\"");
        assertContains(transport.body, "\"channel\":\"android-java\"");
    }

    private static void trackSendsAnalyticsPayload() throws IOException {
        RecordingTransport transport = new RecordingTransport();
        SentinelClient client = new SentinelClient(
            "https://example.com/ingestEvent",
            "test-key",
            "android-app",
            transport
        );

        Map<String, Object> props = new LinkedHashMap<>();
        props.put("plan", "pro");

        int status = client.track("upgrade_tapped", SentinelClient.AnalyticsKind.CONVERSION, props);

        assertEquals(200, status, "status");
        assertContains(transport.body, "\"stream\":\"analytics\"");
        assertContains(transport.body, "\"kind\":\"conversion\"");
        assertContains(transport.body, "\"plan\":\"pro\"");
    }

    private static void screenUsesScreenKind() throws IOException {
        RecordingTransport transport = new RecordingTransport();
        SentinelClient client = new SentinelClient(
            "https://example.com/ingestEvent",
            "test-key",
            "android-app",
            transport
        );

        int status = client.screen("dashboard", Map.of("tab", "home"));

        assertEquals(200, status, "status");
        assertContains(transport.body, "\"kind\":\"screen\"");
        assertContains(transport.body, "\"name\":\"dashboard\"");
        assertContains(transport.body, "\"tab\":\"home\"");
    }

    private static void recordErrorAddsErrorMetadata() throws IOException {
        RecordingTransport transport = new RecordingTransport();
        SentinelClient client = new SentinelClient(
            "https://example.com/ingestEvent",
            "test-key",
            "android-app",
            transport
        );

        client.recordError(new IllegalStateException("boom"), "api_failure", Map.of("flow", "checkout"));

        assertContains(transport.body, "\"stream\":\"telemetry\"");
        assertContains(transport.body, "\"level\":\"error\"");
        assertContains(transport.body, "\"name\":\"api_failure\"");
        assertContains(transport.body, "\"flow\":\"checkout\"");
        assertContains(transport.body, "\"error_type\":\"java.lang.IllegalStateException\"");
        assertContains(transport.body, "\"error_description\":\"boom\"");
    }

    private static void constructorValidatesRequiredFields() {
        expectIllegalArgument(() -> new SentinelClient("", "k", "p"));
        expectIllegalArgument(() -> new SentinelClient("https://example.com", "", "p"));
        expectIllegalArgument(() -> new SentinelClient("https://example.com", "k", ""));
    }

    private static void endpointResolutionPrefersExplicitURL() {
        SentinelClient.EndpointConfig config = new SentinelClient.EndpointConfig();
        config.baseUrl = "https://explicit.example.com/ingestEvent";
        config.projectId = "ignored-project";
        config.environment = Map.of("SENTINEL_INGEST_URL", "https://env.example.com/ingestEvent");

        SentinelClient.EndpointResolution resolution = SentinelClient.resolveEndpoint(config);
        assertEquals(SentinelClient.EndpointResolutionMode.EXPLICIT_URL, resolution.mode, "mode");
        assertEquals("https://explicit.example.com/ingestEvent", resolution.url, "url");
    }

    private static void endpointResolutionUsesEnvURLBeforeDerived() {
        SentinelClient.EndpointConfig config = new SentinelClient.EndpointConfig();
        config.environment = Map.of(
            "SENTINEL_INGEST_URL", "https://env.example.com/ingestEvent",
            "SENTINEL_FIREBASE_PROJECT_ID", "sentinel-8997b"
        );

        SentinelClient.EndpointResolution resolution = SentinelClient.resolveEndpoint(config);
        assertEquals(SentinelClient.EndpointResolutionMode.ENV_URL, resolution.mode, "mode");
        assertEquals("https://env.example.com/ingestEvent", resolution.url, "url");
    }

    private static void endpointResolutionSupportsDerivedProjectAlias() {
        SentinelClient.EndpointConfig config = new SentinelClient.EndpointConfig();
        config.environment = Map.of(
            "SENTINEL_PROJECT_ID", "sentinel-8997b",
            "SENTINEL_FIREBASE_REGION", "europe-west1",
            "SENTINEL_FIREBASE_FUNCTION", "ingestEvent"
        );

        SentinelClient.EndpointResolution resolution = SentinelClient.resolveEndpoint(config);
        assertEquals(SentinelClient.EndpointResolutionMode.DERIVED_FIREBASE, resolution.mode, "mode");
        assertEquals("https://europe-west1-sentinel-8997b.cloudfunctions.net/ingestEvent", resolution.url, "url");
    }

    private static void endpointResolutionFailureIsActionable() {
        try {
            SentinelClient.resolveEndpoint(new SentinelClient.EndpointConfig());
            throw new AssertionError("expected IllegalArgumentException");
        } catch (IllegalArgumentException expected) {
            assertContains(expected.getMessage(), "baseUrl/ingestUrl");
            assertContains(expected.getMessage(), "SENTINEL_INGEST_URL");
            assertContains(expected.getMessage(), "SENTINEL_FIREBASE_PROJECT_ID");
            assertContains(expected.getMessage(), "Cross-project deployments");
        }
    }

    private static void fromEnvMissingRequiredFieldsIsActionable() {
        try {
            SentinelClient.fromEnv(Map.of("SENTINEL_INGEST_URL", "https://env.example.com/ingestEvent"));
            throw new AssertionError("expected IllegalArgumentException");
        } catch (IllegalArgumentException expected) {
            assertContains(expected.getMessage(), "SENTINEL_API_KEY");
            assertContains(expected.getMessage(), "SENTINEL_PROJECT_SLUG");
            assertContains(expected.getMessage(), "Cross-project deployments");
        }
    }

    private static void jsonEncoderEscapesSpecialCharacters() {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("message", "line1\nline2 \"quoted\"");
        payload.put("nested", Arrays.asList("a", "b"));

        String encoded = JsonEncoder.encode(payload);
        assertContains(encoded, "line1\\nline2");
        assertContains(encoded, "\\\"quoted\\\"");
        assertContains(encoded, "\"nested\":[\"a\",\"b\"]");
    }

    private static void run(String name, ThrowingRunnable test) throws Exception {
        try {
            test.run();
            System.out.println("PASS " + name);
        } catch (Throwable t) {
            System.err.println("FAIL " + name + ": " + t.getMessage());
            throw t;
        }
    }

    private static void assertContains(String value, String expected) {
        if (value == null || !value.contains(expected)) {
            throw new AssertionError("expected to find: " + expected + " in: " + value);
        }
    }

    private static void assertEquals(Object expected, Object actual, String field) {
        if ((expected == null && actual != null) || (expected != null && !expected.equals(actual))) {
            throw new AssertionError(field + " expected=" + expected + " actual=" + actual);
        }
    }

    private static void expectIllegalArgument(ThrowingRunnable runnable) {
        try {
            runnable.run();
            throw new AssertionError("expected IllegalArgumentException");
        } catch (IllegalArgumentException expected) {
            // expected
        } catch (Exception other) {
            throw new AssertionError("unexpected exception: " + other.getClass().getName());
        }
    }

    private interface ThrowingRunnable {
        void run() throws Exception;
    }

    private static final class RecordingTransport implements SentinelClient.HttpTransport {
        String url;
        String apiKey;
        String body;

        @Override
        public int post(String url, String apiKey, String jsonBody) {
            this.url = url;
            this.apiKey = apiKey;
            this.body = jsonBody;
            return 200;
        }
    }
}
