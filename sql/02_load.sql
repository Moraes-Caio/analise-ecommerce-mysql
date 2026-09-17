-- ############################################################
-- 02_load.sql
-- Carrega os 6 CSVs do Olist nas tabelas do 01_schema.sql.
--
-- Ordem de carga: pais antes dos filhos → a FK recusa uma
-- linha filha cujo pai ainda não foi carregado.
-- ############################################################

USE olist;

-- ============================================================
-- 1. Ativar local_infile no servidor
-- ============================================================
SHOW GLOBAL VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';


-- ============================================================
-- 2. Cargas
--
-- Lista de colunas = ordem do CSV (casa por posição)
-- Terminador: \n em 4 CSVs, \r\n em 2 → errado = carga torta
-- Coluna que pode vir vazia → @var + NULLIF (vazio não vira NULL sozinho)
-- ============================================================


-- ------------------------------------------------------------
-- 2.1 customers ← olist_customers_dataset.csv
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'  -- LF
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix,
@customer_city, @customer_state)
SET
    customer_city = NULLIF(@customer_city, ''),
    customer_state = NULLIF(@customer_state, '');


-- ------------------------------------------------------------
-- 2.2 products ← olist_products_dataset.csv
-- Todas as colunas, exceto a PK, passam por NULLIF.
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'  -- LF
IGNORE 1 ROWS
(product_id, @product_category_name, @product_name_lenght,
@product_description_lenght, @product_photos_qty, @product_weight_g,
@product_length_cm, @product_height_cm, @product_width_cm)
SET
    product_category_name = NULLIF(@product_category_name, ''),
    product_name_lenght = NULLIF(@product_name_lenght, ''),
    product_description_lenght = NULLIF(@product_description_lenght, ''),
    product_photos_qty = NULLIF(@product_photos_qty, ''),
    product_weight_g = NULLIF(@product_weight_g, ''),
    product_length_cm = NULLIF(@product_length_cm, ''),
    product_height_cm = NULLIF(@product_height_cm, ''),
    product_width_cm = NULLIF(@product_width_cm, '');


-- ------------------------------------------------------------
-- 2.3 product_category_name_translation ← product_category_name_translation.csv
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'  -- CRLF
IGNORE 1 ROWS
(product_category_name, @product_category_name_english)
SET
    product_category_name_english = NULLIF(@product_category_name_english, '');


-- ------------------------------------------------------------
-- 2.4 orders ← olist_orders_dataset.csv
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'  -- LF
IGNORE 1 ROWS
(order_id, customer_id, @order_status, order_purchase_timestamp,
@order_approved_at, @order_delivered_carrier_date,
@order_delivered_customer_date, order_estimated_delivery_date)
SET
    order_status = NULLIF(@order_status, ''),
    order_approved_at = NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date = NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@order_delivered_customer_date, '');


-- ------------------------------------------------------------
-- 2.5 order_items ← olist_order_items_dataset.csv
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'  -- LF
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id,
shipping_limit_date, price, freight_value);


-- ------------------------------------------------------------
-- 2.6 order_reviews ← olist_order_reviews_dataset.csv
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/cdm24/codigo/olist_sql/olist/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'  -- CRLF
IGNORE 1 ROWS
(review_id, order_id, review_score, @review_comment_title,
@review_comment_message, review_creation_date,
review_answer_timestamp)
SET
    review_comment_title = NULLIF(@review_comment_title, ''),
    review_comment_message = NULLIF(@review_comment_message, '');


-- ============================================================
-- L01 · Contagem de linhas por tabela
-- Cada contagem conferida contra o número de linhas do CSV
-- ============================================================
SELECT COUNT(*) FROM customers;                          -- 99441 linhas
SELECT COUNT(*) FROM products;                           -- 32951 linhas
SELECT COUNT(*) FROM product_category_name_translation;  -- 71 linhas
SELECT COUNT(*) FROM orders;                             -- 99441 linhas
SELECT COUNT(*) FROM order_items;                        -- 112650 linhas
SELECT COUNT(*) FROM order_reviews;                      -- 99224 linhas


-- ============================================================
-- L02 · Inspeção visual pós-carga
-- ============================================================
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM product_category_name_translation;
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT * FROM order_reviews;
