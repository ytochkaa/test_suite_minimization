CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY,
    position TEXT,
    employee_first_name TEXT,
    employee_last_name TEXT,
    employee_middle_name TEXT,
    passport_number TEXT,
    passport_issued_by TEXT,
    passport_date DATE,
    snils TEXT,
    inn TEXT,
    hire_date DATE
);

CREATE TABLE laboratories (
    laboratory_id INTEGER PRIMARY KEY,
    laboratory_specification TEXT
);

CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    snils TEXT,
    first_name TEXT,
    user_last_name TEXT,
    user_middle_name TEXT
);

CREATE TABLE goods (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT
);

CREATE TABLE equipment (
    equipment_id INTEGER PRIMARY KEY,
    equipment_name TEXT,
    equipment_description TEXT,
    certificate TEXT,
    laboratory_id INTEGER REFERENCES laboratories(laboratory_id)
);

CREATE TABLE automatons_food (
    vending_machine_id INTEGER PRIMARY KEY,
    vending_machine_model TEXT,
    type_of_vending_machine TEXT,
    laboratory_id INTEGER REFERENCES laboratories(laboratory_id)
);

CREATE TABLE employee_laboratories (
    employee_id INTEGER REFERENCES employees(employee_id),
    laboratory_id INTEGER REFERENCES laboratories(laboratory_id),
    PRIMARY KEY (employee_id, laboratory_id)
);

CREATE TABLE vending_machines_goods (
    vending_machine_id INTEGER REFERENCES automatons_food(vending_machine_id),
    goods_id INTEGER REFERENCES goods(product_id),
    quantity_of_goods INTEGER NOT NULL,
    stock_capacity INTEGER NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (vending_machine_id, goods_id),
    CONSTRAINT quantity_nonnegative CHECK (quantity_of_goods >= 0),
    CONSTRAINT stock_capacity_positive CHECK (stock_capacity > 0),
    CONSTRAINT quantity_within_capacity CHECK (quantity_of_goods <= stock_capacity)
);

CREATE TABLE users_equipment (
    user_id INTEGER REFERENCES users(user_id),
    equipment_id INTEGER REFERENCES equipment(equipment_id),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    PRIMARY KEY (user_id, equipment_id, start_time)
);
