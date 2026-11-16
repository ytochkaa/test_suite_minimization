package org.schemaanalyst.minimization;

import org.schemaanalyst.data.NumericValue;
import org.schemaanalyst.logic.RelationalOperator;
import org.schemaanalyst.sqlrepresentation.Schema;
import org.schemaanalyst.sqlrepresentation.Table;
import org.schemaanalyst.sqlrepresentation.datatype.IntDataType;
import org.schemaanalyst.sqlrepresentation.expression.ColumnExpression;
import org.schemaanalyst.sqlrepresentation.expression.ConstantExpression;
import org.schemaanalyst.sqlrepresentation.expression.RelationalExpression;

/** Небольшая схема для воспроизводимой проверки генерации и сокращения. */
public class CourseworkSchema extends Schema {

    private static final long serialVersionUID = 1L;

    public CourseworkSchema() {
        super("CourseworkSchema");

        Table parent = createTable("parent");
        parent.createColumn("id", new IntDataType());
        createPrimaryKeyConstraint(parent, parent.getColumn("id"));

        Table sample = createTable("sample");
        for (String name : new String[]{"id", "parent_id", "code", "amount", "ceiling", "floor"}) {
            sample.createColumn(name, new IntDataType());
        }

        createPrimaryKeyConstraint(sample, sample.getColumn("id"));
        createForeignKeyConstraint(sample, sample.getColumn("parent_id"), parent, parent.getColumn("id"));
        createUniqueConstraint(sample, sample.getColumn("code"));
        createNotNullConstraint(sample, sample.getColumn("amount"));

        createCheckConstraint("amount_min", sample, new RelationalExpression(
                new ColumnExpression(sample, sample.getColumn("amount")),
                RelationalOperator.GREATER_OR_EQUALS,
                new ConstantExpression(new NumericValue(10))));

        createCheckConstraint("amount_ceiling", sample, new RelationalExpression(
                new ColumnExpression(sample, sample.getColumn("amount")),
                RelationalOperator.LESS_OR_EQUALS,
                new ColumnExpression(sample, sample.getColumn("ceiling"))));

        createCheckConstraint("ceiling_max", sample, new RelationalExpression(
                new ColumnExpression(sample, sample.getColumn("ceiling")),
                RelationalOperator.LESS,
                new ConstantExpression(new NumericValue(100))));

        createCheckConstraint("floor_min", sample, new RelationalExpression(
                new ColumnExpression(sample, sample.getColumn("floor")),
                RelationalOperator.GREATER,
                new ConstantExpression(new NumericValue(0))));
    }
}
