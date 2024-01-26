CREATE TABLE order_items
(
    order_id   NUMBER( 12, 0 ),
    item_id    NUMBER( 12, 0 ),
    product_id NUMBER( 12, 0 ) NOT NULL,
    quantity   NUMBER( 8, 2 ) NOT NULL,
    unit_price NUMBER( 8, 2 ) NOT NULL

);