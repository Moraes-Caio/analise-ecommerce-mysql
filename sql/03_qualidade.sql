USE olist;


/* 
Verificando valores nulos

customers
- customer_unique_id
- customer_zip_code_prefix
- customer_city
- customer_state

products
- product_category_name
- product_weight_g
- product_length_cm
- product_height_cm
- product_width_cm

product_category_name_translation
- product_category_name_english

orders
- customer_id 
- order_status
- order_purchase_timestamp
- order_estimated_delivery_date

order_items
- product_id 
- seller_id
- shipping_limit_date
- price
- freight_value

order_reviews
- order_id 
- review_score
- review_creation_date

OBS: Nao precisa verificar PK's
*/


-- Verificando valores nulos em customer
SELECT COUNT(*) FROM customers WHERE customer_unique_id IS NULL; -- 0 NULL
SELECT COUNT(*) FROM customers WHERE customer_zip_code_prefix IS NULL; -- 0 NULL
SELECT COUNT(*) FROM customers WHERE customer_city IS NULL; -- 0 NULL
SELECT COUNT(*) FROM customers WHERE customer_state IS NULL; -- 0 NULL


-- Verificando valores nulos em products
SELECT COUNT(*) FROM products WHERE product_category_name IS NULL; -- 0 NULL
SELECT COUNT(*) FROM products WHERE product_weight_g IS NULL; -- 2 NULL
SELECT COUNT(*) FROM products WHERE product_length_cm IS NULL; -- 2 NULL
SELECT COUNT(*) FROM products WHERE product_height_cm IS NULL; -- 2 NULL
SELECT COUNT(*) FROM products WHERE product_width_cm IS NULL; -- 2 NULL


-- Verificando valores nulos em product_category_name_translation
SELECT COUNT(*) FROM product_category_name_translation WHERE product_category_name IS NULL; -- 0 NULL


-- Verificando valores nulos em orders
SELECT COUNT(*) FROM orders WHERE customer_id IS NULL; -- 0 NULL
SELECT COUNT(*) FROM orders WHERE order_status IS NULL; -- 0 NULL
SELECT COUNT(*) FROM orders WHERE order_purchase_timestamp IS NULL; -- 0 NULL
SELECT COUNT(*) FROM orders WHERE order_estimated_delivery_date IS NULL; -- 0 NULL


-- Verificando valores nulos em order_items
SELECT COUNT(*) FROM order_items WHERE product_id IS NULL; -- 0 NULL
SELECT COUNT(*) FROM order_items WHERE seller_id IS NULL; -- 0 NULL
SELECT COUNT(*) FROM order_items WHERE shipping_limit_date IS NULL; -- 0 NULL
SELECT COUNT(*) FROM order_items WHERE price IS NULL; -- 0 NULL
SELECT COUNT(*) FROM order_items WHERE freight_value IS NULL; -- 0 NULL


-- Verificando valores nulos em order_reviews
SELECT COUNT(*) FROM order_reviews WHERE order_id IS NULL;  -- 0 NULL
SELECT COUNT(*) FROM order_reviews WHERE review_score IS NULL;  -- 0 NULL
SELECT COUNT(*) FROM order_reviews WHERE review_creation_date IS NULL;  -- 0 NULL


/*
Verificando pedidos orfaos

orders.customer_id -> customers.customer_id
order_items.order_id -> orders.order_id
order_items.product_id -> products.product_id
order_reviews.order_id -> orders.order_id
products.product_category_name -> product_catetgory_name_translation.product_category_name
*/


-- Verificando pedidos orfaos de orders.customer_id
SELECT o.customer_id, c.customer_id
FROM orders AS o 
LEFT JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL; -- 0 NULL


-- Verificando pedidos orfaos de order_items.order_id
SELECT oi.order_id, o.order_id
FROM order_items AS oi
LEFT JOIN orders AS o
ON oi.order_id = o.order_id
WHERE o.order_id IS NULL; -- 0 NULL


-- Verificando pedidos orfaos de order_items.product_id
SELECT oi.product_id, p.product_id
FROM order_items AS oi
LEFT JOIN products AS p
ON oi.product_id = p.product_id
WHERE p.product_id IS NULL; -- 0 NULL


-- Verificando pedidos orfaos de order_reviews.order_id
SELECT orr.order_id, o.order_id
FROM order_reviews AS orr
LEFT JOIN orders AS o
ON orr.order_id = o.order_id
WHERE o.order_id IS NULL; -- 0 NULL


-- Verificando pedidos orfaos de products.product_category_name 
SELECT p.product_category_name, pt.product_category_name
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL;

SELECT COUNT(*)
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL; -- 623 NULL;

-- Verificando categorias orfas existentes em products.product_category_name
SELECT DISTINCT p.product_category_name
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;

SELECT COUNT(DISTINCT p.product_category_name)
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL
	AND p.product_category_name IS NOT NULL; -- 3 categorias orfas
    