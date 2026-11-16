package org.schemaanalyst.minimization;

import org.schemaanalyst.data.Cell;
import org.schemaanalyst.data.Data;
import org.schemaanalyst.data.NumericValue;
import org.schemaanalyst.data.Row;
import org.schemaanalyst.dbms.DBMS;
import org.schemaanalyst.dbms.DBMSFactory;
import org.schemaanalyst.sqlrepresentation.Column;
import org.schemaanalyst.sqlrepresentation.Schema;
import org.schemaanalyst.sqlrepresentation.Table;
import org.schemaanalyst.sqlrepresentation.constraint.CheckConstraint;
import org.schemaanalyst.sqlrepresentation.expression.ColumnExpression;
import org.schemaanalyst.sqlrepresentation.expression.ConstantExpression;
import org.schemaanalyst.sqlrepresentation.expression.Expression;
import org.schemaanalyst.sqlrepresentation.expression.RelationalExpression;
import org.schemaanalyst.testgeneration.TestCase;
import org.schemaanalyst.testgeneration.coveragecriterion.TestRequirement;
import org.schemaanalyst.testgeneration.coveragecriterion.TestRequirementDescriptor;
import org.schemaanalyst.testgeneration.coveragecriterion.predicate.checker.PredicateChecker;
import org.schemaanalyst.testgeneration.coveragecriterion.predicate.checker.PredicateCheckerFactory;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Преобразует сериализованный снимок SchemaAnalyst в документированный JSON. */
final class SnapshotJsonExporter {

    private final BaselineSnapshot snapshot;
    private final DBMS dbms;
    private final List<TestRequirement> requirements;
    private final Set<TestRequirement> failedRequirements;

    SnapshotJsonExporter(BaselineSnapshot snapshot) {
        this.snapshot = snapshot;
        this.dbms = DBMSFactory.instantiate("Postgres");
        this.requirements = snapshot.getRequirements();
        this.failedRequirements = new HashSet<>(snapshot.getFailedRequirements());
    }

    Map<String, Object> export(String snapshotSha256) {
        Map<String, Object> root = object();
        root.put("formatVersion", 1);
        root.put("snapshotSha256", snapshotSha256);
        root.put("generation", generation());
        root.put("schema", schema(snapshot.getSchema()));
        root.put("requirements", requirements());
        root.put("tests", tests());
        return root;
    }

    private Map<String, Object> generation() {
        Map<String, Object> result = object();
        result.put("criterion", snapshot.getCriterion());
        result.put("generator", snapshot.getGenerator());
        result.put("seed", snapshot.getSeed());
        result.put("budget", snapshot.getBudget());
        result.put("generationNanoseconds", snapshot.getGenerationNanoseconds());
        result.put("attemptedRequirements", snapshot.getAttemptedRequirements());
        result.put("coveredRequirements", snapshot.getCoveredRequirements());
        return result;
    }

    private Map<String, Object> schema(Schema schema) {
        Map<String, Object> result = object();
        result.put("name", schema.getName());

        List<Object> tables = array();
        for (Table table : schema.getTables()) {
            Map<String, Object> tableJson = object();
            tableJson.put("name", table.getName());
            List<Object> columns = array();
            for (Column column : table.getColumns()) {
                Map<String, Object> columnJson = object();
                columnJson.put("name", column.getName());
                columnJson.put("type", column.getDataType().getClass().getSimpleName());
                columns.add(columnJson);
            }
            tableJson.put("columns", columns);
            tables.add(tableJson);
        }
        result.put("tables", tables);

        List<Object> checks = array();
        int index = 0;
        for (CheckConstraint constraint : schema.getCheckConstraints()) {
            checks.add(check(++index, constraint));
        }
        result.put("checks", checks);
        return result;
    }

    private Map<String, Object> check(int index, CheckConstraint constraint) {
        Map<String, Object> result = object();
        String name = constraint.getName();
        result.put("id", name == null ? "CHECK_" + index : name);
        result.put("table", constraint.getTable().getName());
        result.put("expression", constraint.getExpression().toString());

        Expression expression = constraint.getExpression();
        if (!(expression instanceof RelationalExpression)) {
            result.put("supported", false);
            result.put("unsupportedReason", "CHECK is not a simple relational expression");
            return result;
        }

        RelationalExpression relational = (RelationalExpression) expression;
        String operator = relational.getRelationalOperator().toString();
        boolean supportedOperator = "<".equals(operator) || "<=".equals(operator)
                || ">".equals(operator) || ">=".equals(operator);
        Map<String, Object> left = operand(relational.getLHS());
        Map<String, Object> right = operand(relational.getRHS());
        boolean supportedShape = left != null && right != null
                && ("column".equals(left.get("kind")) || "column".equals(right.get("kind")));

        result.put("supported", supportedOperator && supportedShape);
        result.put("operator", operator);
        result.put("left", left);
        result.put("right", right);
        if (!supportedOperator) {
            result.put("unsupportedReason", "operator is outside <, <=, >, >=");
        } else if (!supportedShape) {
            result.put("unsupportedReason", "operands are outside column/constant MVP");
        }
        return result;
    }

    private Map<String, Object> operand(Expression expression) {
        Map<String, Object> result = object();
        if (expression instanceof ColumnExpression) {
            ColumnExpression columnExpression = (ColumnExpression) expression;
            result.put("kind", "column");
            result.put("table", columnExpression.getTable().getName());
            result.put("column", columnExpression.getColumn().getName());
            result.put("type", columnExpression.getColumn().getDataType().getClass().getSimpleName());
            return result;
        }
        if (expression instanceof ConstantExpression) {
            Object value = ((ConstantExpression) expression).getValue();
            if (!(value instanceof NumericValue)) {
                return null;
            }
            result.put("kind", "constant");
            result.put("value", value.toString());
            result.put("type", "NumericValue");
            return result;
        }
        return null;
    }

    private List<Object> requirements() {
        List<Object> result = array();
        for (int index = 0; index < requirements.size(); index++) {
            TestRequirement requirement = requirements.get(index);
            Map<String, Object> requirementJson = object();
            requirementJson.put("id", requirementId(index));
            requirementJson.put("expectedResult", requirement.getResult());
            requirementJson.put("requiresComparisonRow", requirement.getRequiresComparisonRow());
            requirementJson.put("predicate", requirement.getPredicate().toString());
            requirementJson.put("failedDuringGeneration", failedRequirements.contains(requirement));
            List<Object> descriptors = array();
            for (TestRequirementDescriptor descriptor : requirement.getDescriptors()) {
                descriptors.add(descriptor.toString());
            }
            requirementJson.put("descriptors", descriptors);
            result.add(requirementJson);
        }
        return result;
    }

    private List<Object> tests() {
        List<Object> result = array();
        List<TestCase> tests = snapshot.getTestSuite().getTestCases();
        for (int index = 0; index < tests.size(); index++) {
            TestCase test = tests.get(index);
            Map<String, Object> testJson = object();
            testJson.put("id", "T" + (index + 1));
            testJson.put("expectedResult", test.getTestRequirement().getResult());
            testJson.put("sourceRequirementId", findRequirementId(test.getTestRequirement()));
            testJson.put("coveredRequirementIds", coveredRequirements(test));
            testJson.put("state", data(test.getState()));
            testJson.put("data", data(test.getData()));
            testJson.put("stateSql", sql(test.getState()));
            testJson.put("dataSql", sql(test.getData()));
            testJson.put("stateInsertCount", test.getState().getNumRows());
            testJson.put("dataInsertCount", test.getData().getNumRows());
            result.add(testJson);
        }
        return result;
    }

    private List<Object> data(Data data) {
        List<Object> result = array();
        for (Table table : data.getTables()) {
            for (Row row : data.getRows(table)) {
                Map<String, Object> rowJson = object();
                rowJson.put("table", table.getName());
                Map<String, Object> values = object();
                for (Cell cell : row.getCells()) {
                    values.put(cell.getColumn().getName(), cell.isNull() ? null : cell.getValue().toString());
                }
                rowJson.put("values", values);
                result.add(rowJson);
            }
        }
        return result;
    }

    private List<Object> sql(Data data) {
        List<Object> result = array();
        for (String statement : dbms.getSQLWriter().writeInsertStatements(snapshot.getSchema(), data)) {
            result.add(statement + ";");
        }
        return result;
    }

    private List<Object> coveredRequirements(TestCase test) {
        List<Object> result = array();
        for (int index = 0; index < requirements.size(); index++) {
            TestRequirement requirement = requirements.get(index);
            if (!failedRequirements.contains(requirement) && covers(test, requirement)) {
                result.add(requirementId(index));
            }
        }
        return result;
    }

    private boolean covers(TestCase test, TestRequirement requirement) {
        if (!sameTables(test.getTestRequirement(), requirement)) {
            return false;
        }
        if (test.getTestRequirement().getRequiresComparisonRow() != requirement.getRequiresComparisonRow()) {
            return false;
        }
        if (!test.getTestRequirement().getResult().equals(requirement.getResult())) {
            return false;
        }
        PredicateChecker checker = PredicateCheckerFactory.instantiate(
                requirement.getPredicate(), true, test.getData(), test.getState());
        return checker.check();
    }

    private boolean sameTables(TestRequirement first, TestRequirement second) {
        Set<String> firstNames = new HashSet<>();
        for (Table table : first.getTables()) {
            firstNames.add(table.getName());
        }
        Set<String> secondNames = new HashSet<>();
        for (Table table : second.getTables()) {
            secondNames.add(table.getName());
        }
        return firstNames.equals(secondNames);
    }

    private String findRequirementId(TestRequirement requirement) {
        for (int index = 0; index < requirements.size(); index++) {
            if (requirements.get(index).equals(requirement)) {
                return requirementId(index);
            }
        }
        return null;
    }

    private String requirementId(int zeroBasedIndex) {
        return "R" + (zeroBasedIndex + 1);
    }

    private static Map<String, Object> object() {
        return new LinkedHashMap<>();
    }

    private static List<Object> array() {
        return new ArrayList<>();
    }
}
