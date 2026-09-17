# NOTAS — Diário do projeto

Decisões, bugs, achados e aprendizados de cada dia.
Resultados detalhados de cada query → `docs/achados.md` (mesmo ID do `.sql`).

---

## Dia 1 — 31/08

### Objetivo
Setup do ambiente e `01_schema.sql` → 6 tabelas com PK e FK declaradas.

### Setup
- MySQL, Workbench, GitHub Desktop, repositório clonado, `.gitignore` commitado.

### Decisões técnicas
- Nome e ordem das colunas iguais ao cabeçalho do CSV → facilita conferir a carga.
- Collation `utf8mb4_0900_ai_ci` → comparação ignora acento e maiúscula. Motivo: cidade grafada de formas diferentes ('sao paulo' / 'são paulo' / 'SAO PAULO') cairia em grupos separados no GROUP BY.
- `DECIMAL UNSIGNED` é deprecado no MySQL 8 (gera warning) → tirado de `price` e `freight_value`.
- `review_score` → TINYINT, não ENUM. ENUM usa a POSIÇÃO do valor em conta numérica → AVG sobre ENUM não dá erro, dá número errado em silêncio.
- `order_status` → VARCHAR(20), não ENUM. Os 8 valores ainda não tinham sido confirmados no CSV.
- PK composta em `order_items` → `(order_id, order_item_id)`. Só o par identifica a linha.
- `order_reviews` SEM PK → a documentação do Kaggle confirma a PK de todas as tabelas, exceto reviews → `review_id` pode ter duplicata.

### Achados sobre o modelo de dados
- `customer_id` ≠ pessoa. Muda a cada pedido.
- `customer_unique_id` = pessoa → contar cliente exige `COUNT(DISTINCT customer_unique_id)`.

### Aprendizados
- FK aponta para PK ou UNIQUE (padrão SQL). O MySQL 8.0 aceita coluna que só tem índice, mas não é boa prática.

**Status:** `01_schema.sql` completo → 6 tabelas, PK e FK declaradas.

---

## Dia 2 — 02/09

### Objetivo
`02_load.sql` → carregar as 6 tabelas com `LOAD DATA LOCAL INFILE`.
Ordem: customers → products → translation → orders → order_items → order_reviews.

### Decisões técnicas
- Pais antes dos filhos → a FK recusa linha filha sem pai carregado.
- Campo opcional → `@variavel` + `NULLIF(@variavel, '')` dentro do próprio LOAD DATA.
  - Sem isso, campo vazio NÃO vira NULL: INT vira `0` e DATETIME vira `0000-00-00 00:00:00`.
  - Com `LOCAL`, isso gera só warning, não erro → passa em silêncio.
- `LINES TERMINATED BY` varia por arquivo:
  - `\n` (Unix) → customers, products, orders, order_items
  - `\r\n` (Windows) → `product_category_name_translation.csv`, `olist_order_reviews_dataset.csv`

### Bugs encontrados e corrigidos
1. **Barra invertida antes das aspas finais** → review_id `636b237e87574ba29654deaba9eb9797` terminava o comentário com o emoji `:\`. O LOAD DATA leu `\"` como aspas escapadas (texto), não como fim de campo → o campo não fechava onde deveria. Fix: barra removida à mão no CSV, no Bloco de Notas.

### Verificação de carga
- `COUNT(*)` das 6 tabelas conferido contra os CSVs → todas batem.
- Contar linhas no Bloco de Notas superestima o total: comentário com quebra de linha interna ocupa várias linhas físicas.
- Fonte de verdade → `COUNT(*)` do MySQL ou contagem lógica do Excel (aspas protegem a quebra interna).

### Aprendizados
- `\` é caractere de escape padrão do LOAD DATA:
  - `\"` antes do fim do campo → quebra a carga
  - `\n` → vira quebra de linha · `\t` → vira tab · `\N` → vira NULL
  - `\` antes de outro caractere → a barra some
  - Ou seja: barra no meio do texto não quebra a carga, mas altera o texto em silêncio
- Workbench: linha toda `NULL` no fim da grade, marcada com `*` → linha vazia para inserir dado novo. Não é dado.

### Commits
- **Tipos:**
  - `feat` → novo recurso (ex.: query nova)
  - `fix` → corrige erro
  - `docs` → só documentação
  - `style` → formatação, sem mudar lógica
  - `refactor` → reorganiza código sem nova função nem correção
  - `test` → testes
  - `chore` → configurações que não afetam o sistema
- **Regras:**
  - Um assunto por commit
  - Imperativo, primeira letra minúscula, sem ponto final
  - Título com no máximo 50 a 72 caracteres
  - Exemplo → `docs: cria achados.md`

**Status:** `02_load.sql` completo → 6 tabelas carregadas e conferidas.

---

## Dia 3 — 02/09

### Objetivo
`03_qualidade.sql` → 4 checagens: nulos, registros órfãos, `review_id` duplicado, datas inconsistentes.

### Decisões técnicas
- PK não entra no check de nulo → a constraint já impede NULL.
- FK fora da PK entra em DOIS checks: nulo e órfão.
- `products.product_category_name → translation` não tem FK, mas foi checada como órfã mesmo assim.
- `IS NULL` não pega `''` → coluna de texto opcional sem `NULLIF` esconde vazio. Fix no `02_load.sql`: `NULLIF` em `product_category_name`, `customer_city` e `customer_state`.

### Achados sobre a qualidade do dado
- **Nulos (Q01)**
  - 0 em quase todas as colunas checadas.
  - `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm` → 2 NULL cada.
  - `product_category_name` → 610 linhas com `''`, invisíveis ao `IS NULL`. Após o fix na carga → 610 NULL.
  - `customer_city`, `customer_state`, `order_status` checados com `= ''` → 0.
- **Órfãos (Q02)**
  - 0 nas 4 relações com FK (orders→customers, order_items→orders, order_items→products, order_reviews→orders).
  - products → translation: 623 produtos sem tradução.
    - 610 → categoria NULL (NULL nunca casa no JOIN)
    - 13 → categoria preenchida sem tradução: `pc_gamer` (3) e `portateis_cozinha_e_preparadores_de_alimentos` (10)
- **Duplicatas (Q03)**
  - 789 `review_id` aparecem mais de uma vez.
  - 1.603 linhas pertencem a esses `review_id` → 1.603 − 789 = 814 cópias excedentes.
- **Datas (Q04)**
  - Ordem esperada: compra → aprovação → transportadora → entrega.
  - 1.382 pedidos com pelo menos uma inversão.
  - Por etapa: compra 166 · aprovação 1.359 · transportadora 23.
  - 166 + 1.359 + 23 = 1.548 > 1.382 → há pedidos com mais de uma inversão (contados várias vezes nas etapas, uma vez no total).
  - 2.980 pedidos têm pelo menos uma das 4 datas NULL. Não ficam fora da checagem: entram quando duas datas preenchidas estão invertidas → 9 dos 1.382 (Q04f, Dia 4).

### Aprendizados
- Órfão → `LEFT JOIN` + `WHERE pai.coluna IS NULL`.
- `HAVING` filtra grupos depois do `GROUP BY`. Sem `GROUP BY`, a tabela inteira vira um grupo só.
- Subquery dentro do `FROM` (tabela derivada) exige alias.

**Status:** `03_qualidade.sql` completo → 4 checagens rodadas no dado real. `02_load.sql` corrigido e reconferido.

---

## Dia 4 — 03/09 a 15/09

### Objetivo
Beaulieu cap. 8 (GROUP BY). Perguntas 1, 2 e 3 no `04_analises.sql`.

### Mudanças no projeto
- Criado `docs/achados.md` → caderno com resultado e leitura de cada query.
- Toda query ganhou ID: `L` (carga), `Q` (qualidade), `A` (análises), `V` (views).
- Os 4 `.sql` reorganizados em seções, com cabeçalho e comentários explicativos.
- *Importante:* `DATEDIFF` - substituída no Dia 5

### Decisões técnicas

**Organização**
- Formato de número → bloco de resultado como o MySQL devolve (`1179143.77`). Texto em formato brasileiro (`1.179.143,77`).

**Qualidade (revisão do Dia 3)**
- `= ''` só em colunas de texto carregadas SEM `NULLIF` → nas outras, `''` já virou NULL.
- FK fica fora do `= ''` → `''` não teria pai e a carga recusaria a linha.
- Data e número sem `NULLIF` → `MIN` por coluna. Se procura o menor valor (`0000-00-00` ou `0`) → pode ser warning de `NULL`.
- PK não passa por `NULLIF` → PK não aceita NULL.

**P1 — Receita**
- Receita → sempre `price + freight_value`.
  - Bruta → os 8 status. Valor nominal de tudo que foi comprado.
  - Líquida prevista → exclui `canceled` e `unavailable`. Assume que pendentes serão concluídos.
  - Líquida → só `delivered`. Receita realizada.
  - Três definições porque "receita" admite mais de uma leitura e o número muda.
- Mês → agrupar e ordenar por `'%Y-%m'`, exibir com `'%M %Y'`.
- `SET lc_time_names = 'pt_BR'` no topo do `04` → mês e dia da semana em português.
- Pedido atrasado → data estimada de entrega vencida antes do fim da coleta (em vez de mês de compra).
- Margem do README → 90 dias: a mais exigente, e ainda cobre 90,8% dos intermediários.
- Série útil → até agosto/2018. Setembro e outubro têm volume residual.

**P2 — Categorias**
- Ticket médio → receita líquida ÷ `COUNT(DISTINCT o.order_id)` de `delivered`. Gasto por pedido, não preço por item.
- Categoria → em inglês, via `LEFT JOIN`, mantendo NULL. `INNER JOIN` descartaria os 13 sem tradução em silêncio. Português evitaria só 13 dos 623.

**P3 — Entrega**
- Início na compra (`order_purchase_timestamp`) → o cliente percebe a espera inteira, incluindo aprovação do pagamento, preparo e transporte.
- `DATEDIFF` → dias inteiros de calendário, mais legíveis para comparar estados. O erro por pedido é menor que 1 dia, pequeno diante de médias entre 8 e 29 dias. Média exata em horas: 12,54 contra 12,50.
- Corte `HAVING pedidos >= 150` → os 4 estados abaixo têm entre 41 e 145 pedidos; a partir de RO, todos têm mais de 240. Com poucas entregas, alguns pedidos atípicos mudam a média.
- A17 → mostra os estados excluídos. Sem ele, o corte esconderia as 3 piores médias.

### Bugs encontrados e corrigidos

**Queries**
1. Q01c checava a PK da translation → trocado para `product_category_name_english`.
2. Tradução carregada sem `NULLIF` → `IS NULL` não provava ausência de vazio → `NULLIF` em `product_category_name_english` e tabela recarregada.
3. FK `fk_orders_product_id` numa coluna `customer_id` → renomeada `fk_orders_customer_id` no arquivo.

**Afirmações**
4. "609 `unavailable` sem pagamento" → 609 é o total de `unavailable`, e 0 estão sem aprovação (A06).
5. "1.729 pedidos atrasados" → afirmado só com base no pedido mais antigo → A10 confirma atraso (90,8% há mais de 90 dias), não abandono → termo trocado para 'atrasado'
6. Black Friday "aumento proporcional" → 7,8× na receita ≠ 8,8× nos pedidos → valor médio por pedido 11,4% menor.
7. A01–A03 com "mesma trajetória" → sobem e caem nos mesmos meses, mas com intensidades diferentes → "trajetória semelhante".
8. Distância bruta/líquida "1% a 3% na maior parte da série" → só 13 de 20 meses → 1,0–3,0% de set/2017 a ago/2018, até 7,1% em jan/2017.
9. 2016 como "fase piloto" → hipótese → "volume irregular".
10. "Setembro/2018 marca o fim da coleta" → a última compra é de 17/10/2018 → série útil até agosto/2018 (A08, A09).
11. Motivos da P3:
    - Início descrito como "pagamento" → a escolha real é a compra.
    - `DATEDIFF` "faz 23h → 01h pesar pouco" → invertido: 2 horas viram 1 dia. O argumento certo é o erro menor que 1 dia.
    - Corte pelo "salto AM → RO" → em proporção, AC → AM é maior → motivo reescrito.

### Achados que mudaram decisão
- A10 → 90,8% dos intermediários vencidos há +90 dias → margem de 90 dias no README
- A09 → out/2018 só tem 4 cancelados sem item → série útil até ago/2018
- A12, A13 → grupo NULL em 19º → LEFT JOIN mantido
- A17 → corte escondia as 3 piores médias → README cita os excluídos

### Aprendizados

**Filtros e agregação**
- `WHERE` filtra linhas antes do `GROUP BY`.
- `HAVING` filtra grupos depois → aceita agregação e alias.
- `AND` é avaliado antes de `OR` → usar parênteses ao combinar.

**NULL e vazio**
- `COUNT(coluna)` ignora NULL → com `LEFT JOIN`, conta só quem tem par.
- Zero no banco não diz se era zero ou vazio no CSV.

**Contas**
- Condição vira 1 ou 0 → `GROUP BY` ou `SUM` sobre condição separa e conta casos numa query só.
- `DATEDIFF(fim, início)` × `TIMESTAMPDIFF(unidade, início, fim)` → ordem dos argumentos oposta. Ordem errada → número negativo, sem erro.
- `DATEDIFF` ignora a hora → não detecta inversão no mesmo dia.
- `TIMESTAMPDIFF(HOUR, ...) / 24` → decimal é fração de dia (0,25 = 6 horas), não horas.

**Análise**
- Número no README precisa de ID rastreável em `docs/achados.md`.

**Status:** P1, P2 e P3 respondidas e validadas. `03_qualidade.sql` ampliado. Documentação sintetizada.

---

## Dia 5 — 16/09

### Objetivo
Trocar a medição de tempo de entrega de `DATEDIFF` para `TIMESTAMPDIFF`. Refazer A15, A16 e A17.

### Decisões técnicas
- Tempo de entrega → `TIMESTAMPDIFF(HOUR, compra, entrega) / 24` em A15, A16 e A17. Motivo: dias exatos, sem o arredondamento de calendário do `DATEDIFF`.
- Substitui a decisão do Dia 4 (`DATEDIFF`, dias de calendário).

### Bugs encontrados e corrigidos
1. A15 com colunas duplicadas → `media_dias` e `media_dias_exata` viraram a mesma conta depois da troca; `negativos` e `invertidos` também → sobraram `media_dias` e `invertidos`.
2. 'parado' foi afirmado sem prova → atraso não prova abandono (há entrega de 210 dias) → termo trocado por 'atrasado'

### Achados que mudaram decisão
- A15–A17 → troca de função não mudou nenhuma leitura → método novo mantido

### Aprendizados
- Trocar a função de cálculo obriga a revisar o propósito da query auxiliar, não só o número.
- `DATEDIFF` devolve inteiro · `TIMESTAMPDIFF(HOUR, ...) / 24` devolve decimal → `MIN`/`MAX` precisam de `ROUND`.

**Status:** P3 refeita com `TIMESTAMPDIFF`. A15, A16 e A17 validadas.