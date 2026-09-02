## 01/08 — Dia 1 — APRENDIZADOS & ACHADOS

### Objetivo
Setup do ambiente e escrita de `01_schema.sql` — 6 tabelas com PK e FK declaradas.

### Setup
- MySQL, Workbench, GitHub Desktop, repo clonado, .gitignore commitado.

### Decisões técnicas
- Nome de coluna == cabeçalho do CSV, mesma ordem. LOAD DATA mapeia coluna por POSIÇÃO, não por nome.
- Collation `utf8mb4_0900_ai_ci` -> comparação ignora acento e maiúscula. Necessário: cidade brasileira vem grafada de formas diferentes ('sao paulo' / 'são paulo' / 'SAO PAULO'). Sem isso, GROUP BY por cidade separa o que deveria ser um grupo só.
- `DECIMAL UNSIGNED` é deprecado no MySQL 8 — gera warning. Tirado de `price`/`freight_value`.
- `review_score` virou TINYINT, não ENUM. ENUM guarda ÍNDICE (posição), não a string — AVG/soma sobre ENUM gera erro.
- `order_status` virou VARCHAR(20), não ENUM — Olist tem 8 valores possíveis, ainda não confirmados no CSV.
- PK composta em `order_items`: `PRIMARY KEY (order_id, order_item_id)`. Só a combinação das duas identifica linha única.
- `order_reviews` SEM PK — documentação do dataset no Kaggle confirma a PK de todas as tabelas em uso, exceto a de `olist_order_reviews_dataset.csv`. Ou seja, `review_id` pode ter duplicata.
- `DROP TABLE IF EXISTS` em ordem inversa da criação (filho antes do pai) — senão FK trava o DROP da tabela pai. Permite rodar a mesma query sem dar erro.

### Achados sobre o modelo de dados
- `customer_id` != pessoa. Repete por pedido. `customer_unique_id` = pessoa. Contar cliente exige `COUNT(DISTINCT customer_unique_id)`, não `COUNT(*)`.

### Aprendizados
- FK só aponta pra coluna PK ou UNIQUE — precisa de alvo único do outro lado.

### Pendente pro Dia 2 ou 3
Checar `review_id` duplicado em `order_reviews` com GROUP BY + HAVING COUNT(*) > 1.

**Status:** `01_schema.sql` completo — 6 tabelas, PK e FK declaradas.


## Dia 2 — 02/09

### Objetivo
Escrever e executar `02_load.sql`, carregando as 6 tabelas via LOAD DATA LOCAL INFILE, na ordem: customers → products → translation → orders → order_items → order_reviews.

### Decisões técnicas
- Campos numéricos e de data opcionais (podem vir vazios no CSV) usam padrão `@variavel` + `NULLIF(@variavel, '')` dentro do próprio LOAD DATA, convertendo string vazia em NULL antes da inserção. Evita zero-falso em INT e erro de conversão em DATETIME.
- `LINES TERMINATED BY` varia por arquivo: a maioria dos CSVs do Olist usa quebra de linha Unix (`\n`), mas `product_category_name_translation.csv` e `olist_order_reviews_dataset.csv` usam Windows (`\r\n`). Confirmado abrindo cada arquivo no Bloco de Notas (indicador no canto inferior direito).

### Bugs encontrados e corrigidos
1. **SET fora do comando LOAD DATA**: escrever `;` antes do bloco `SET` transforma-o num statement independente, desconectado da carga — as variáveis `@var` recebem o valor do CSV mas nunca são gravadas na coluna real (fica tudo NULL). Fix: SET precisa estar dentro do mesmo comando LOAD DATA.
2. **Caractere de escape em texto livre**: 1 linha de `order_reviews` (review_id `636b237e87574ba29654deaba9eb9797`) tinha um emoji de texto (`:\`) no final do comentário, logo antes do fechamento de aspas. O parser CSV interpretou `\"` como aspas escapada (parte do texto), não como fim de campo. Corrigido editando o CSV fonte diretamente no Bloco de Notas, removendo a barra invertida da linha específica. Barras `\` no meio de outros comentários não causam o mesmo problema — só quando colada imediatamente antes do fechamento de aspas.

### Verificação de carga
Contagem MySQL (`COUNT(*)`) conferida contra CSV original para as 6 tabelas — todas batendo. Nota lateral: contar linhas no Bloco de Notas superestima o total quando há comentários com quebra de linha interna; Excel e MySQL contam linha lógica (1 registro = 1 linha, aspas protegem quebras internas). Usar sempre COUNT(*) do MySQL ou contagem lógica do Excel como fonte de verdade, nunca contagem de linhas físicas de editor de texto.

### Aprendizados
Linha `null` no final da tabela é uma *linha de inserção de novos dados **(linha fantasma)***. Simbolizada pelo *.
#### Commits 
1. **Tipos Principais de Commits:**
- *feat*: Adiciona um novo recurso ao código.
- *fix*: Corrige um erro ou bug.
- *docs*: Altera apenas a documentação.
- *style*: Muda a estilização ou formatação do código, sem alterar a lógica.
- *refactor*: Refatora o código sem criar novas funções ou corrigir bugs.
- *test:* Cria ou altera testes.
- *chore:* Atualiza tarefas de build, pacotes ou configurações que não afetam o sistema principal.
2. **Usar Imperativo**
- Separe commits diferentes.
- Modo imperativo na descrição.
- Escreva a primeira letra da descrição em minúscula.
- Não coloque ponto final no final da primeira linha.
- Mantenha o título com no máximo 50 a 72 caracteres.


### Pendente pro Dia 3
Checar `review_id` duplicados em `order_reviews` (nota do escopo do projeto, ainda não verificado contra dado real) via GROUP BY + HAVING COUNT(*) > 1.

**Status:** `02_load.sql` completo - 6 tabelas com dados carregados (a partir dos csv's) e conferidos.