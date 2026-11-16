package org.schemaanalyst.minimization;

import org.schemaanalyst.sqlrepresentation.Schema;
import org.schemaanalyst.testgeneration.TestSuite;
import org.schemaanalyst.testgeneration.coveragecriterion.TestRequirement;
import org.schemaanalyst.testgeneration.coveragecriterion.TestRequirements;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/** Сериализуемый снимок одного исходного набора для независимых запусков редукторов. */
public class BaselineSnapshot implements Serializable {

    private static final long serialVersionUID = 1L;

    private final String criterion;
    private final String generator;
    private final long seed;
    private final int budget;
    private final long generationNanoseconds;
    private final int attemptedRequirements;
    private final int coveredRequirements;
    private final Schema schema;
    private final TestSuite testSuite;
    private final List<TestRequirement> requirements;
    private final List<TestRequirement> failedRequirements;

    public BaselineSnapshot(String criterion,
                            String generator,
                            long seed,
                            int budget,
                            long generationNanoseconds,
                            int attemptedRequirements,
                            int coveredRequirements,
                            Schema schema,
                            TestSuite testSuite,
                            List<TestRequirement> requirements,
                            List<TestRequirement> failedRequirements) {
        this.criterion = criterion;
        this.generator = generator;
        this.seed = seed;
        this.budget = budget;
        this.generationNanoseconds = generationNanoseconds;
        this.attemptedRequirements = attemptedRequirements;
        this.coveredRequirements = coveredRequirements;
        this.schema = schema;
        this.testSuite = testSuite;
        this.requirements = new ArrayList<>(requirements);
        this.failedRequirements = new ArrayList<>(failedRequirements);
    }

    public String getCriterion() { return criterion; }
    public String getGenerator() { return generator; }
    public long getSeed() { return seed; }
    public int getBudget() { return budget; }
    public long getGenerationNanoseconds() { return generationNanoseconds; }
    public int getAttemptedRequirements() { return attemptedRequirements; }
    public int getCoveredRequirements() { return coveredRequirements; }
    public Schema getSchema() { return schema; }
    public TestSuite getTestSuite() { return testSuite; }
    public List<TestRequirement> getRequirements() { return new ArrayList<>(requirements); }
    public List<TestRequirement> getFailedRequirements() { return new ArrayList<>(failedRequirements); }

    public TestRequirements rebuildRequirements() {
        TestRequirements rebuilt = new TestRequirements();
        for (TestRequirement requirement : requirements) {
            rebuilt.addTestRequirement(requirement);
        }
        return rebuilt;
    }
}
