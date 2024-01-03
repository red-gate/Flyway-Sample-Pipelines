CREATE TABLE Customer
(
    _id          INTEGER PRIMARY KEY AUTOINCREMENT,
    lastname     TEXT    NOT NULL,
    firstname    TEXT,
    animals_name TEXT    NOT NULL,
    animal_id    INTEGER NOT NULL,
    FOREIGN KEY (animal_id) REFERENCES Animal (_id)
);