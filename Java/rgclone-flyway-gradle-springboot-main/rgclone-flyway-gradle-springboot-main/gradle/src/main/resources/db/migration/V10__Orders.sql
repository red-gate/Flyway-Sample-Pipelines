CREATE TABLE orders
(
  order_id    NUMBER PRIMARY KEY,
  customer_id NUMBER( 6, 0 ) NOT NULL,
  status      VARCHAR(20) NOT NULL,
  salesman_id NUMBER( 6, 0 ),
  order_date  DATE        NOT NULL
);

