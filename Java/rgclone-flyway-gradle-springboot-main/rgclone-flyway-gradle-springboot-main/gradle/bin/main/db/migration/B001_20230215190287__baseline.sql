SET DEFINE OFF

CREATE SEQUENCE hr.departments_seq INCREMENT BY 10 MAXVALUE 9990 NOCACHE;

CREATE SEQUENCE hr.locations_seq INCREMENT BY 100 MAXVALUE 9900 NOCACHE;

CREATE SEQUENCE hr.employees_seq NOCACHE;

CREATE TABLE hr.contacts_notes (
  contact_id NUMBER(6),
  first_name VARCHAR2(20 BYTE),
  last_name VARCHAR2(25 BYTE),
  fidelity_num VARCHAR2(20 BYTE)
);

CREATE TABLE hr.regions (
  region_id NUMBER NOT NULL,
  region_name VARCHAR2(25 BYTE)
);

CREATE UNIQUE INDEX hr.reg_id_pkx ON hr.regions(region_id);

ALTER TABLE hr.regions ADD CONSTRAINT reg_id_pk PRIMARY KEY (region_id) USING INDEX hr.reg_id_pkx;

CREATE TABLE hr.countries (
  country_id CHAR(2 BYTE) NOT NULL,
  country_name VARCHAR2(40 BYTE),
  region_id NUMBER
);

COMMENT ON COLUMN hr.countries.country_id IS 'Primary key of countries table.';

COMMENT ON COLUMN hr.countries.country_name IS 'Country name';

COMMENT ON COLUMN hr.countries.region_id IS 'Region ID for the country. Foreign key to region_id column in the departments table.';

CREATE UNIQUE INDEX hr.country_c_id_pkx ON hr.countries(country_id);

ALTER TABLE hr.countries ADD CONSTRAINT country_c_id_pk PRIMARY KEY (country_id) USING INDEX hr.country_c_id_pkx;

CREATE TABLE hr.locations (
  location_id NUMBER(4) NOT NULL,
  street_address VARCHAR2(40 BYTE),
  postal_code VARCHAR2(12 BYTE),
  city VARCHAR2(30 BYTE) NOT NULL,
  state_province VARCHAR2(25 BYTE),
  country_id CHAR(2 BYTE)
);

COMMENT ON COLUMN hr.locations.location_id IS 'Primary key of locations table';

COMMENT ON COLUMN hr.locations.street_address IS 'Street address of an office, warehouse, or production site of a company.
Contains building number and street name';

COMMENT ON COLUMN hr.locations.postal_code IS 'Postal code of the location of an office, warehouse, or production site
of a company. ';

COMMENT ON COLUMN hr.locations.city IS 'A not null column that shows city where an office, warehouse, or
production site of a company is located. ';

COMMENT ON COLUMN hr.locations.state_province IS 'State or Province where an office, warehouse, or production site of a
company is located.';

COMMENT ON COLUMN hr.locations.country_id IS 'Country where an office, warehouse, or production site of a company is
located. Foreign key to country_id column of the countries table.';

CREATE UNIQUE INDEX hr.loc_id_pkx ON hr.locations(location_id);

ALTER TABLE hr.locations ADD CONSTRAINT loc_id_pk PRIMARY KEY (location_id) USING INDEX hr.loc_id_pkx;

CREATE TABLE hr.departments (
  department_id NUMBER(4) NOT NULL,
  department_name VARCHAR2(30 BYTE) NOT NULL,
  manager_id NUMBER(6),
  location_id NUMBER(4)
);

COMMENT ON COLUMN hr.departments.department_id IS 'Primary key column of departments table.';

COMMENT ON COLUMN hr.departments.department_name IS 'A not null column that shows name of a department. Administration,
Marketing, Purchasing, Human Resources, Shipping, IT, Executive, Public
Relations, Sales, Finance, and Accounting. ';

COMMENT ON COLUMN hr.departments.manager_id IS 'Manager_id of a department. Foreign key to employee_id column of employees table. The manager_id column of the employee table references this column.';

COMMENT ON COLUMN hr.departments.location_id IS 'Location id where a department is located. Foreign key to location_id column of locations table.';

CREATE UNIQUE INDEX hr.dept_id_pkx ON hr.departments(department_id);

ALTER TABLE hr.departments ADD CONSTRAINT dept_id_pk PRIMARY KEY (department_id) USING INDEX hr.dept_id_pkx;

CREATE TABLE hr.jobs (
  job_id VARCHAR2(10 BYTE) NOT NULL,
  job_title VARCHAR2(35 BYTE) NOT NULL,
  min_salary NUMBER(6),
  max_salary NUMBER(6)
);

COMMENT ON COLUMN hr.jobs.job_id IS 'Primary key of jobs table.';

COMMENT ON COLUMN hr.jobs.job_title IS 'A not null column that shows job title, e.g. AD_VP, FI_ACCOUNTANT';

COMMENT ON COLUMN hr.jobs.min_salary IS 'Minimum salary for a job title.';

COMMENT ON COLUMN hr.jobs.max_salary IS 'Maximum salary for a job title';

CREATE UNIQUE INDEX hr.job_id_pkx ON hr.jobs(job_id);

ALTER TABLE hr.jobs ADD CONSTRAINT job_id_pk PRIMARY KEY (job_id) USING INDEX hr.job_id_pkx;

CREATE TABLE hr.employees (
  employee_id NUMBER(6) NOT NULL,
  first_name VARCHAR2(20 BYTE),
  last_name VARCHAR2(25 BYTE) NOT NULL,
  email VARCHAR2(25 BYTE) NOT NULL,
  phone_number VARCHAR2(20 BYTE),
  hire_date DATE NOT NULL,
  job_id VARCHAR2(10 BYTE) NOT NULL,
  salary NUMBER(8,2) CONSTRAINT emp_salary_min CHECK ( salary > 0),
  commission_pct NUMBER(2,2),
  manager_id NUMBER(6),
  department_id NUMBER(4),
  end_date DATE,
  CONSTRAINT emp_email_uk UNIQUE (email)
);

COMMENT ON COLUMN hr.employees.employee_id IS 'Primary key of employees table.';

COMMENT ON COLUMN hr.employees.first_name IS 'First name of the employee. A not null column.';

COMMENT ON COLUMN hr.employees.last_name IS 'Last name of the employee. A not null column.';

COMMENT ON COLUMN hr.employees.email IS 'Email id of the employee';

COMMENT ON COLUMN hr.employees.phone_number IS 'Phone number of the employee; includes country code and area code';

COMMENT ON COLUMN hr.employees.hire_date IS 'Date when the employee started on this job. A not null column.';

COMMENT ON COLUMN hr.employees.job_id IS 'Current job of the employee; foreign key to job_id column of the
jobs table. A not null column.';

COMMENT ON COLUMN hr.employees.salary IS 'Monthly salary of the employee. Must be greater
than zero (enforced by constraint emp_salary_min)';

COMMENT ON COLUMN hr.employees.commission_pct IS 'Commission percentage of the employee; Only employees in sales
department elgible for commission percentage';

COMMENT ON COLUMN hr.employees.manager_id IS 'Manager id of the employee; has same domain as manager_id in
departments table. Foreign key to employee_id column of employees table.
(useful for reflexive joins and CONNECT BY query)';

COMMENT ON COLUMN hr.employees.department_id IS 'Department id where employee works; foreign key to department_id
column of the departments table';

COMMENT ON COLUMN hr.employees.end_date IS 'Date when the employee left the company.  ';

CREATE UNIQUE INDEX hr.emp_emp_id_pkx ON hr.employees(employee_id);

ALTER TABLE hr.employees ADD CONSTRAINT emp_emp_id_pk PRIMARY KEY (employee_id) USING INDEX hr.emp_emp_id_pkx;

CREATE TABLE hr.job_history (
  employee_id NUMBER(6) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  job_id VARCHAR2(10 BYTE) NOT NULL,
  department_id NUMBER(4),
  CONSTRAINT jhist_date_check CHECK (end_date > start_date)
);

COMMENT ON COLUMN hr.job_history.employee_id IS 'A not null column in the complex primary key employee_id+start_date.
Foreign key to employee_id column of the employee table';

COMMENT ON COLUMN hr.job_history.start_date IS 'A not null column in the complex primary key employee_id+start_date.
Must be less than the end_date of the job_history table. (enforced by
constraint jhist_date_interval)';

COMMENT ON COLUMN hr.job_history.end_date IS 'Last day of the employee in this job role. A not null column. Must be
greater than the start_date of the job_history table.
(enforced by constraint jhist_date_interval)';

COMMENT ON COLUMN hr.job_history.job_id IS 'Job role in which the employee worked in the past; foreign key to
job_id column in the jobs table. A not null column.';

COMMENT ON COLUMN hr.job_history.department_id IS 'Department id in which the employee worked in the past; foreign key to deparment_id column in the departments table';

CREATE UNIQUE INDEX hr.jhist_id_date_pkx ON hr.job_history(employee_id,start_date);

ALTER TABLE hr.job_history ADD CONSTRAINT jhist_id_date_pk PRIMARY KEY (employee_id,start_date) USING INDEX hr.jhist_id_date_pkx;

CREATE TABLE hr.contacts (
  contact_id NUMBER(6) NOT NULL,
  first_name VARCHAR2(20 BYTE),
  last_name VARCHAR2(25 BYTE) NOT NULL,
  address1 VARCHAR2(30 BYTE),
  address2 VARCHAR2(30 BYTE),
  address3 VARCHAR2(30 BYTE),
  zipcode VARCHAR2(10 BYTE),
  email VARCHAR2(24 BYTE) NOT NULL,
  phone_number VARCHAR2(20 BYTE),
  twitter_id VARCHAR2(20 BYTE),
  linkedin_id VARCHAR2(20 BYTE),
  CONSTRAINT contacts_pk PRIMARY KEY (contact_id)
);

COMMENT ON COLUMN hr.contacts.contact_id IS 'Contact ID';

COMMENT ON COLUMN hr.contacts.first_name IS 'First name';

COMMENT ON COLUMN hr.contacts.last_name IS 'Last name';

CREATE INDEX hr.emp_name_ix ON hr.employees(last_name,first_name);

CREATE INDEX hr.jhist_dept_ix ON hr.job_history(department_id);

CREATE INDEX hr.jhist_emp_ix ON hr.job_history(employee_id);

CREATE INDEX hr.loc_state_prov_ix ON hr.locations(state_province);

CREATE INDEX hr.loc_city_ix ON hr.locations(city);

CREATE INDEX hr.emp_manager_ix ON hr.employees(manager_id);

CREATE INDEX hr.loc_country_ix ON hr.locations(country_id);

CREATE INDEX hr.emp_job_ix ON hr.employees(job_id);

CREATE INDEX hr.jhist_job_ix ON hr.job_history(job_id);

CREATE INDEX hr.dept_location_ix ON hr.departments(location_id);

CREATE INDEX hr.emp_department_ix ON hr.employees(department_id);

CREATE OR REPLACE function hr.betwnstr( a_string varchar2, a_start_pos integer, a_end_pos integer ) return varchar2
is
begin
  if a_start_pos = 0 then
    return substr( a_string, a_start_pos, a_end_pos - a_start_pos);
  else
    return substr( a_string, a_start_pos, a_end_pos - a_start_pos + 1);
  end if;
end;
/

CREATE OR REPLACE FUNCTION hr.DMORAND(seedVal IN  VARCHAR2) RETURN NUMBER IS BEGIN dbms_random.seed(seedVal); RETURN dbms_random.VALUE(); END;
/

CREATE OR REPLACE PROCEDURE hr.secure_dml
IS
BEGIN
  IF TO_CHAR (SYSDATE, 'HH24:MI') NOT BETWEEN '08:00' AND '18:00'
        OR TO_CHAR (SYSDATE, 'DY') IN ('SAT', 'SUN') THEN
	RAISE_APPLICATION_ERROR (-20205,
		'You may only make changes during normal office hours');
  END IF;
END secure_dml;
/

CREATE OR REPLACE PROCEDURE hr.GET_CONTACTS( p_rc OUT SYS_REFCURSOR )
AS
BEGIN
  OPEN p_rc FOR
  SELECT * FROM CONTACTS;
  -- SELECT FIRST_NAME, LAST_NAME, EMAIL FROM CONTACTS;
END;
/

CREATE OR REPLACE PROCEDURE hr.add_job_history
  (  p_emp_id          job_history.employee_id%type
   , p_start_date      job_history.start_date%type
   , p_end_date        job_history.end_date%type
   , p_job_id          job_history.job_id%type
   , p_department_id   job_history.department_id%type
   )
IS
BEGIN
  INSERT INTO job_history (employee_id, start_date, end_date,
                           job_id, department_id)
    VALUES(p_emp_id, p_start_date, p_end_date, p_job_id, p_department_id);
END add_job_history;
/

CREATE OR REPLACE TYPE hr.DMO_RIDTYPE AS OBJECT (rid VARCHAR2(100))
/

CREATE OR REPLACE TYPE hr.DMO_RIDTYPE_TAB IS TABLE OF DMO_RIDTYPE
/

CREATE OR REPLACE package hr.bl_user_registration as
    function validate_password_strength(in_password in varchar2)
    return boolean;
end bl_user_registration;
/

CREATE OR REPLACE package hr.test_betwnstr as
  
  -- %suite(Between string function)
  
  -- %test(Returns substring from start position to end position)
  procedure basic_usage;
  
  -- %test(Returns substring when start position is zero)
--   procedure zero_start_position;
  
  -- %test(More between function)
  procedure ut_betwn;
  
end;
/

CREATE OR REPLACE package hr.test_bl_user_registration as
   
 -- %suite(Password tests)
   
  -- %test(validates strong passwords)
  procedure validate_strong_passwords;
  -- %test(validates missing characters)
  procedure validate_missing_characters;
  -- %test(validates boundary cases)
  procedure validate_boundaries;
    
   
 -- source: https://apexplained.wordpress.com/2013/07/14/introducing-unit-tests-in-plsql-with-utplsql/
end test_bl_user_registration;
/

CREATE OR REPLACE package body hr.bl_user_registration as
 
   -- A valid password needs an uppercase and lowercase character, a digit and to be between 4 and 20 characters long
 
   -- Example tests from https://apexplained.wordpress.com/2013/07/14/introducing-unit-tests-in-plsql-with-utplsql/
 
  function validate_password_strength(in_password in varchar2)
  return boolean is
  begin
    if not regexp_like(in_password, '[[:digit:]]') then
      return false;
    end if;
   
    if not regexp_like(in_password, '[[:lower:]]') then
      return false;
    end if;
   
    if not regexp_like(in_password, '[[:upper:]]') then
      return false;
    end if;
   
    if not regexp_like(in_password, '[@#$%]') then
      return false;
    end if;
 
    if length(in_password) is null or length(in_password)
    not between 4 and 20 then
      return false;
    end if;
 
   
    return true;
  end validate_password_strength;
   
end bl_user_registration;
/

CREATE OR REPLACE package body hr.test_betwnstr as
  
  procedure basic_usage is
  begin
    ut.expect( betwnstr( '1234567', 2, 5 ) ).to_equal('2345');
  end;
  
  procedure zero_start_position is
  begin
    ut.expect( betwnstr( '1234567', 0, 5 ) ).to_equal('12345');
  end;
    
   PROCEDURE ut_betwn IS
   BEGIN
    ut.expect(betwnstr ('this is a string', 3, 7), 'Typical Valid Usage').to_equal('is is');
    ut.expect(betwnstr ('this is a string', -3, 7), 'Test Negative Start').to_equal('ing');
    ut.expect(betwnstr ('this is a string', 3, 1), 'Start Bigger than End').to_be_null();
   END;
end;
/

CREATE OR REPLACE package body hr.test_bl_user_registration as
 
       procedure validate_strong_passwords as
    begin
        ut.expect(bl_user_registration.validate_password_strength('ABCdef123#'), 'ABCdef123# is a strong password').to_(equal(true));
        ut.expect(bl_user_registration.validate_password_strength('%abc1B2CD'), '%abc1B2CD is a strong password').to_(equal(true));
        ut.expect(bl_user_registration.validate_password_strength('%abc1B2CD'), '%abc1B2CD is a stronger password').to_(equal(true));
    end validate_strong_passwords;
 
 
    procedure validate_missing_characters as
    begin
        ut.expect(bl_user_registration.validate_password_strength('Abcdefg#'), 'Abcdefg# misses a digit character').to_(equal(false));
        ut.expect(bl_user_registration.validate_password_strength('ABCD1234$'), 'ABCD1234$ misses a lowercase character').to_(equal(false));
        ut.expect(bl_user_registration.validate_password_strength('abcd1234@'), 'abcd1234@ misses an uppercase character').to_(equal(false));
        ut.expect(bl_user_registration.validate_password_strength('ABcd1234'), 'ABcd1234 misses a special character').to_(equal(false));
    end validate_missing_characters;
 
 
    procedure validate_boundaries as
    begin
        ut.expect(bl_user_registration.validate_password_strength('Ab1%'), 'Password is the minimum valid length').to_(equal(true));
        ut.expect(bl_user_registration.validate_password_strength('A1%'), 'Password is too short').to_(equal(false));
        ut.expect(bl_user_registration.validate_password_strength('Abcdefghijk12345678@'), 'Password is the maximum valid length').to_(equal(true));
        ut.expect(bl_user_registration.validate_password_strength('Abcdefghijk123456789@'), 'Password is too long').to_(equal(false));
        ut.expect(bl_user_registration.validate_password_strength(''), 'An empty string should return false').to_(equal(false));
 
    end validate_boundaries;
 
  
  
end test_bl_user_registration;
/

CREATE OR REPLACE FORCE VIEW hr.emp_details_view (employee_id,job_id,manager_id,department_id,location_id,country_id,first_name,last_name,salary,commission_pct,department_name,job_title,city,state_province,country_name) AS
SELECT
  e.employee_id,
  e.job_id,
  e.manager_id,
  e.department_id,
  d.location_id,
  l.country_id,
  e.first_name,
  e.last_name,
  e.salary,
  e.commission_pct,
  d.department_name,
  j.job_title,
  l.city,
  l.state_province,
  c.country_name
FROM
  employees e,
  departments d,
  jobs j,
  locations l,
  countries c,
  regions r
WHERE e.department_id = d.department_id
  AND d.location_id = l.location_id
  AND l.country_id = c.country_id
  AND c.region_id = r.region_id
  AND j.job_id = e.job_id WITH READ ONLY;

CREATE OR REPLACE TRIGGER hr.UPDATE_JOB_HISTORY 
    AFTER UPDATE OF JOB_ID, DEPARTMENT_ID ON hr.EMPLOYEES 
    FOR EACH ROW 
BEGIN
  add_job_history(:old.employee_id, :old.hire_date, sysdate,
                  :old.job_id, :old.department_id);
END;
/

ALTER TABLE hr.job_history ADD CONSTRAINT jhist_dept_fk FOREIGN KEY (department_id) REFERENCES hr.departments (department_id);

ALTER TABLE hr.job_history ADD CONSTRAINT jhist_emp_fk FOREIGN KEY (employee_id) REFERENCES hr.employees (employee_id);

ALTER TABLE hr.job_history ADD CONSTRAINT jhist_job_fk FOREIGN KEY (job_id) REFERENCES hr.jobs (job_id);

ALTER TABLE hr.departments ADD CONSTRAINT dept_loc_fk FOREIGN KEY (location_id) REFERENCES hr.locations (location_id);

ALTER TABLE hr.departments ADD CONSTRAINT dept_mgr_fk FOREIGN KEY (manager_id) REFERENCES hr.employees (employee_id);

ALTER TABLE hr.countries ADD CONSTRAINT countr_reg_fk FOREIGN KEY (region_id) REFERENCES hr.regions (region_id);

ALTER TABLE hr.locations ADD CONSTRAINT loc_c_id_fk FOREIGN KEY (country_id) REFERENCES hr.countries (country_id);

ALTER TABLE hr.employees ADD CONSTRAINT emp_dept_fk FOREIGN KEY (department_id) REFERENCES hr.departments (department_id);

ALTER TABLE hr.employees ADD CONSTRAINT emp_job_fk FOREIGN KEY (job_id) REFERENCES hr.jobs (job_id);

ALTER TABLE hr.employees ADD CONSTRAINT emp_manager_fk FOREIGN KEY (manager_id) REFERENCES hr.employees (employee_id);

