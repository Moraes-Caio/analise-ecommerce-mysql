-- Verificando e Ativando local_infile
SHOW GLOBAL VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';


-- Upload de olist_customers_dataset.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- Unix (LF)
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, 
customer_city, customer_state);


-- Upload de olist_products_dataset.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- Unix (LF)
IGNORE 1 ROWS
(product_id, product_category_name, @product_name_lenght, 
@product_description_lenght, @product_photos_qty, @product_weight_g, 
@product_length_cm, @product_height_cm, @product_width_cm)
SET
  product_name_lenght = NULLIF(@product_name_lenght, ''),
  product_description_lenght = NULLIF(@product_description_lenght, ''),
  product_photos_qty = NULLIF(@product_photos_qty, ''),
  product_weight_g = NULLIF(@product_weight_g, ''),
  product_length_cm = NULLIF(@product_length_cm, ''),
  product_height_cm = NULLIF(@product_height_cm, ''),
  product_width_cm = NULLIF(@product_width_cm, '');
  

-- Upload de olist_product_category_name_translation.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' -- Windows (CRLF)
IGNORE 1 ROWS
(product_category_name, product_category_name_english);


-- Upload de olist_orders_dataset.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- Unix (LF)
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp, 
@order_approved_at, @order_delivered_carrier_date, 
@order_delivered_customer_date, order_estimated_delivery_date)
SET
	order_approved_at = NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date = NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@order_delivered_customer_date, '');


-- Upload de olist_order_items_dataset.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- Unix (LF)
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, 
shipping_limit_date, price, freight_value);


-- Upload de olist_order_reviews_dataset.csv
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' -- Windows (CRLF)
IGNORE 1 ROWS
(review_id, order_id, review_score, @review_comment_title, 
@review_comment_message, review_creation_date, 
review_answer_timestamp)
SET
	review_comment_title = NULLIF(@review_comment_title, ''),
    review_comment_message = NULLIF(@review_comment_message, '');


-- Certificando quantidade de linhas
SELECT COUNT(*) FROM customers; -- CONFIRMADO
SELECT COUNT(*) FROM products; -- CONFIRMADO
SELECT COUNT(*) FROM product_category_name_translation; -- CONFIRMADO
SELECT COUNT(*) FROM orders; -- CONFIRMADO
SELECT COUNT(*) FROM order_items; -- CONFIRMADO
SELECT COUNT(*) FROM order_reviews; -- CONFIRMADO

-- Visualizando as tabelas
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM product_category_name_translation;
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT * FROM order_reviews;