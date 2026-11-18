package org.schemaanalyst.minimization;

import org.schemaanalyst.data.NumericValue;
import org.schemaanalyst.logic.RelationalOperator;
import org.schemaanalyst.sqlrepresentation.Schema;
import org.schemaanalyst.sqlrepresentation.Table;
import org.schemaanalyst.sqlrepresentation.datatype.DateDataType;
import org.schemaanalyst.sqlrepresentation.datatype.IntDataType;
import org.schemaanalyst.sqlrepresentation.datatype.NumericDataType;
import org.schemaanalyst.sqlrepresentation.datatype.TextDataType;
import org.schemaanalyst.sqlrepresentation.datatype.TimestampDataType;
import org.schemaanalyst.sqlrepresentation.expression.ColumnExpression;
import org.schemaanalyst.sqlrepresentation.expression.ConstantExpression;
import org.schemaanalyst.sqlrepresentation.expression.RelationalExpression;

/** Domain schema for laboratory, equipment, and vending-machine experiments. */
public class CourseworkSchema extends Schema {

    private static final long serialVersionUID = 1L;

    public CourseworkSchema() {
        super("CourseworkSchema");

        Table employees = createTable("employees");
        employees.createColumn("employee_id", new IntDataType());
        employees.createColumn("position", new TextDataType());
        employees.createColumn("employee_first_name", new TextDataType());
        employees.createColumn("employee_last_name", new TextDataType());
        employees.createColumn("employee_middle_name", new TextDataType());
        employees.createColumn("passport_number", new TextDataType());
        employees.createColumn("passport_issued_by", new TextDataType());
        employees.createColumn("passport_date", new DateDataType());
        employees.createColumn("snils", new TextDataType());
        employees.createColumn("inn", new TextDataType());
        employees.createColumn("hire_date", new DateDataType());
        createPrimaryKeyConstraint(employees, employees.getColumn("employee_id"));

        Table laboratories = createTable("laboratories");
        laboratories.createColumn("laboratory_id", new IntDataType());
        laboratories.createColumn("laboratory_specification", new TextDataType());
        createPrimaryKeyConstraint(laboratories, laboratories.getColumn("laboratory_id"));

        Table users = createTable("users");
        users.createColumn("user_id", new IntDataType());
        users.createColumn("snils", new TextDataType());
        users.createColumn("first_name", new TextDataType());
        users.createColumn("user_last_name", new TextDataType());
        users.createColumn("user_middle_name", new TextDataType());
        createPrimaryKeyConstraint(users, users.getColumn("user_id"));

        Table goods = createTable("goods");
        goods.createColumn("product_id", new IntDataType());
        goods.createColumn("product_name", new TextDataType());
        createPrimaryKeyConstraint(goods, goods.getColumn("product_id"));

        Table equipment = createTable("equipment");
        equipment.createColumn("equipment_id", new IntDataType());
        equipment.createColumn("equipment_name", new TextDataType());
        equipment.createColumn("equipment_description", new TextDataType());
        equipment.createColumn("certificate", new TextDataType());
        equipment.createColumn("laboratory_id", new IntDataType());
        createPrimaryKeyConstraint(equipment, equipment.getColumn("equipment_id"));
        createForeignKeyConstraint(
                equipment, equipment.getColumn("laboratory_id"),
                laboratories, laboratories.getColumn("laboratory_id"));

        Table automatons = createTable("automatons_food");
        automatons.createColumn("vending_machine_id", new IntDataType());
        automatons.createColumn("vending_machine_model", new TextDataType());
        automatons.createColumn("type_of_vending_machine", new TextDataType());
        automatons.createColumn("laboratory_id", new IntDataType());
        createPrimaryKeyConstraint(automatons, automatons.getColumn("vending_machine_id"));
        createForeignKeyConstraint(
                automatons, automatons.getColumn("laboratory_id"),
                laboratories, laboratories.getColumn("laboratory_id"));

        Table employeeLaboratories = createTable("employee_laboratories");
        employeeLaboratories.createColumn("employee_id", new IntDataType());
        employeeLaboratories.createColumn("laboratory_id", new IntDataType());
        createPrimaryKeyConstraint(
                employeeLaboratories,
                employeeLaboratories.getColumn("employee_id"),
                employeeLaboratories.getColumn("laboratory_id"));
        createForeignKeyConstraint(
                employeeLaboratories, employeeLaboratories.getColumn("employee_id"),
                employees, employees.getColumn("employee_id"));
        createForeignKeyConstraint(
                employeeLaboratories, employeeLaboratories.getColumn("laboratory_id"),
                laboratories, laboratories.getColumn("laboratory_id"));

        Table vendingMachinesGoods = createTable("vending_machines_goods");
        vendingMachinesGoods.createColumn("vending_machine_id", new IntDataType());
        vendingMachinesGoods.createColumn("goods_id", new IntDataType());
        vendingMachinesGoods.createColumn("quantity_of_goods", new IntDataType());
        vendingMachinesGoods.createColumn("stock_capacity", new IntDataType());
        vendingMachinesGoods.createColumn("price", new NumericDataType(10, 2));
        createPrimaryKeyConstraint(
                vendingMachinesGoods,
                vendingMachinesGoods.getColumn("vending_machine_id"),
                vendingMachinesGoods.getColumn("goods_id"));
        createForeignKeyConstraint(
                vendingMachinesGoods, vendingMachinesGoods.getColumn("vending_machine_id"),
                automatons, automatons.getColumn("vending_machine_id"));
        createForeignKeyConstraint(
                vendingMachinesGoods, vendingMachinesGoods.getColumn("goods_id"),
                goods, goods.getColumn("product_id"));
        createNotNullConstraint(vendingMachinesGoods, vendingMachinesGoods.getColumn("quantity_of_goods"));
        createNotNullConstraint(vendingMachinesGoods, vendingMachinesGoods.getColumn("stock_capacity"));
        createNotNullConstraint(vendingMachinesGoods, vendingMachinesGoods.getColumn("price"));

        createCheckConstraint("quantity_nonnegative", vendingMachinesGoods, new RelationalExpression(
                new ColumnExpression(vendingMachinesGoods, vendingMachinesGoods.getColumn("quantity_of_goods")),
                RelationalOperator.GREATER_OR_EQUALS,
                new ConstantExpression(new NumericValue(0))));
        createCheckConstraint("stock_capacity_positive", vendingMachinesGoods, new RelationalExpression(
                new ColumnExpression(vendingMachinesGoods, vendingMachinesGoods.getColumn("stock_capacity")),
                RelationalOperator.GREATER,
                new ConstantExpression(new NumericValue(0))));
        createCheckConstraint("quantity_within_capacity", vendingMachinesGoods, new RelationalExpression(
                new ColumnExpression(vendingMachinesGoods, vendingMachinesGoods.getColumn("quantity_of_goods")),
                RelationalOperator.LESS_OR_EQUALS,
                new ColumnExpression(vendingMachinesGoods, vendingMachinesGoods.getColumn("stock_capacity"))));

        Table usersEquipment = createTable("users_equipment");
        usersEquipment.createColumn("user_id", new IntDataType());
        usersEquipment.createColumn("equipment_id", new IntDataType());
        usersEquipment.createColumn("start_time", new TimestampDataType());
        usersEquipment.createColumn("end_time", new TimestampDataType());
        createPrimaryKeyConstraint(
                usersEquipment,
                usersEquipment.getColumn("user_id"),
                usersEquipment.getColumn("equipment_id"),
                usersEquipment.getColumn("start_time"));
        createForeignKeyConstraint(
                usersEquipment, usersEquipment.getColumn("user_id"),
                users, users.getColumn("user_id"));
        createForeignKeyConstraint(
                usersEquipment, usersEquipment.getColumn("equipment_id"),
                equipment, equipment.getColumn("equipment_id"));
    }
}
