-- ############################################################
-- 01_schema.sql
-- Cria o banco olist e as 6 tabelas do projeto, com PK e FK.
-- ############################################################


-- ============================================================
-- 1. Banco de dados
-- utf8mb4 → dado brasileiro tem acento e as reviews têm emoji
-- ============================================================
CREATE DATABASE IF NOT EXISTS olist
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE olist;


-- ============================================================
-- 2. Limpeza
-- Permite rodar o arquivo de novo a partir do zero.
-- Apaga os dados → rodar o 02 depois
-- ============================================================
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS product_category_name_translation;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;


-- ============================================================
-- 3. Tabelas
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 customers
-- customer_id muda a cada pedido.
-- customer_unique_id identifica a pessoa → contar clientes
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR(32),
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix CHAR(5),
    customer_city VARCHAR(50),
    customer_state CHAR(2),
    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);


-- ------------------------------------------------------------
-- 3.2 products
-- "lenght" é erro de grafia do dataset original → mantido para bater com o CSV.
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id VARCHAR(32),
    product_category_name VARCHAR(50),
    product_name_lenght SMALLINT UNSIGNED,
    product_description_lenght SMALLINT UNSIGNED,
    product_photos_qty SMALLINT UNSIGNED,
    product_weight_g MEDIUMINT UNSIGNED,
    product_length_cm SMALLINT UNSIGNED,
    product_height_cm SMALLINT UNSIGNED,
    product_width_cm SMALLINT UNSIGNED,
    CONSTRAINT pk_products PRIMARY KEY (product_id)
);


-- ------------------------------------------------------------
-- 3.3 product_category_name_translation
-- Não há FK de products para esta tabela.
-- Se houvesse, a carga recusaria os 13 produtos cuja categoria
-- não tem tradução (ver Q02 no 03_qualidade.sql).
-- ------------------------------------------------------------
CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(50),
    product_category_name_english VARCHAR(50),
    CONSTRAINT pk_product_category_name_translation PRIMARY KEY (product_category_name)
);


-- ------------------------------------------------------------
-- 3.4 orders
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id VARCHAR(32),
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- ------------------------------------------------------------
-- 3.5 order_items
-- PK composta: nenhuma coluna sozinha é única; o par
-- (order_id, order_item_id) é.
-- ------------------------------------------------------------
CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id TINYINT UNSIGNED,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    CONSTRAINT pk_order_item_id PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_order_items_order_id FOREIGN KEY (order_id)
        REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product_id FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);


-- ------------------------------------------------------------
-- 3.6 order_reviews
-- Sem PK: review_id não é único no dataset
-- (789 review_id repetidos, ver Q03 no 03_qualidade.sql).
-- ------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id VARCHAR(32),
    order_id VARCHAR(32) NOT NULL,
    review_score TINYINT UNSIGNED NOT NULL,
    review_comment_title TEXT,
    review_comment_message MEDIUMTEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    CONSTRAINT fk_order_reviews_order_id FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);
