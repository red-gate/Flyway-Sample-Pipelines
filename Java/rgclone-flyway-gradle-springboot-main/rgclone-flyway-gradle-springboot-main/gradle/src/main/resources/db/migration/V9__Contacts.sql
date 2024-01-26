CREATE TABLE contacts
(
  contact_id  NUMBER PRIMARY KEY,
  first_name  VARCHAR2( 255 ) NOT NULL,
  last_name   VARCHAR2( 255 ) NOT NULL,
  email       VARCHAR2( 255 ) NOT NULL,
  phone       VARCHAR2( 20 ),
  customer_id NUMBER
);

