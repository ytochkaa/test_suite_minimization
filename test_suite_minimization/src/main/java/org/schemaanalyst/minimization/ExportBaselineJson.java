package org.schemaanalyst.minimization;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.ObjectInputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/** Читает неизменяемый снимок и экспортирует данные для C++-компонента. */
public final class ExportBaselineJson {

    private ExportBaselineJson() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            throw new IllegalArgumentException("Usage: ExportBaselineJson <input.ser> <output.json>");
        }

        File input = new File(args[0]);
        File output = new File(args[1]);
        File parent = output.getAbsoluteFile().getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + parent);
        }

        BaselineSnapshot snapshot;
        try (ObjectInputStream stream = new ObjectInputStream(new FileInputStream(input))) {
            snapshot = (BaselineSnapshot) stream.readObject();
        }

        SnapshotJsonExporter exporter = new SnapshotJsonExporter(snapshot);
        try (Writer writer = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(output), StandardCharsets.UTF_8))) {
            JsonUtil.write(exporter.export(sha256(input)), writer);
            writer.write(System.lineSeparator());
        }

        System.out.println("json=" + output.getAbsolutePath());
        System.out.println("snapshot_sha256=" + sha256(input));
        System.out.println("tests=" + snapshot.getTestSuite().getTestCases().size());
        System.out.println("requirements=" + snapshot.getRequirements().size());
    }

    private static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                digest.update(buffer, 0, read);
            }
        }
        StringBuilder result = new StringBuilder();
        for (byte value : digest.digest()) {
            result.append(String.format("%02x", value & 0xff));
        }
        return result.toString();
    }
}
