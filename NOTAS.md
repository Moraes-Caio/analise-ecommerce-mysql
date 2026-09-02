## 01/09 — Dia 1 - APRENDIZADOS

- Setup: MySQL, Workbench, GitHub Desktop, repo clonado, .gitignore commitado.
- LOAD DATA mapeia coluna por POSIÇÃO, não por nome. Nome de coluna == cabeçalho do CSV, mesma ordem — permite auditar a carga visualmente.
- customer_id != pessoa. Repete por pedido. customer_unique_id = pessoa. Contar cliente exige COUNT(DISTINCT customer_unique_id), não COUNT(*).
- FK só aponta pra coluna PK ou UNIQUE — precisa de alvo único do outro lado.
- Collation utf8mb4_0900_ai_ci -> comparação ignora acento e maiúscula. Necessário: cidade brasileira vem grafada de formas diferentes ('sao paulo' / 'são paulo' / 'SAO PAULO'). Sem isso, GROUP BY por cidade separa o que deveria ser um grupo só.
- DECIMAL UNSIGNED é deprecado no MySQL 8 — gera warning. Tirado de price/freight_value.
- ENUM guarda ÍNDICE (posição), não a string. AVG/soma sobre ENUM é armadilha. review_score virou TINYINT por isso.
- order_status virou VARCHAR(20), não ENUM — Olist tem 8 valores possíveis, ainda não confirmados no CSV.
- PK composta: PRIMARY KEY (order_id, order_item_id) em order_items. Só a combinação das duas identifica linha única.
- order_reviews SEM PK — documentação do dataset no kaggle confirma a PK de todas as tabelas em uso, exceto a de olist_order_reviews_dataset.csv. Ou seja, review_id poder ter duplicata. Checar com GROUP BY + HAVING COUNT(*) > 1 no Dia 2 ou 3.
- DROP TABLE IF EXISTS: ordem inversa da criação (filho antes do pai) — senão FK trava o DROP da tabela pai. -> Permite rodar mesmo query sem dar erro

**Status:** 01_schema.sql completo — 6 tabelas, PK e FK declaradas.

