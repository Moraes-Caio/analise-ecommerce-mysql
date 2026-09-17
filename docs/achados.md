# Achados

Caderno de laboratório do projeto. Cada query que sustenta uma afirmação tem uma entrada aqui, com o mesmo ID usado no arquivo `.sql`.

- `L` → `sql/02_load.sql`
- `Q` → `sql/03_qualidade.sql` · uma entrada por checagem, com letras para cada query (`Q02a`, `Q02b`...)
- `A` → `sql/04_analises.sql`
- `V` → `sql/05_views.sql`

Formato dos números:
- Bloco de resultado → como o MySQL devolve (`1179143.77`)
- Texto → formato brasileiro (`1.179.143,77`)

Status → `confirmado` · `hipótese` · `revisar` · `refazer` · `pendente`

---

## Carga (L)

### L01 · Contagem de linhas por tabela

- **Pergunta:** cada tabela tem o mesmo número de linhas que o CSV de origem (sem o cabeçalho)?
- **Resultado:**
  - customers → 99.441 linhas
  - products → 32.951 linhas
  - product_category_name_translation → 71 linhas
  - orders → 99.441 linhas
  - order_items → 112.650 linhas
  - order_reviews → 99.224 linhas
- **Checagem:**
  - As 6 contagens conferem com os CSVs
- **Leitura:** carga completa, nenhuma linha perdida
- **Status:** confirmado
- **Usado em:** Q04 (total de pedidos)

---

## Qualidade (Q)

### Q01 · Valores nulos e vazios escondidos

- **Pergunta:** as colunas usadas em análise ou em FK têm valores nulos, ou vazios que o `IS NULL` não detecta?
- **Resultado:**
  - Q01a · customers → 0 nulos nas 4 colunas checadas
  - Q01b · products → `product_category_name` 610 · `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm` 2 cada
  - Q01c · translation → `product_category_name_english` 0 nulos
  - Q01d · orders → 0 nulos nas 4 colunas checadas
  - Q01e · order_items → 0 nulos nas 5 colunas checadas
  - Q01f · order_reviews → 0 nulos nas 3 colunas checadas
  - Q01g · texto vazio (`''`) em colunas sem `NULLIF` → 0 em `customer_unique_id`, `customer_zip_code_prefix`, `seller_id`, `review_id`
  - Q01h · menor valor em datas e números sem `NULLIF`:
  - QO1i · itens com frete zero
    ```
    order_purchase_timestamp        2016-09-04 21:15:19
    order_estimated_delivery_date   2016-09-30 00:00:00
    shipping_limit_date             2016-09-19 00:15:34
    price                           0.85
    freight_value                   0.00
    review_score                    1
    review_creation_date            2016-10-02 00:00:00
    review_answer_timestamp         2016-10-07 18:32:28
    ```
  - Q01h · itens com `freight_value` = 0 → 383
- **Leitura:**
  - Único volume relevante de nulos → 610 produtos sem categoria (campo vazio no CSV, convertido em `NULL` na carga) → aparecem como categoria `NULL` na P2
  - Nenhum texto vazio escondido nas colunas carregadas sem `NULLIF`
  - Nenhuma data zero (`0000-00-00`)
  - `price` e `review_score` sem zero escondido
  - 383 itens com frete grátis real
- **Status:** confirmado
- **Usado em:** README P2, ressalva de método

### Q02 · Registros órfãos

- **Pergunta:** existem linhas filhas cuja chave não existe na tabela pai?
- **Técnica:** `LEFT JOIN` + `IS NULL` na coluna do pai
- **Resultado:**
  - Q02a · orders → customers → 0 linhas
  - Q02b · order_items → orders → 0 linhas
  - Q02c · order_items → products → 0 linhas
  - Q02d · order_reviews → orders → 0 linhas
  - Q02e · products → translation → 623 produtos
  - Q02g · categorias preenchidas sem tradução → 2 (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`)
  - Q02h · produtos nessas categorias → `pc_gamer` 3 · `portateis_cozinha_e_preparadores_de_alimentos` 10
- **Checagem:** 610 (Q01b) + 13 (Q02h) = 623 (Q02e) → bate
- **Leitura:**
  - As 4 relações com FK declarada não têm órfãos
  - products → translation não tem FK → 623 produtos sem tradução
  - Desses, 610 têm categoria nula (`NULL` nunca casa no JOIN) e 13 têm categoria preenchida sem tradução
  - Exibir a categoria em português evitaria só os 13, não os 623
- **Status:** confirmado
- **Usado em:** README P2, decisão do `LEFT JOIN`

### Q03 · review_id duplicado

- **Pergunta:** `review_id` é único em `order_reviews`?
- **Resultado:**
  - Q03b · review_id que se repetem → 789
  - Q03c · linhas que pertencem a esses review_id → 1.603
- **Derivado:** 1.603 − 789 = 814 cópias excedentes (linhas além da primeira ocorrência de cada review_id)
- **Leitura:** `review_id` não é único → `order_reviews` ficou sem PK
- **Status:** confirmado
- **Usado em:** `01_schema.sql` (ausência de PK)

### Q04 · Datas fora da ordem cronológica

- **Pergunta:** existem pedidos com uma etapa datada depois de uma etapa posterior?
- **Ordem esperada:** compra → aprovação → saída para transportadora → entrega ao cliente
- **Resultado:**
  - Q04a · pedidos com pelo menos uma das 4 datas nula → 2.980
  - Q04b · compra depois de alguma etapa seguinte → 166
  - Q04c · aprovação depois de alguma etapa seguinte → 1.359
  - Q04d · saída para transportadora depois da entrega → 23
  - Q04e · pedidos com pelo menos uma inversão → 1.382
  - Q04f · pedidos com inversão e pelo menos uma data nula → 9
- **Derivado:**
  - 99.441 − 2.980 = 96.461 pedidos com as 4 datas preenchidas
  - 166 + 1.359 + 23 = 1.548 > 1.382 → há pedidos com mais de uma inversão
  - 1.382 − 9 = 1.373 pedidos com inversão e as 4 datas preenchidas
  - 9 ÷ 1.382 = 0,65%
- **Leitura:**
  - 1.382 pedidos têm alguma data fora de ordem
  - O maior grupo é aprovação depois da saída para transportadora ou da entrega (1.359)
  - Comparação com NULL não é verdadeira nem falsa → Q04b–Q04e comparam só as datas preenchidas de cada pedido
  - Pedido com data nula entra quando tem inversão entre as datas que existem → 9 casos, peso desprezível
- **Status:** confirmado
- **Usado em:** A15 (checagem de entrega antes da compra)

---

## P1 — Receita mês a mês

### A01 · Final · Receita bruta mensal

- **Pergunta:** qual a receita bruta (8 status, `price + freight_value`) por mês de compra?
- **Resultado:** 
  ```
  mes               receita_bruta
  setembro 2016            354.75
  outubro 2016           56808.84
  dezembro 2016             19.62
  janeiro 2017          137188.49
  fevereiro 2017        286280.62
  março 2017            432048.59
  abril 2017            412422.24
  maio 2017             586190.95
  junho 2017            502963.04
  julho 2017            584971.62
  agosto 2017           668204.60
  setembro 2017         720398.91
  outubro 2017          769312.37
  novembro 2017        1179143.77
  dezembro 2017         863547.23
  janeiro 2018         1107301.89
  fevereiro 2018        986908.96
  março 2018           1155126.82
  abril 2018           1159698.04
  maio 2018            1149781.82
  junho 2018            1022677.11
  julho 2018           1058728.03
  agosto 2018          1003308.47
  setembro 2018            166.46
  ```
- **Checagem:** 24 linhas → set/2016 a set/2018 são 25 meses; falta novembro/2016
- **Leitura:**
  - Pico da série → novembro/2017, R$ 1.179.143,77
  - 2017 → de R$ 137.188,49 (jan) a R$ 863.547,23 (dez)
  - 2018 → entre R$ 986.908,96 (fev) e R$ 1.159.698,04 (abr), de janeiro a agosto
  - 2016 → volume irregular: setembro R$ 354,75 · outubro R$ 56.808,84 · novembro sem vendas · dezembro R$ 19,62
  - Setembro/2018 → R$ 166,46, contra R$ 1.003.308,47 em agosto → série útil termina em agosto/2018
  - Outubro/2018 não aparece, embora A08 mostre compra nesse mês → explicado em A09
- **Derivado:**
  - 1.179.143,77 ÷ 769.312,37 = 1,53 → novembro/2017 53% acima de outubro/2017
  - 863.547,23 ÷ 137.188,49 = 6,29 → receita cresce 6,3× ao longo de 2017
- **Status:** confirmado
- **Usado em:** README P1 → resumo, números, interpretação, ressalvas

### A02 · Final · Receita líquida prevista mensal

- **Pergunta:** qual a receita mensal excluindo `canceled` e `unavailable`?
- **Resultado:**
  ```
  mes               receita_liquida_prevista
  setembro 2016                       279.69
  outubro 2016                      51354.52
  dezembro 2016                        19.62
  janeiro 2017                     136943.46
  fevereiro 2017                   283561.69
  março 2017                       425617.96
  abril 2017                       405848.61
  maio 2017                        582710.83
  junho 2017                       499652.24
  julho 2017                       578753.73
  agosto 2017                      661903.52
  setembro 2017                    717102.72
  outubro 2017                     764756.03
  novembro 2017                   1172191.68
  dezembro 2017                    861526.77
  janeiro 2018                    1101920.01
  fevereiro 2018                   979486.16
  março 2018                      1152656.99
  abril 2018                      1156248.89
  maio 2018                       1145686.46
  junho 2018                      1020381.90
  julho 2018                      1039783.58
  agosto 2018                      996973.51
  setembro 2018                       166.46
  ```
- **Checagem:** 24 linhas → mesmos meses de A01
- **Leitura:**
  - Sobe e cai nos mesmos meses que A01, com pico em novembro/2017
  - Setembro/2018 igual a A01 (R$ 166,46) → nenhum pedido `canceled` ou `unavailable` com item nesse mês
- **Derivado:** (A01 − A02) ÷ A01 → entre 0,18% e 1,79% de jan/2017 a ago/2018 → peso de cancelados e indisponíveis
- **Status:** confirmado
- **Usado em:** README P1

### A03 · Final · Receita líquida mensal

- **Pergunta:** qual a receita mensal só de pedidos `delivered`?
- **Resultado:** 
  ```
  mes               receita_liquida
  setembro 2016              143.46
  outubro 2016             46490.66
  dezembro 2016               19.62
  janeiro 2017            127482.37
  fevereiro 2017          271239.32
  março 2017              414330.95
  abril 2017              390812.40
  maio 2017               566851.40
  junho 2017              490050.37
  julho 2017              566299.08
  agosto 2017             645832.36
  setembro 2017           701077.49
  outubro 2017            751117.01
  novembro 2017          1153364.20
  dezembro 2017           843078.29
  janeiro 2018           1077887.46
  fevereiro 2018          966168.41
  março 2018             1120598.24
  abril 2018             1132878.93
  maio 2018              1128774.52
  junho 2018             1011978.29
  julho 2018             1027807.28
  agosto 2018             985491.64
  ```
- **Checagem:** 23 linhas → A01 sem setembro/2018
- **Leitura:**
  - Sobe e cai nos mesmos meses que A01 e A02
  - Pico também em novembro/2017 → R$ 1.153.364,20
  - Intensidade das variações difere. Ex.: jul/2018 → bruta +3,5%, líquida +1,6%
  - 2018 → entre R$ 966.168,41 (fev) e R$ 1.132.878,93 (abr), de janeiro a agosto
  - Setembro/2018 ausente → nenhum pedido `delivered` com item comprado nesse mês
- **Derivado:**
  - Distância (A01 − A03) ÷ A01:
    - set/2017 a ago/2018 → entre 1,05% (jun/2018) e 2,99% (mar/2018)
    - jan a ago/2017 → entre 2,57% (jun/2017) e 7,08% (jan/2017)
    - 2016 → até 59,56% (set/2016), volume muito baixo
  - jan/2017 → distância de 7,08%, só 0,18% de cancelados e indisponíveis (A02) → o resto vem de pedidos intermediários
- **Status:** confirmado
- **Usado em:** README P1

### A04 · Auxiliar · Receita diária novembro/2017

- **Pergunta:** o pico de novembro/2017 está concentrado em algum dia?
- **Resultado:**
  ```
  dia           dia_semana    receita_bruta    pedidos
  2017-11-01    quarta             22066.99        109
  2017-11-02    quinta             24082.94        121
  2017-11-03    sexta              26036.15        138
  2017-11-04    sábado             22294.81        111
  2017-11-05    domingo            20901.95        141
  2017-11-06    segunda            33149.61        190
  2017-11-07    terça              24610.72        157
  2017-11-08    quarta             23262.88        174
  2017-11-09    quinta             28901.64        188
  2017-11-10    sexta              23603.57        164
  2017-11-11    sábado             26670.94        155
  2017-11-12    domingo            26529.31        172
  2017-11-13    segunda            29334.24        202
  2017-11-14    terça              31356.87        189
  2017-11-15    quarta             27546.25        185
  2017-11-16    quinta             32918.09        224
  2017-11-17    sexta              34192.17        189
  2017-11-18    sábado             27205.38        146
  2017-11-19    domingo            23312.61        158
  2017-11-20    segunda            50065.87        226
  2017-11-21    terça              39276.17        226
  2017-11-22    quarta             29951.16        198
  2017-11-23    quinta             51499.46        277
  2017-11-24    sexta             178377.63       1166
  2017-11-25    sábado             71858.16        498
  2017-11-26    domingo            53595.20        388
  2017-11-27    segunda            56644.85        400
  2017-11-28    terça              56248.47        376
  2017-11-29    quarta             47031.59        319
  2017-11-30    quinta             36618.09        264
  ```
- **Checagem:** 30 linhas · soma da receita = 1.179.143,77 → bate com novembro/2017 em A01
- **Método de comparação:** cada dia contra a média do mesmo dia da semana em outubro/2017 (A05)
- **Leitura:**
  - Pico em 24/11/2017 (sexta, Black Friday) → R$ 178.377,63 · 1.166 pedidos
  - 1 a 10/11 → entre 0,8× e 1,3× o normal
  - 11 a 19/11 → entre 1,0× e 1,6×
  - 20/11 (segunda) → 1,7× · 21/11 → 1,3× · 22/11 → 1,2× · 23/11 (quinta) → 2,0×
  - Semana anterior acima do normal, com oscilação, mas em escala muito menor que 24/11
  - Depois do evento, queda gradual → 25/11 4,1× · 26/11 2,5× · 27/11 2,0× · 28/11 1,9× · 29/11 1,8× · 30/11 1,4×
  - Valor médio por pedido abaixo do habitual em todos os dias de 24 a 30/11 → entre 8% e 21% menor
- **Limitação:** a baseline é outubro. Parte da alta de novembro pode ser crescimento do mês, e não efeito do evento. Os dados não separam as duas coisas
- **Status:** confirmado
- **Usado em:** README P1

### A05 · Auxiliar · Receita diária outubro/2017

- **Pergunta:** qual o patamar normal de cada dia da semana, para comparar com novembro?
- **Resultado:**
  ```
  dia           dia_semana    receita_bruta    pedidos
  2017-10-01    domingo            21909.43        128
  2017-10-02    segunda            25178.30        142
  2017-10-03    terça              30389.12        198
  2017-10-04    quarta             24787.58        157
  2017-10-05    quinta             29129.83        140
  2017-10-06    sexta              19998.48        126
  2017-10-07    sábado             17748.51        103
  2017-10-08    domingo            19424.09        124
  2017-10-09    segunda            34989.53        191
  2017-10-10    terça              31965.46        180
  2017-10-11    quarta             25916.40        156
  2017-10-12    quinta             22201.28        140
  2017-10-13    sexta              26405.41        151
  2017-10-14    sábado             16185.46        116
  2017-10-15    domingo            21299.15        120
  2017-10-16    segunda            35107.63        194
  2017-10-17    terça              34756.27        197
  2017-10-18    quarta             31501.86        176
  2017-10-19    quinta             26909.61        175
  2017-10-20    sexta              21563.08        120
  2017-10-21    sábado             17552.04        110
  2017-10-22    domingo            23234.37        157
  2017-10-23    segunda            25835.52        158
  2017-10-24    terça              25738.66        164
  2017-10-25    quarta             20731.59        154
  2017-10-26    quinta             26317.77        143
  2017-10-27    sexta              23152.45        131
  2017-10-28    sábado             18922.48         86
  2017-10-29    domingo            20283.60        130
  2017-10-30    segunda            23330.88        144
  2017-10-31    terça              26846.53        157
  ```
- **Checagem:** 31 linhas · soma da receita = 769.312,37 → bate com outubro/2017 em A01
- **Derivado:**
  - Média de receita por dia da semana:
    - domingo 21.230,13 (5 dias) · segunda 28.888,37 (5) · terça 29.939,21 (5)
    - quarta 25.734,36 (4) · quinta 26.139,62 (4) · sexta 22.779,86 (4) · sábado 17.602,12 (4)
  - Sextas (6, 13, 20, 27) → receita média 22.779,86 · pedidos médios 132
  - 24/11 ÷ sextas → receita 178.377,63 ÷ 22.779,86 = 7,83× · pedidos 1.166 ÷ 132 = 8,83×
  - Valor médio por pedido → 24/11: 152,98 · sextas: 172,57 → 11,4% menor
- **Nota de termo:** "valor médio por pedido" = receita bruta ÷ pedidos de todos os status. Não é o ticket médio do projeto (receita líquida ÷ pedidos `delivered`)
- **Status:** confirmado
- **Usado em:** README P1

### A06 · Auxiliar · unavailable por aprovação de pagamento

- **Pergunta:** todo pedido `unavailable` teve pagamento aprovado?
- **Resultado:**
  ```
  sem_pagamento  total
  0                609
  ```
- **Checagem:** única linha, `sem_pagamento = 0` → nenhum `unavailable` com `order_approved_at` nulo
- **Leitura:** os 609 pedidos `unavailable` tiveram pagamento aprovado e não foram entregues → sugere estorno. O dataset não tem tabela de reembolso para confirmar
- **Status:** confirmado
- **Usado em:** README P1, ressalva de `unavailable`

### A07 · Auxiliar · Pedidos intermediários por mês de compra

- **Pergunta:** os pedidos fora de `delivered`, `canceled` e `unavailable` estão concentrados no fim da coleta ou espalhados (pedidos intermediários)?
- **Resultado:**
  ```
  mes_compra   pedidos_intermediarios
  2016-09                           1
  2016-10                          28
  2017-01                          37
  2017-02                          65
  2017-03                          71
  2017-04                          74
  2017-05                          94
  2017-06                          70
  2017-07                          74
  2017-08                          79
  2017-09                          77
  2017-10                          69
  2017-11                         134
  2017-12                         107
  2018-01                         118
  2018-02                          70
  2018-03                         165
  2018-04                         121
  2018-05                          84
  2018-06                          46
  2018-07                          74
  2018-08                          70
  2018-09                           1
  ```
- **Checagem:** 23 linhas · soma = 1.729
- **Leitura:**
  - 1.729 pedidos em status intermediário
  - Os mais antigos são de setembro e outubro/2016
  - Distribuição espalhada por todo o período, não concentrada nos últimos meses
  - Agosto/2018 (70) próximo de fevereiro/2017 (65)
  - Picos em novembro/2017 (134) e março/2018 (165)
  - Maioria parada, não fila → confirmado por A10
- **Status:** confirmado
- **Usado em:** README P1, ressalva de pedidos intermediários

### A08 · Auxiliar · Data da última compra

- **Pergunta:** qual a data e hora exata da última compra registrada?
- **Resultado:**
  ```
  ultima_compra
  2018-10-17 17:30:18
  ```
- **Leitura:** fim da coleta = 17/10/2018, 17:30:18 → referência do A10
- **Status:** confirmado
- **Usado em:** A09, A10, README P1

### A09 · Auxiliar · Pedidos de outubro/2018

- **Pergunta:** A08 mostra compra em outubro/2018, mas A01 e A07 terminam em setembro/2018. O que são os pedidos de outubro?
- **Resultado:**
  ```
  order_status    pedidos    itens
  canceled              4        0
  ```
- **Leitura:**
  - Outubro/2018 → 4 pedidos, todos `canceled`, nenhum item
  - A01 usa `INNER JOIN` com `order_items` → pedido sem item é descartado → série termina em setembro
  - A07 exclui `canceled` → outubro também não aparece
  - A última compra (A08) é um desses 4 pedidos
- **Status:** confirmado
- **Usado em:** README P1, ressalva do fim da série

### A10 · Auxiliar · Pedidos intermediários com data estimada vencida

- **Pergunta:** quantos dos 1.729 intermediários têm `order_estimated_delivery_date` vencida antes do fim da coleta (A08)?
- **Critério:** data estimada vencida (escolhido em vez de mês de compra)
- **Resultado:**
  ```
  pedidos_intermediarios    com_estimativa    vencidos_0d    vencidos_30d    vencidos_90d
  1729                                1729           1729            1728            1570
  ```
- **Checagem:**
  - `pedidos_intermediarios` = 1.729 → bate com A07
  - `com_estimativa` = 1.729 → bate com Q01 (0 nulos)
- **Derivado:**
  - 1.570 ÷ 1.729 = 90,8%
  - 1.728 − 1.570 = 158 vencidos entre 30 e 90 dias
  - 1 vencido há menos de 30 dias
- **Leitura:**
  - Nenhum intermediário estava dentro do prazo quando a coleta terminou
  - 90,8% já tinham passado mais de 90 dias da data estimada
  - Todos atrasados; não é possível verificar se foram entregues depois da coleta
- **Status:** confirmado
- **Usado em:** README P1, ressalva de pedidos intermediários

---

## P2 — Top 10 categorias

### A11 · Final · Top 10 categorias por faturamento, com ticket médio

- **Pergunta:** quais as 10 categorias com maior receita líquida, quantos pedidos e qual o ticket médio de cada?
- **Resultado:**
  ```
  categoria               faturamento   pedidos   ticket_medio
  health_beauty            1412089.53      8647         163.30
  watches_gifts            1264333.12      5495         230.09
  bed_bath_table           1225209.26      9272         132.14
  sports_leisure           1118256.91      7530         148.51
  computers_accessories    1032723.77      6530         158.15
  furniture_decor           880329.92      6307         139.58
  housewares                758392.25      5743         132.06
  cool_stuff                691680.89      3559         194.35
  auto                      669454.75      3810         175.71
  garden_tools              567145.68      3448         164.49
  ```
- **Derivado:**
  - Mediana dos 10 tickets = (158,15 + 163,30) ÷ 2 = 160,73
  - watches_gifts → 230,09 − 160,73 = R$ 69,36 acima da mediana
  - Ranking de pedidos → bed_bath_table 1º · health_beauty 2º · sports_leisure 3º · computers_accessories 4º · furniture_decor 5º · housewares 6º · watches_gifts 7º · auto 8º · cool_stuff 9º · garden_tools 10º
  - Soma da coluna `pedidos` = 60.341
- **Leitura:**
  - Posição no faturamento não antecipa posição no ticket
  - health_beauty (1º) → 2º em pedidos + ticket acima da mediana → volume e valor
  - watches_gifts (2º) → só 7º em pedidos, maior ticket → valor
  - bed_bath_table (3º) → 1º em pedidos, um dos dois menores tickets → volume
  - cool_stuff → 9º em pedidos, 2º maior ticket (R$ 194,35) → valor, em escala menor
  - housewares → menor ticket (R$ 132,06), volume mediano (6º) → não se destaca em nenhum dos dois
  - Grupo `NULL` fora do top 10 → A12, A13
- **Nota de definição:** pedido com itens de 2 categorias conta nas duas → 60.341 não é o total de pedidos distintos do top 10
- **Status:** confirmado
- **Usado em:** README P2

### A12 · Auxiliar · Faturamento do grupo NULL

- **Pergunta:** quanto fatura o grupo de produtos sem categoria traduzida?
- **Resultado:**
  ```
  categoria   faturamento   pedidos   ticket_medio
  NULL          203353.84      1412         144.02
  ```
- **Checagem:** 1 linha
- **Derivado:** 203.353,84 ÷ 567.145,68 (garden_tools, 10º) = 0,36 → o NULL fatura 36% do 10º colocado
- **Leitura:** ticket de R$ 144,02, abaixo da mediana do top 10
- **Status:** confirmado
- **Usado em:** README P2, ressalva de método

### A13 · Auxiliar · Posição do grupo NULL no ranking

- **Pergunta:** em que posição o grupo NULL fica no ranking completo?
- **Resultado:**
  ```
  COUNT(*)
  18
  ```
- **Derivado:** posição = 18 + 1 = 19ª
- **Leitura:** fora do top 10 → manter o NULL via `LEFT JOIN` não altera o ranking
- **Limitação:** o valor do `HAVING` foi copiado do A12 → se o A12 mudar, o A13 precisa ser atualizado
- **Status:** confirmado
- **Usado em:** README P2, ressalva de método

---

## P3 — Tempo de entrega por estado

### A14 · Auxiliar · Pedidos entregues por estado

- **Pergunta:** quantos pedidos entregues, com data de entrega preenchida, cada estado tem?
- **Resultado:**
  ```
  estado  pedidos
  RR           41
  AP           67
  AC           80
  AM          145
  RO          243
  TO          274
  SE          335
  AL          397
  RN          474
  PI          476
  PB          517
  MS          701
  MA          717
  MT          886
  PA          946
  CE         1279
  PE         1593
  GO         1957
  ES         1995
  DF         2080
  BA         3256
  SC         3546
  PR         4923
  RS         5344
  MG        11354
  RJ        12350
  SP        40494
  ```
- **Checagem:** 27 linhas (26 estados + DF) · soma = 96.470
- **Derivado:** SP → 40.494 ÷ 96.470 = 42% dos pedidos
- **Leitura:**
  - 4 estados com menos de 150 pedidos (RR, AP, AC, AM) → 333 pedidos
  - A partir de RO, todos têm mais de 240
- **Status:** confirmado
- **Usado em:** corte do `HAVING` em A16

### A15 · Auxiliar · Tempo de entrega nacional

- **Pergunta:** a diferença entre compra e entrega, medida em horas exatas, faz sentido no país inteiro?
- **Resultado:**
  ```
  pedidos    media_dias    min_dias    max_dias    invertidos
  96470          12.54        0.50      209.63             0
  ```
- **Checagem:** `pedidos` = 96.470 → bate com a soma do A14
- **Leitura:**
  - Média nacional → 12,54 dias
  - `invertidos` = 0 → nenhuma entrega registrada antes da compra
  - Mínimo → 0,50 dia (12 horas) · máximo → 209,63 dias
  - Máximo muito acima da média → a média é sensível a entregas extremas
- **Status:** confirmado
- **Usado em:** README P3

### A16 · Final · Tempo médio de entrega por estado

- **Pergunta:** qual o tempo médio de entrega em cada estado, e onde é pior?
- **Resultado:**
  ```
  estado    pedidos    media_dias
  AL            397         24.52
  PA            946         23.75
  MA            717         21.55
  SE            335         21.50
  CE           1279         21.25
  PB            517         20.41
  PI            476         19.44
  RO            243         19.35
  BA           3256         19.31
  RN            474         19.26
  PE           1593         18.43
  MT            886         18.03
  TO            274         17.64
  ES           1995         15.77
  MS            701         15.60
  GO           1957         15.59
  RJ          12350         15.29
  RS           5344         15.28
  SC           3546         14.93
  DF           2080         12.95
  MG          11354         11.99
  PR           4923         11.97
  SP          40494          8.74
  ```
- **Checagem:** 
  - 23 linhas (27 − 4) · soma de `pedidos` = 96.137 (96.470 − 333) → bate
  - A16b → 96.137
- **Derivado:**
  - 24,52 ÷ 8,74 = 2,8× → amplitude AL ÷ SP
  - 12,54 − 8,74 = 3,80 dias → SP abaixo da média nacional
- **Leitura:**
  - 5 piores → AL 24,52 · PA 23,75 · MA 21,55 · SE 21,50 · CE 21,25
  - 5 melhores → SP 8,74 · PR 11,97 · MG 11,99 · DF 12,95 · SC 14,93
  - 5 piores → 1 estado do Norte (PA) e 4 do Nordeste
  - 5 melhores → Sul, Sudeste e DF
- **Status:** confirmado
- **Usado em:** README P3

### A17 · Auxiliar · Estados excluídos pelo HAVING do A16

- **Pergunta:** o corte esconde estados com média pior?
- **Resultado:**
  ```
  estado_excluido    pedidos    media_dias
  RR                      41         29.36
  AP                      67         27.17
  AM                     145         26.40
  AC                      80         21.02
  ```
- **Checagem:** 
  - 4 linhas · soma = 333
  - A17b → 333
- **Derivado:** 29,36 ÷ 8,74 = 3,4× → amplitude sem corte (RR ÷ SP)
- **Leitura:**
  - RR, AP e AM têm as 3 maiores médias do país, todas acima de AL (24,52)
  - Poucos pedidos → médias instáveis
- **Status:** confirmado
- **Usado em:** README P3, ressalva de método

---

## P4 — Entregas atrasadas

> IDs a partir de A18.

---

## P5 — Atraso e nota

---

## P6 — Top 3 categorias por estado

---

## Views (V)
