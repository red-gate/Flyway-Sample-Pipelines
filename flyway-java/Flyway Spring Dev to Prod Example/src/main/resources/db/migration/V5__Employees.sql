CREATE TABLE employees
(
    employee_id NUMBER PRIMARY KEY,
    first_name  VARCHAR(255) NOT NULL,
    last_name   VARCHAR(255) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(50)  NOT NULL,
    hire_date   DATE         NOT NULL,
    manager_id  NUMBER( 12, 0 ),
    job_title   VARCHAR(255) NOT NULL
);

