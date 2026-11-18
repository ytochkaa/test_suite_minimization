package org.schemaanalyst.minimization;

import org.schemaanalyst.data.generation.DataGenerator;
import org.schemaanalyst.data.generation.DataGeneratorFactory;
import org.schemaanalyst.dbms.DBMS;
import org.schemaanalyst.dbms.DBMSFactory;
import org.schemaanalyst.sqlrepresentation.Schema;
import org.schemaanalyst.testgeneration.TestSuite;
import org.schemaanalyst.testgeneration.TestSuiteGenerationReport;
import org.schemaanalyst.testgeneration.TestSuiteGenerator;
import org.schemaanalyst.testgeneration.coveragecriterion.CoverageCriterionFactory;
import org.schemaanalyst.testgeneration.coveragecriterion.TestRequirements;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectOutputStream;
import java.security.MessageDigest;

/** Создаёт один исходный набор и сохраняет его для всех последующих редукторов. */
public final class GenerateBaselineSnapshot {

    private GenerateBaselineSnapshot() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 4) {
            throw new IllegalArgumentException(
                    "Usage: GenerateBaselineSnapshot <generator> <seed> <budget> <output.ser>");
        }

        String generatorName = args[0];
        long seed = Long.parseLong(args[1]);
        int budget = Integer.parseInt(args[2]);
        File output = new File(args[3]);
        File parent = output.getAbsoluteFile().getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + parent);
        }

        String criterionName = "CondAICC";
        Schema schema = new CourseworkSchema();
        DBMS dbms = DBMSFactory.instantiate("Postgres");
        TestRequirements requirements = CoverageCriterionFactory
                .instantiateSchemaCriterion(criterionName, schema, dbms)
                .generateRequirements();
        requirements.filterInfeasible();
        requirements.reduce();

        DataGenerator dataGenerator = DataGeneratorFactory
                .instantiate(generatorName, seed, budget, schema);
        TestSuiteGenerator generator = new TestSuiteGenerator(
                schema,
                requirements,
                dbms.getValueFactory(),
                dataGenerator,
                generatorName,
                seed,
                false,
                false);

        long started = System.nanoTime();
        TestSuite suite = generator.generate();
        long generationNanoseconds = System.nanoTime() - started;
        TestSuiteGenerationReport report = generator.getTestSuiteGenerationReport();

        BaselineSnapshot snapshot = new BaselineSnapshot(
                criterionName,
                generatorName,
                seed,
                budget,
                generationNanoseconds,
                report.getNumTestRequirementsAttempted(),
                report.getNumTestRequirementsCovered(),
                schema,
                suite,
                requirements.getTestRequirements(),
                report.getFailedTestRequirements());

        try (ObjectOutputStream stream = new ObjectOutputStream(new FileOutputStream(output))) {
            stream.writeObject(snapshot);
        }

        System.out.println("snapshot=" + output.getAbsolutePath());
        System.out.println("sha256=" + sha256(output));
        System.out.println("generator=" + generatorName);
        System.out.println("criterion=" + criterionName);
        System.out.println("seed=" + seed);
        System.out.println("budget=" + budget);
        System.out.println("tests=" + suite.getTestCases().size());
        System.out.println("inserts=" + suite.countNumberOfInserts());
        System.out.println("requirements_attempted=" + report.getNumTestRequirementsAttempted());
        System.out.println("requirements_covered=" + report.getNumTestRequirementsCovered());
        System.out.println("generation_ns=" + generationNanoseconds);
    }

    private static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(file)) {
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
