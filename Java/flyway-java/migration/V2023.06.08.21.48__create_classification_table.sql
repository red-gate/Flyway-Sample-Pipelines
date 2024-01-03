CREATE TABLE Classification
(
    _id  INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL
);

CREATE TABLE Animal_tmp
(
    _id               INTEGER PRIMARY KEY AUTOINCREMENT,
    type              TEXT    NOT NULL,
    classification_id INTEGER NOT NULL,
    FOREIGN KEY (classification_id) REFERENCES Classification (_id)
);

INSERT INTO Classification(type)
SELECT DISTINCT classification
FROM Animal;

INSERT INTO Animal_tmp(type, classification_id)
SELECT a.type, c._id
FROM Animal a
         JOIN Classification c ON c.type = a.classification;

DROP TABLE Animal;

ALTER TABLE Animal_tmp
    RENAME TO Animal;