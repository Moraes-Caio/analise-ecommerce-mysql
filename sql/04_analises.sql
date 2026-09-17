-- ############################################################
-- 04_analises.sql
-- 6 perguntas de negócio sobre o dataset Olist.
--
-- Resultado completo e leitura: docs/achados.md (mesmo ID).
-- ############################################################

USE olist; 

SET lc_time_names = 'pt_BR';

/*
============================================================
DEFINIÇÕES DE RECEITA (valem para o arquivo inteiro)
Todas somam price + freight_value.

Receita bruta → os 8 status
    delivered, unavailable, shipped, canceled,
    invoiced, processing, approved, created

Receita líquida prevista → exclui canceled e unavailable
    delivered, shipped, invoiced, processing, approved, created
    (assume que os pedidos pendentes serão concluídos)

Receita líquida → só delivered

Ticket médio → receita líquida ÷ pedidos distintos com delivered
============================================================
*/


-- ############################################################
-- PERGUNTA 1 — Como a receita evoluiu mês a mês?
-- ############################################################

-- A01 · Final · Receita bruta mensal
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%M %Y') AS mes,
    SUM(oi.price + oi.freight_value) AS receita_bruta
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), mes
ORDER BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m');


-- A02 · Final · Receita líquida prevista mensal
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%M %Y') AS mes,
    SUM(oi.price + oi.freight_value) AS receita_liquida_prevista
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status <> 'unavailable'
    AND o.order_status <> 'canceled'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), mes
ORDER BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m');


-- A03 · Final · Receita líquida mensal
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%M %Y') AS mes,
    SUM(oi.price + oi.freight_value) AS receita_liquida
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), mes
ORDER BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m');


-- ============================================================
-- Auxiliares de diagnóstico · Black Friday
-- ============================================================

-- A04 · Auxiliar · Receita diária, novembro/2017
SELECT
    DATE(o.order_purchase_timestamp) AS dia,
    DAYNAME(o.order_purchase_timestamp) AS dia_semana,
    SUM(oi.price + oi.freight_value) AS receita_bruta,
    COUNT(DISTINCT o.order_id) AS pedidos
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp >= '2017-11-01'
    AND o.order_purchase_timestamp < '2017-12-01'
GROUP BY dia, dia_semana
ORDER BY dia;


-- A05 · Auxiliar · Receita diária, outubro/2017
SELECT
    DATE(o.order_purchase_timestamp) AS dia,
    DAYNAME(o.order_purchase_timestamp) AS dia_semana,
    SUM(oi.price + oi.freight_value) AS receita_bruta,
    COUNT(DISTINCT o.order_id) AS pedidos
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp >= '2017-10-01'
    AND o.order_purchase_timestamp < '2017-11-01'
GROUP BY dia, dia_semana
ORDER BY dia;


-- A06 · Auxiliar · unavailable por aprovação de pagamento
SELECT
    o.order_approved_at IS NULL AS sem_pagamento,
    COUNT(*) AS total
FROM orders o
WHERE o.order_status = 'unavailable'
GROUP BY sem_pagamento;  -- sem_pagamento 0 · total 609


-- A07 · Auxiliar · Pedidos em status intermediário por mês de compra
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS mes_compra,
    COUNT(*) AS pedidos_intermediarios
FROM orders o
WHERE o.order_status NOT IN ('delivered', 'canceled', 'unavailable')
GROUP BY mes_compra
ORDER BY mes_compra;  -- 23 meses, soma = 1729


-- A08 · Auxiliar · Data da última compra registrada
SELECT
    MAX(o.order_purchase_timestamp) AS ultima_compra
FROM orders o; -- 2018-10-17 17:30:18


-- A09 · Auxiliar · Pedidos comprados em outubro/2018
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS pedidos,
    COUNT(oi.order_item_id) AS itens
FROM orders o
LEFT JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE o.order_purchase_timestamp >= '2018-10-01'
    AND o.order_purchase_timestamp < '2018-11-01'
GROUP BY o.order_status; -- 4 pedidos cancelados


-- A10 · Auxiliar · Pedidos intermediários com data estimada vencida
SELECT
    COUNT(*) AS pedidos_intermediarios,
    COUNT(o.order_estimated_delivery_date) AS com_estimativa,
    SUM(o.order_estimated_delivery_date < '2018-10-17 17:30:18') AS vencidos_0d,
    SUM(o.order_estimated_delivery_date < DATE_SUB('2018-10-17 17:30:18', INTERVAL 30 DAY)) AS vencidos_30d,
    SUM(o.order_estimated_delivery_date < DATE_SUB('2018-10-17 17:30:18', INTERVAL 90 DAY)) AS vencidos_90d
FROM orders o
WHERE o.order_status NOT IN ('delivered', 'canceled', 'unavailable'); 
-- pedidos_intermediarios 1729 · com_estimativa 1729 · vencidos_0d 1729 · vencidos_30d 1728 · vencidos_90d 1570


-- ############################################################
-- PERGUNTA 2 — Quais as 10 categorias que mais faturam,
--              e o ticket médio de cada?
-- ############################################################

-- ============================================================
-- A11 · Final · Top 10 categorias por faturamento
-- ============================================================
SELECT
    t.product_category_name_english AS categoria,
    SUM(oi.price + oi.freight_value) AS faturamento,
    COUNT(DISTINCT o.order_id) AS pedidos,
    ROUND(SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id), 2) AS ticket_medio
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY categoria
ORDER BY faturamento DESC
LIMIT 10;


-- ============================================================
-- Auxiliares de diagnóstico — grupo NULL
-- Objetivo: mostrar que o grupo NULL não distorce o ranking.
-- ============================================================

-- A12 · Auxiliar · Faturamento do grupo NULL
SELECT
    t.product_category_name_english AS categoria,
    SUM(oi.price + oi.freight_value) AS faturamento,
    COUNT(DISTINCT o.order_id) AS pedidos,
    ROUND(SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id), 2) AS ticket_medio
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
    AND t.product_category_name_english IS NULL
GROUP BY categoria;  -- faturamento 203353.84 · pedidos 1412 · ticket 144.02


-- A13 · Auxiliar · Posição do grupo NULL no ranking (faturamento)
SELECT COUNT(*) FROM (
    SELECT
        t.product_category_name_english AS categoria,
        SUM(oi.price + oi.freight_value) AS faturamento
    FROM orders o
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY categoria
    HAVING faturamento > 203353.84)
AS pos_acima_do_null;  -- 18 → NULL em 19º
					   -- Valor do HAVING copiado do A12

-- ############################################################
-- PERGUNTA 3 — Tempo médio de entrega por estado,
--              e onde é pior?
-- ############################################################

-- A14 · Auxiliar · Pedidos entregues por estado
SELECT
	c.customer_state AS estado, 
    COUNT(*) AS pedidos
FROM orders o
INNER JOIN customers c
	ON o.customer_id = c.customer_id 
WHERE o.order_status = 'delivered'
	AND o.order_delivered_customer_date IS NOT NULL
GROUP BY estado
ORDER BY pedidos ASC;

-- A15 · Auxiliar · Tempo de entrega nacional (sanidade)
-- invertidos > 0 → entrega antes da compra (ver Q04)
SELECT 
    COUNT(*) AS pedidos, 
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24), 2) AS media_dias,
    ROUND(MIN(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24), 2) AS min_dias,
    ROUND(MAX(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24), 2) AS max_dias,
    SUM(o.order_delivered_customer_date < o.order_purchase_timestamp) AS invertidos
FROM orders o
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL; -- pedidos 96470 · media 12.54 · min 0.50 · max 209.63 · invertidos 0

-- A16 · Final · Tempo médio de entrega por estado
SELECT
    c.customer_state AS estado, 
    COUNT(*) AS pedidos,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24), 2) AS media_dias
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY estado
HAVING pedidos >= 150
ORDER BY media_dias DESC; -- 5 piores (estado, media_dias): AL 24.52 · PA 23.75 · MA 21.55 · SE 21.50 · CE 21.25
                          -- 5 melhores (estado, media_dias): SP 8.74 · PR 11.97 · MG 11.99 · DF 12.95 · SC 14.93

-- A16b · Auxiliar · Soma de pedidos do A16
SELECT SUM(a16_subquery.pedidos) AS total_pedidos_a16
FROM (
    SELECT
        c.customer_state AS estado, 
        COUNT(*) AS pedidos
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
    HAVING COUNT(*) >= 150
) AS a16_subquery; -- total pedidos (a16): 96137


-- A17 · Auxiliar · Estados excluídos pelo HAVING do A16
-- Objetivo: o corte esconde média pior?
SELECT
    c.customer_state AS estado_excluido, 
    COUNT(*) AS pedidos,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24), 2) AS media_dias
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY estado_excluido
HAVING pedidos < 150
ORDER BY media_dias DESC;  -- estados excluídos (estado_excluido, media_dias): RR 29.36 · AP 27.17 · AM 26.40 · AC 21.02

-- A17b · Auxiliar · Soma de pedidos do A17
SELECT SUM(a17_subquery.pedidos) AS total_pedidos_a17
FROM (
	SELECT
		c.customer_state AS estado_excluido, 
		COUNT(*) AS pedidos
	FROM orders o
	INNER JOIN customers c
		ON o.customer_id = c.customer_id
	WHERE o.order_status = 'delivered'
		AND o.order_delivered_customer_date IS NOT NULL
	GROUP BY estado_excluido
	HAVING pedidos < 150
    ) AS a17_subquery; -- 96137 + 333 = 96470 → bate com A15

-- total_pedidos_a16 + total_pedido_a17 = pedidos (a15)

-- ############################################################
-- PERGUNTA 4 — Percentual de pedidos entregues após
--              a data estimada?
-- ############################################################


-- ############################################################
-- PERGUNTA 5 — Pedido atrasado recebe nota pior?
-- ############################################################


-- ############################################################
-- PERGUNTA 6 — As 3 categorias mais vendidas dentro
--              de cada estado?
-- ############################################################
