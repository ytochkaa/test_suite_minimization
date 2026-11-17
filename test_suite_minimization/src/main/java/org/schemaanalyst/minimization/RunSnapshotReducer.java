package org.schemaanalyst.minimization;

import org.schemaanalyst.reduction.ReductionFactory;
import org.schemaanalyst.testgeneration.TestSuite;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;

/** Запускает один штатный редуктор на свежей копии сохранённого снимка. */
public final class RunSnapshotReducer {

    private RunSnapshotReducer() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "Usage: RunSnapshotReducer <input.ser> <none|simpleGreedy|additionalGreedy|HGS|random|sticcer> <output.json>");
        }

        File input = new File(args[0]);
        String reducer = args[1];
        File output = new File(args[2]);
        File parent = output.getAbsoluteFile().getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + parent);
        }

        BaselineSnapshot snapshot;
        try (ObjectInputStream stream = new ObjectInputStream(new FileInputStream(input))) {
            snapshot = (BaselineSnapshot) stream.readObject();
        }

        TestSuite original = snapshot.getTestSuite();
        TestSuite reduced = original;
        int coveredAfter = snapshot.getCoveredRequirements();
        long started = System.nanoTime();
        if (!"none".equals(reducer)) {
            ReductionFactory factory = new ReductionFactory();
            reduced = factory.reduceTestSuite(
                    original,
                    snapshot.rebuildRequirements(),
                    snapshot.getSchema(),
                    snapshot.getFailedRequirements(),
                    snapshot.getCoveredRequirements(),
                    snapshot.getSeed(),
                    reducer);
            coveredAfter = factory.numberOfSatisfiedRequirements;
        }
        long reductionNanoseconds = System.nanoTime() - started;
        if (reduced == null) {
            throw new IllegalStateException("Reducer returned null: " + reducer);
        }

        String sourceHash = sha256(input);
        SnapshotJsonExporter exporter = new SnapshotJsonExporter(
                snapshot, reduced, original.getTestCases());
        Map<String, Object> json = exporter.export(sourceHash);
        Map<String, Object> reduction = new LinkedHashMap<>();
        reduction.put("name", reducer);
        reduction.put("nanoseconds", reductionNanoseconds);
        reduction.put("coveredRequirementsAfter", coveredAfter);
        reduction.put("originalTestCount", original.getTestCases().size());
        reduction.put("finalTestCount", reduced.getTestCases().size());
        reduction.put("originalInsertCount", original.countNumberOfInserts());
        reduction.put("finalInsertCount", reduced.countNumberOfInserts());
        json.put("reduction", reduction);

        try (Writer writer = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(output), StandardCharsets.UTF_8))) {
            JsonUtil.write(json, writer);
            writer.write(System.lineSeparator());
        }

        System.out.println("source_snapshot_sha256=" + sourceHash);
        System.out.println("reducer=" + reducer);
        System.out.println("original_tests=" + original.getTestCases().size());
        System.out.println("final_tests=" + reduced.getTestCases().size());
        System.out.println("original_inserts=" + original.countNumberOfInserts());
        System.out.println("final_inserts=" + reduced.countNumberOfInserts());
        System.out.println("covered_requirements_after=" + coveredAfter);
        System.out.println("reduction_ns=" + reductionNanoseconds);
        System.out.println("json=" + output.getAbsolutePath());
    }

    private static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream stream = new FileInputStream(file)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = stream.read(buffer)) >= 0) {
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
