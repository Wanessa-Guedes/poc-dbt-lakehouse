# Diário de bordo

Registro de cada etapa da POC: **o que** foi feito, **por quê**, o que resultou
e o que ficou pendente. Serve para reconstruir o raciocínio depois (portfólio,
entrevista) e para não repetir decisão já tomada.

Formato de cada entrada: Objetivo · O que fizemos · Por quê · Resultado ·
Pendências / aprendizados.

---

## Etapa 0 — Ambiente + dados — 2026-09-01

**Objetivo:** ter dbt rodando local e o dataset em mãos, sem escrever modelo ainda.

**O que fizemos:**
- `python3 -m venv .venv` + `pip install dbt-duckdb` → `dbt --version` ok.
- Baixamos o *Brazilian E-Commerce Public Dataset by Olist* (Kaggle) para
  `data/raw/` — 9 CSVs.
- `.gitignore` cobrindo `.venv/`, `data/raw/`, `target/`, `dbt_packages/`,
  `logs/`, `*.duckdb`.

**Por quê:**
- **venv** isola as libs da POC do Python do sistema — reprodutível e descartável.
- **DuckDB** como engine: grátis, roda na máquina e no CI, fala SQL puro (o time
  de BI do desafio não sabe Spark), e o `dbt build` roda tudo em 1 comando.
  Atende as restrições do brief sem data warehouse cloud.
- **Dataset do Olist**: é a base pública padrão de marketplace BR; as 9 tabelas
  são exatamente as do desenho de arquitetura. Bom para portfólio (gente
  reconhece o dataset).
- **`data/raw/` fora do git**: arquivos grandes (geolocation tem 61 MB) e o
  Kaggle tem licença própria — o README linka a fonte em vez de commitar os CSVs.

**Resultado:** ambiente funcional, dados em `data/raw/`, nada versionado além de
config.

**Pendências / aprendizados:**
- `product_category_name_translation.csv` começa com **BOM** (`﻿`) — tratar
  no staging para a primeira coluna não vir com nome sujo.
- `olist_orders_dataset.csv` tem `order_delivered_carrier_date` **e**
  `order_delivered_customer_date`. A definição de "no prazo" precisa escolher uma
  (ver [onde-mora-a-regra-de-negocio.md](02-camadas-e-dbt/onde-mora-a-regra-de-negocio.md)).
- `geolocation` confirmado multivalorado por prefixo de CEP.
- `order_reviews`: `review_comment_title` / `_message` quase sempre vazios.

---

## Etapa 1 — Inicializar o projeto dbt + conectar no DuckDB — 2026-09-07

**Objetivo:** um `dbt debug` verde, sem nenhum model ainda. Só esqueleto + conexão.

**O que fazer (Wanessa cria os arquivos):**

`dbt_project.yml` na raiz:

```yaml
name: 'poc_dbt_lakehouse'
version: '1.0.0'
profile: 'poc_dbt_lakehouse'          # tem que bater com o nome no profiles.yml

model-paths: ["models"]
seed-paths: ["seeds"]
snapshot-paths: ["snapshots"]
macro-paths: ["macros"]
test-paths: ["tests"]

clean-targets: ["target", "dbt_packages"]

models:
  poc_dbt_lakehouse:
    staging:
      +materialized: view
    intermediate:
      +materialized: view
    marts:
      +materialized: table
```

`profiles.yml` na raiz:

```yaml
poc_dbt_lakehouse:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: dev.duckdb
      threads: 4
```

Depois: `mkdir -p models` e `dbt debug`.

**Por quê:**
- Criamos os arquivos à mão (em vez de `dbt init`) para entender cada chave, e
  para manter o `profiles.yml` **dentro do repo** — DuckDB não tem senha, então
  versionar deixa qualquer um clonar e rodar (bom para portfólio).
- `profile:` liga o projeto à conexão. Ordem de busca do `profiles.yml`:
  `--profiles-dir` → env var → pasta atual → `~/.dbt/`. Rodando o dbt da raiz,
  ele acha o daqui.
- O bloco `models:` é o mapa bronze/silver/gold virando materialização por pasta
  (ver [materializacoes.md](02-camadas-e-dbt/materializacoes.md)).
- `path: dev.duckdb` — o banco inteiro é esse arquivo (está no `.gitignore`).

**Resultado:** `dbt debug` verde — `profiles.yml` e `dbt_project.yml` válidos,
conexão com o `dev.duckdb` ok. Nenhum model ainda.

**Pendências / aprendizados:**
- Python 3.14 no venv: a preocupação da Etapa 0 (sem wheel pronta) não se
  confirmou — `dbt-core 1.12.3` + `dbt-duckdb 1.11.0` instalaram e rodam normal.
- O bloco `models:` do `dbt_project.yml` gera um warning *"unused configuration
  paths"* enquanto não existir nenhum `.sql` nas pastas `staging/` etc. Some na
  Etapa 3.

---

## Etapa 2 — Ingestão dos CSVs + sources — 2026-09-07

**Objetivo:** os 9 CSVs do Olist visíveis para o dbt como `source('olist', ...)`,
sem escrever model ainda. Separar o **EL** (carga) do **T** (dbt).

**O que fizemos:**
- `ingest/ingest.py` — para cada CSV: `CREATE OR REPLACE TABLE raw.<tabela> AS
  SELECT *, current_timestamp AS _loaded_at, <arquivo> AS _source_file FROM
  read_csv_auto(<caminho>)`. Nome do arquivo e caminho passam como parâmetro
  (`?`) do DuckDB, não f-string.
- `models/staging/_sources.yml` — declara a source `olist`, `schema: raw`, as 9
  tabelas, cada uma com `description`.
- `Makefile` — alvos `ingest`, `build`, `all` (= `ingest` + `build`), `.PHONY`.
- `scripts/explorar.py` — abre a UI web do DuckDB (read-only) para navegar as
  tabelas.
- `requirements.txt` — versões de `dbt-duckdb` e `duckdb` fixadas.

**Por quê:**
- **EL fora do dbt:** o dbt é só transformação (T). O `ingest.py` é o "EL" do
  ELT — na POC 3 ele vira uma task do Airflow sem o dbt mudar nada. Ver
  [o-que-e-dbt.md](02-camadas-e-dbt/o-que-e-dbt.md).
- **`CREATE OR REPLACE`:** ingestão idempotente — rodar 2x dá o mesmo resultado,
  simula "chegou a pasta de segunda-feira, recarrego tudo".
- **Colunas `_loaded_at` / `_source_file`:** padrão bronze — rastrear quando cada
  dado entrou e de qual arquivo. Depois alimentam o `source freshness`.
- **`source()` só no staging:** um ponto de contato por fonte. Do intermediate
  pra frente é tudo `ref()`. Ver
  [sources-e-ingestao.md](02-camadas-e-dbt/sources-e-ingestao.md).

**Resultado:** 9 tabelas em `raw.*`, contagens conferem com o dataset Olist
padrão:

| tabela | linhas |
|---|---|
| `raw.orders` | 99.441 |
| `raw.customers` | 99.441 |
| `raw.geolocation` | 1.000.163 |
| `raw.order_items` | 112.650 |
| `raw.order_payments` | 103.886 |
| `raw.order_reviews` | 99.224 |
| `raw.products` | 32.951 |
| `raw.sellers` | 3.095 |
| `raw.product_category_name_translation` | 71 |

`dbt list --resource-type source` mostra as 9; `dbt build` = *"Found 9 sources /
Nothing to do"* (verde esperado, 0 models).

**Pendências / aprendizados:**
- **BOM não deu problema.** O `read_csv_auto` do DuckDB removeu o BOM do CSV de
  tradução sozinho — a 1ª coluna veio `product_category_name` limpa. Risca a
  pendência da Etapa 0.
- **Valores monetários estão em reais, não centavos.** `price` tem decimais
  (58.9, 12.99), média ~R$120, máx R$6.735. Se fossem centavos a média seria
  R$1,20. → A macro `centavos_para_reais()` da arquitetura de referência **não
  serve para este dataset.** (Confirmar no dado antes de aplicar solução pronta.)
- `price`, `freight_value`, `payment_value` vieram `DOUBLE` (ponto flutuante).
  Dinheiro em float acumula erro em `SUM` → `CAST(... AS DECIMAL(10,2))` no
  staging.
- CEP-prefixo (`customer_zip_code_prefix`, `geolocation_zip_code_prefix`) veio
  `VARCHAR` — zero à esquerda preservado (`01003`). Manter como texto (CEP não
  se soma).
- `_loaded_at` ficou `TIMESTAMP WITH TIME ZONE` (`current_timestamp` retorna com
  fuso), enquanto os timestamps das fontes são sem fuso. Decidir no staging se
  normaliza (`now()::timestamp`).

---

## Conceitos cobertos até aqui (base para as próximas etapas)

- **model** = 1 arquivo `.sql` com 1 `SELECT` = 1 objeto no banco. Não é a
  materialização.
- **materialização** = *como* o model vira objeto: view (barato criar / lento
  ler), table (caro criar / rápido ler), ephemeral (vira CTE), incremental (só
  processa linhas novas).
- **`ref()`** = função do dbt que (1) monta o DAG de execução e (2) resolve o
  nome real da tabela. Nunca hardcodar nome.
- **DuckDB** = banco relacional ACID, embutido (arquivo único), colunar/OLAP.
  Banco de verdade, só que sem servidor.
- **DAG do dbt vs Airflow** = mesma estrutura, papéis diferentes. Airflow
  orquestra entre sistemas e agenda; dbt infere o DAG dos `ref()` e roda a
  transformação. Complementares.

<!-- próximas etapas entram aqui -->

