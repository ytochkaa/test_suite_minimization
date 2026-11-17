CREATE TABLE parent (
    id INTEGER PRIMARY KEY
);

CREATE TABLE sample (
    id INTEGER PRIMARY KEY,
    parent_id INTEGER REFERENCES parent(id),
    code INTEGER UNIQUE,
    amount INTEGER NOT NULL,
    ceiling INTEGER,
    floor INTEGER,
    CONSTRAINT amount_min CHECK (amount >= 10),
    CONSTRAINT amount_ceiling CHECK (amount <= ceiling),
    CONSTRAINT ceiling_max CHECK (ceiling < 100),
    CONSTRAINT floor_min CHECK (floor > 0)
);
