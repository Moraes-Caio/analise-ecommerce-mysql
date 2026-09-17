-- ############################################################
-- 03_qualidade.sql
-- 4 checagens de qualidade antes das análises:
--   Q01 → valores nulos
--   Q02 → registros órfãos (filho sem pai)
--   Q03 → review_id duplicado
--   Q04 → datas fora da ordem cronológica
-- ############################################################

USE olist;

-- ############################################################
-- Q01 · VALORES NULOS
--
-- Colunas usadas em análise ou FK. PK fora → não aceita NULL.
-- ############################################################

-- Q01a · customers
SELECT COUNT(*) FROM customers WHERE customer_unique_id IS NULL;        -- 0
SELECT COUNT(*) FROM customers WHERE customer_zip_code_prefix IS NULL;  -- 0
SELECT COUNT(*) FROM customers WHERE customer_city IS NULL;             -- 0
SELECT COUNT(*) FROM customers WHERE customer_state IS NULL;            -- 0

-- Q01b · products
SELECT COUNT(*) FROM products WHERE product_category_name IS NULL;  -- 610
SELECT COUNT(*) FROM products WHERE product_weight_g IS NULL;       -- 2
SELECT COUNT(*) FROM products WHERE product_length_cm IS NULL;      -- 2
SELECT COUNT(*) FROM products WHERE product_height_cm IS NULL;      -- 2
SELECT COUNT(*) FROM products WHERE product_width_cm IS NULL;       -- 2

-- Q01c · product_category_name_translation
SELECT COUNT(*) FROM product_category_name_translation WHERE product_category_name_english IS NULL;  -- 0

-- Q01d · orders
SELECT COUNT(*) FROM orders WHERE customer_id IS NULL;                    -- 0
SELECT COUNT(*) FROM orders WHERE order_status IS NULL;                   -- 0
SELECT COUNT(*) FROM orders WHERE order_purchase_timestamp IS NULL;       -- 0
SELECT COUNT(*) FROM orders WHERE order_estimated_delivery_date IS NULL;  -- 0

-- Q01e · order_items
SELECT COUNT(*) FROM order_items WHERE product_id IS NULL;           -- 0
SELECT COUNT(*) FROM order_items WHERE seller_id IS NULL;            -- 0
SELECT COUNT(*) FROM order_items WHERE shipping_limit_date IS NULL;  -- 0
SELECT COUNT(*) FROM order_items WHERE price IS NULL;                -- 0
SELECT COUNT(*) FROM order_items WHERE freight_value IS NULL;        -- 0

-- Q01f · order_reviews
SELECT COUNT(*) FROM order_reviews WHERE order_id IS NULL;              -- 0
SELECT COUNT(*) FROM order_reviews WHERE review_score IS NULL;          -- 0
SELECT COUNT(*) FROM order_reviews WHERE review_creation_date IS NULL;  -- 0

-- Q01g · Texto vazio ('') em colunas carregadas sem NULLIF
SELECT COUNT(*) FROM customers WHERE customer_unique_id = '';        -- 0
SELECT COUNT(*) FROM customers WHERE customer_zip_code_prefix = '';  -- 0
SELECT COUNT(*) FROM order_items WHERE seller_id = '';               -- 0
SELECT COUNT(*) FROM order_reviews WHERE review_id = '';             -- 0

-- Q01h · Data zero ou número zero em colunas carregadas sem NULLIF
-- Vazio nessas colunas vira 0000-00-00 ou 0 (só warning).
SELECT MIN(order_purchase_timestamp) FROM orders;         -- 2016-09-04 21:15:19
SELECT MIN(order_estimated_delivery_date) FROM orders;    -- 2016-09-30 00:00:00
SELECT MIN(shipping_limit_date) FROM order_items;         -- 2016-09-19 00:15:34
SELECT MIN(price) FROM order_items;                       -- 0.85
SELECT MIN(freight_value) FROM order_items;               -- 0.00
SELECT MIN(review_score) FROM order_reviews;              -- 1
SELECT MIN(review_creation_date) FROM order_reviews;      -- 2016-10-02 00:00:00
SELECT MIN(review_answer_timestamp) FROM order_reviews;   -- 2016-10-07 18:32:28

-- Q01i · Itens com frete zero
SELECT COUNT(*) FROM order_items WHERE freight_value = 0;  -- 383 · conferido no CSV → zero real, não campo vazio

-- ############################################################
-- Q02 · REGISTROS ÓRFÃOS
--
-- Órfão = linha filha cuja chave não existe na tabela pai.
-- ############################################################

-- Q02a · orders.customer_id → customers
SELECT o.customer_id, c.customer_id
FROM orders AS o
LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;  -- 0 linhas 


-- Q02b · order_items.order_id → orders
SELECT oi.order_id, o.order_id
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;  -- 0 linhas 


-- Q02c · order_items.product_id → products
SELECT oi.product_id, p.product_id
FROM order_items AS oi
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;  -- 0 linhas 


-- Q02d · order_reviews.order_id → orders
SELECT orr.order_id, o.order_id
FROM order_reviews AS orr
LEFT JOIN orders AS o
    ON orr.order_id = o.order_id
WHERE o.order_id IS NULL;  -- 0 linhas 


-- ------------------------------------------------------------
-- products.product_category_name → translation
-- ------------------------------------------------------------

-- Q02e · Total de produtos sem tradução
SELECT COUNT(*)
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
    ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL;  -- 623


-- Q02f · Lista dos 623, para inspeção
SELECT p.product_category_name, pt.product_category_name
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
    ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL;


-- Q02g · Categorias preenchidas que não têm tradução
SELECT COUNT(DISTINCT p.product_category_name)
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
    ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL
    AND p.product_category_name IS NOT NULL;  -- 2 categorias

SELECT DISTINCT p.product_category_name
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
    ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL
    AND p.product_category_name IS NOT NULL;  -- pc_gamer, portateis_cozinha_e_preparadores_de_alimentos


-- Q02h · Produtos em cada categoria sem tradução
SELECT product_category_name, COUNT(*) AS qty
FROM products
WHERE product_category_name IN ('pc_gamer', 'portateis_cozinha_e_preparadores_de_alimentos')
GROUP BY product_category_name;  -- pc_gamer: 3 | portateis_cozinha_e_preparadores_de_alimentos: 10 → total 13


-- ############################################################
-- Q03 · REVIEW_ID DUPLICADO
--
-- Motivo: a documentação não garante que review_id é único.
-- Se não for, order_reviews não pode ter PK em review_id.
-- ############################################################

-- Q03a · Lista dos review_id repetidos e quantas vezes cada um aparece
SELECT review_id, COUNT(*) AS qty
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;


-- Q03b · Quantos review_id se repetem
SELECT COUNT(*) FROM (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1)
AS qty_tot;  -- 789 review_id repetidos


-- Q03c · Quantas linhas pertencem a review_id repetidos
SELECT SUM(qty) FROM (
    SELECT review_id, COUNT(*) AS qty
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1)
AS qty_tot_sum;  -- 1603 linhas em 789 grupos → 814 cópias excedentes


-- ############################################################
-- Q04 · DATAS FORA DA ORDEM CRONOLÓGICA
--
-- Ordem esperada na tabela orders:
-- 1. Cliente compra               → order_purchase_timestamp
-- 2. Pagamento aprovado           → order_approved_at
-- 3. Pedido sai para transportadora → order_delivered_carrier_date
-- 4. Pedido chega ao cliente      → order_delivered_customer_date
--
-- Inconsistência = data de uma etapa MAIOR que a de uma etapa posterior.
-- ############################################################

-- Q04a · Pedidos com pelo menos uma das 4 datas nula
SELECT COUNT(*) FROM orders
WHERE order_purchase_timestamp IS NULL
    OR order_approved_at IS NULL
    OR order_delivered_carrier_date IS NULL
    OR order_delivered_customer_date IS NULL;  -- 2980


-- Q04b · Compra depois de alguma etapa seguinte
SELECT COUNT(*) FROM orders
WHERE order_purchase_timestamp > order_approved_at
    OR order_purchase_timestamp > order_delivered_carrier_date
    OR order_purchase_timestamp > order_delivered_customer_date;  -- 166

-- Q04c · Aprovação depois de alguma etapa seguinte
SELECT COUNT(*) FROM orders
WHERE order_approved_at > order_delivered_carrier_date
    OR order_approved_at > order_delivered_customer_date;  -- 1359

-- Q04d · Saída para transportadora depois da entrega
SELECT COUNT(*) FROM orders
WHERE order_delivered_carrier_date > order_delivered_customer_date;  -- 23


-- Q04e · Total de pedidos com pelo menos uma inversão
SELECT COUNT(*) FROM orders
WHERE order_purchase_timestamp > order_approved_at
    OR order_purchase_timestamp > order_delivered_carrier_date
    OR order_purchase_timestamp > order_delivered_customer_date
    OR order_approved_at > order_delivered_carrier_date
    OR order_approved_at > order_delivered_customer_date
    OR order_delivered_carrier_date > order_delivered_customer_date;  -- 1382

-- 1548 > 1382 → pedido com 2+ inversões conta 1× aqui

-- Q04f · Pedidos com inversão que têm pelo menos uma data nula
SELECT COUNT(*) FROM orders
WHERE (
    order_purchase_timestamp > order_approved_at
    OR order_purchase_timestamp > order_delivered_carrier_date
    OR order_purchase_timestamp > order_delivered_customer_date
    OR order_approved_at > order_delivered_carrier_date
    OR order_approved_at > order_delivered_customer_date
    OR order_delivered_carrier_date > order_delivered_customer_date
)
AND (
    order_purchase_timestamp IS NULL
    OR order_approved_at IS NULL
    OR order_delivered_carrier_date IS NULL
    OR order_delivered_customer_date IS NULL
); -- 9
