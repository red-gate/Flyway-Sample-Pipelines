CREATE TABLE products
(
  product_id    NUMBER PRIMARY KEY,
  product_name  VARCHAR2( 255 ) NOT NULL,
  description   VARCHAR2( 2000 ),
  standard_cost NUMBER( 9, 2 ),
  list_price    NUMBER( 9, 2 ),
  category_id   NUMBER NOT NULL
);

