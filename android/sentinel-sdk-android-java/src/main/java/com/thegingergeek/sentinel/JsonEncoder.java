package com.thegingergeek.sentinel;

import java.util.List;
import java.util.Map;

final class JsonEncoder {
    private JsonEncoder() {}

    static String encode(Object value) {
        if (value == null) return "null";

        if (value instanceof String) {
            return "\"" + escape((String) value) + "\"";
        }

        if (value instanceof Number || value instanceof Boolean) {
            return String.valueOf(value);
        }

        if (value instanceof Map<?, ?>) {
            StringBuilder builder = new StringBuilder();
            builder.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> entry : ((Map<?, ?>) value).entrySet()) {
                if (!first) builder.append(',');
                first = false;
                builder.append("\"").append(escape(String.valueOf(entry.getKey()))).append("\":");
                builder.append(encode(entry.getValue()));
            }
            builder.append('}');
            return builder.toString();
        }

        if (value instanceof List<?>) {
            StringBuilder builder = new StringBuilder();
            builder.append('[');
            boolean first = true;
            for (Object item : (List<?>) value) {
                if (!first) builder.append(',');
                first = false;
                builder.append(encode(item));
            }
            builder.append(']');
            return builder.toString();
        }

        return "\"" + escape(String.valueOf(value)) + "\"";
    }

    private static String escape(String value) {
        return value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
    }
}
