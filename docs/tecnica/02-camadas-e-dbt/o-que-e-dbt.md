# O que é o dbt

## O dbt é o "T" do ELT

Pipeline de dados em 3 letras: **E**xtract, **L**oad, **T**ransform.

- **E + L** — alguém tira os dados da origem e carrega num banco (aqui: os CSVs
  do Olist entram no DuckDB).
- **T** — transformar o bruto em tabelas confiáveis para o BI. **É só isso que o
  dbt faz.**

## A ideia central: 1 arquivo = 1 SELECT = 1 objeto

Você escreve `models/algnome.sql` com **um único `SELECT`**. O dbt embrulha esse
SELECT em `CREATE VIEW algnome AS (...)` ou `CREATE TABLE algnome AS (...)` e
manda o banco executar.

- Você **nunca** escreve `CREATE TABLE`, `INSERT`, `DROP`. Só `SELECT`.
- 1 arquivo `.sql` = 1 "model" = 1 tabela ou view no banco.
- O dbt cuida do DDL, de recriar quando o SQL muda, e da ordem.

## `ref()` e o DAG

Um model puxa de outro assim:

```sql
select * from {{ ref('stg_orders') }}
```

`{{ ref('...') }}` não é SQL — é marcação do dbt (Jinja). Antes de rodar, o dbt:

1. lê todos os `ref()` de todos os arquivos,
2. monta o **grafo de dependências (DAG)**,
3. roda os models na ordem certa, sozinho.

Você nunca declara a ordem de execução. Só declara quem depende de quem, via
`ref()`. Benefício extra: trocar o nome de um model não quebra nada, porque
ninguém hardcoda o nome.

### model ≠ materialização

- **model** = o passo de transformação: um `.sql` com um `SELECT` que vira um
  objeto no banco. `stg_orders`, `fct_order_items` são models.
- **materialização** = *como* esse model vira objeto (view / table / ephemeral /
  incremental). Ver [materializacoes.md](materializacoes.md).

Analogia: o model é a receita (os passos); a materialização é servir na hora
(view) ou deixar pronto na geladeira (table).

### `ref()` faz duas coisas

1. **ordem de execução** — monta o DAG.
2. **resolve o nome real** — `{{ ref('stg_orders') }}` vira
   `banco.schema.stg_orders` no SQL final, com o schema/ambiente corretos. Por
   isso nunca se hardcoda nome de tabela.

### DAG do dbt vs DAG do Airflow

Mesma estrutura (grafo de dependências sem ciclo), papéis diferentes:

| | Airflow | dbt |
|---|---|---|
| Nó | qualquer tarefa (script, API, arquivo, disparar dbt) | um model / teste / snapshot — SQL no mesmo banco |
| Dependências | definidas à mão (`task_a >> task_b`) | inferidas dos `ref()` / `source()` |
| Agenda / dispara | sim — é a função dele | não — roda uma vez quando se chama `dbt build` |
| Escopo | pipeline ponta a ponta, entre sistemas | só a camada de transformação |

Complementares: o Airflow (ou cron / GitHub Actions / Dagster) dispara o
`dbt build`; o dbt gerencia o DAG interno dos models. Numa POC local, `dbt build`
na mão ou num GitHub Actions já basta.

## Onde a conta acontece

O **dbt não processa dados**. Ele gera SQL e manda para um banco (o "adapter").
O banco faz o trabalho. Aqui o banco é o **DuckDB** (ver
[o-que-e-duckdb.md](o-que-e-duckdb.md)).

Fluxo completo:

```
CSVs em data/raw/
   ↓  DuckDB lê
dbt gera SQL (resolvendo os ref())
   ↓  DuckDB executa
tabelas/views dentro de dev.duckdb
   ↓
Power BI / análise consulta as tabelas de marts
```

## Os dois arquivos de config

| Arquivo | Descreve | Versionado? |
|---|---|---|
| `dbt_project.yml` | o **projeto**: caminhos das pastas, config padrão por pasta | sim, é compartilhado |
| `profiles.yml` | a **conexão**: tipo de banco, caminho/servidor, credenciais | em geral **não** (segredo). Nesta POC sim — DuckDB não tem senha, e versionar deixa o repo rodável por qualquer um |

Ligados pelo nome do `profile:`. O `dbt_project.yml` diz qual profile usar; o
`profiles.yml` define o que é esse profile.

Ordem de busca do `profiles.yml`: `--profiles-dir` → variável de ambiente →
**pasta atual** → `~/.dbt/`. Deixamos na raiz do repo e rodamos o dbt de lá.

### `target` e múltiplos ambientes

Dentro do profile, `outputs:` pode ter vários ambientes (`dev`, `prod`, `ci`...) e
`target:` diz qual é o padrão:

```yaml
poc_dbt_lakehouse:
  target: dev
  outputs:
    dev:  { type: duckdb, path: dev.duckdb,          threads: 4 }
    prod: { type: duckdb, path: /dados/prod.duckdb,  threads: 8 }
```

- `dbt run` → usa `dev`
- `dbt run --target prod` → **mesmo código**, banco diferente

É assim que o mesmo projeto roda na máquina, no CI e em produção. Num banco com
senha, o `prod` teria `host` / `user` / `password` — e o `password` viria de
variável de ambiente (`"{{ env_var('DBT_PASSWORD') }}"`), nunca escrito no arquivo.
Esse é o motivo de o `profiles.yml` normalmente ficar fora do Git.

## `seed` não é o dado do negócio

`data/raw/*.csv` (os 99k pedidos do Olist) **não são seeds**. Seed é uma tabelinha
de apoio, pequena, que você mantém à mão e versiona no Git.

| | `data/raw/*.csv` | `seeds/*.csv` |
|---|---|---|
| O que é | dado de verdade, chega de um sistema | referência manual (de-para, feriados, grupos) |
| Tamanho | grande (aqui ~120 MB) | KB |
| Entra no banco via | `ingest.py` → `raw.*` (o EL) | `dbt seed` → schema do projeto |
| Declarado como | `source('olist', ...)` no `_sources.yml` | vira `ref('nome_do_csv')` sozinho |
| Muda | toda semana | quase nunca |

A pasta `seeds/` só passa a existir quando houver um seed de verdade — a linha
`seed-paths: ["seeds"]` no `dbt_project.yml` é só "onde procurar, se houver".
Candidato provável nesta POC: `regioes_br.csv` (UF → região) para o "% no prazo
por região" do desafio.

## Estrutura de pastas

| Pasta | Conteúdo | Camada |
|---|---|---|
| `models/staging/` | 1 model por tabela de origem, só renomeia e tipa | bronze |
| `models/intermediate/` | joins, dedup, regras de negócio | silver |
| `models/marts/` | `fct_*` e `dim_*` no modelo estrela | gold |
| `seeds/` | CSVs pequenos versionados (ex.: mapeamentos manuais) | — |
| `snapshots/` | SCD2 nativo (histórico de status) | — |
| `macros/` | funções SQL reaproveitáveis (Jinja) | — |
| `tests/` | testes singulares (um `.sql` que não pode retornar linhas) | — |
| `target/` | SQL compilado + artefatos (gerado, no `.gitignore`) | — |

## Comandos

| Comando | O que faz |
|---|---|
| `dbt debug` | confere config + conexão. Não roda model |
| `dbt run` | constrói todos os models |
| `dbt test` | roda os testes de dados |
| `dbt build` | `run` + `test` + `seed` + `snapshot` na ordem do DAG — o "1 comando" |
| `dbt compile` | só gera o SQL final em `target/`, sem executar (bom para debugar) |
| `dbt docs generate && dbt docs serve` | site de documentação com o DAG navegável |
