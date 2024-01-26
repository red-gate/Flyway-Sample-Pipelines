CREATE TABLE locations
(
  location_id NUMBER PRIMARY KEY,
  address     VARCHAR2( 255 ) NOT NULL,
  postal_code VARCHAR2( 20 ),
  city        VARCHAR2( 50 ),
  state       VARCHAR2( 50 ),
  country_id  CHAR(2)
);

