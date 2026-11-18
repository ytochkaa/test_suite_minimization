package org.schemaanalyst.minimization;

import java.io.IOException;
import java.io.Writer;
import java.util.List;
import java.util.Map;

/** Минимальный JSON writer без дополнительной зависимости. */
final class JsonUtil {

    private JsonUtil() {
    }

    static void write(Object value, Writer output) throws IOException {
        if (value == null) {
            output.write("null");
        } else if (value instanceof String) {
            writeString((String) value, output);
        } else if (value instanceof Boolean || value instanceof Number) {
            output.write(value.toString());
        } else if (value instanceof Map) {
            writeMap((Map<?, ?>) value, output);
        } else if (value instanceof List) {
            writeList((List<?>) value, output);
        } else {
            throw new IllegalArgumentException("Unsupported JSON value: " + value.getClass());
        }
    }

    private static void writeMap(Map<?, ?> map, Writer output) throws IOException {
        output.write('{');
        boolean first = true;
        for (Map.Entry<?, ?> entry : map.entrySet()) {
            if (!(entry.getKey() instanceof String)) {
                throw new IllegalArgumentException("JSON object key must be a string");
            }
            if (!first) {
                output.write(',');
            }
            first = false;
            writeString((String) entry.getKey(), output);
            output.write(':');
            write(entry.getValue(), output);
        }
        output.write('}');
    }

    private static void writeList(List<?> list, Writer output) throws IOException {
        output.write('[');
        for (int index = 0; index < list.size(); index++) {
            if (index > 0) {
                output.write(',');
            }
            write(list.get(index), output);
        }
        output.write(']');
    }

    private static void writeString(String value, Writer output) throws IOException {
        output.write('"');
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            switch (character) {
                case '"': output.write("\\\""); break;
                case '\\': output.write("\\\\"); break;
                case '\b': output.write("\\b"); break;
                case '\f': output.write("\\f"); break;
                case '\n': output.write("\\n"); break;
                case '\r': output.write("\\r"); break;
                case '\t': output.write("\\t"); break;
                default:
                    if (character < 0x20) {
                        output.write(String.format("\\u%04x", (int) character));
                    } else {
                        output.write(character);
                    }
            }
        }
        output.write('"');
    }
}
