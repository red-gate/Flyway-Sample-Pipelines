CREATE TABLE customers
(
    customer_id  NUMBER PRIMARY KEY,
    name         VARCHAR2( 255 ) NOT NULL,
    address      VARCHAR2( 255 ),
    website      VARCHAR2( 255 ),
    credit_limit NUMBER( 8, 2 )
);

