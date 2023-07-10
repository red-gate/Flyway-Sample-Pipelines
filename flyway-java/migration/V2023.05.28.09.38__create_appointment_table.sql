CREATE TABLE Appointment
(
    _id         INTEGER PRIMARY KEY AUTOINCREMENT,
    date_time   TEXT    NOT NULL,
    customer_id INTEGER NOT NULL,
    vet_id      INTEGER NOT NULL,
    reason      TEXT    NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customer (_id),
    FOREIGN KEY (vet_id) REFERENCES Vet (_id)
);