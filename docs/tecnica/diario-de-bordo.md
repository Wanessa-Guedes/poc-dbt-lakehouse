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

## Etapa 1 — Inicializar o projeto dbt + conectar no DuckDB — EM ANDAMENTO

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

**Resultado:** _(preencher quando o `dbt debug` passar)_

**Pendências / aprendizados:** _(preencher)_

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

