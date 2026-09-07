# Sources e ingestão

## A fronteira: EL ↔ T

O dbt só faz o **T** do ELT. Ele nunca "lê CSV e carrega" — isso é o **EL**, e
mora fora do dbt:

```
CSVs em data/raw/  ──ingest.py──▶  raw.<tabela> no dev.duckdb  ──dbt──▶  staging → marts
     \_________________ EL _________________/                    \______ T ______/
```

`ingest/ingest.py` é o "EL": um script Python que carrega cada CSV numa tabela do
schema `raw`. O dbt entra só depois, e enxerga essas tabelas como **sources**.

Por que separar: o dbt é uma ferramenta de transformação, não de extração. Manter
a carga num script à parte deixa a fronteira explícita e faz o passo de ingestão
ser portável — na POC 3 ele vira uma task do Airflow sem o projeto dbt mudar.

## O que é um `source`

Um **source** é a declaração, dentro do dbt, de uma tabela **que já existe no
banco e que o dbt não criou**. É a porta de entrada do projeto.

Todo objeto no `dev.duckdb` é uma de duas coisas:

| | O que é | Como se referencia no SQL |
|---|---|---|
| **source** | dado bruto que entrou por fora (o `ingest.py`) | `{{ source('olist', 'orders') }}` |
| **model** | tabela/view que um `.sql` do dbt gera | `{{ ref('stg_orders') }}` |

O `_sources.yml` **não cria nada**. Ele dá nome lógico e metadados a tabelas que
já estão no banco:

```yaml
# models/staging/_sources.yml
version: 2

sources:
  - name: olist          # nome lógico do grupo de tabelas
    schema: raw           # onde elas estão no dev.duckdb
    tables:
      - name: orders
      - name: order_items
      # ... as 9
```

Serve para 4 coisas:

1. **Indireção.** `{{ source('olist', 'orders') }}` compila para `dev.raw.orders`.
   Se o schema `raw` um dia virar `bronze`, muda 1 linha no yml, não os 9
   `stg_*.sql`.
2. **Lineage.** No `dbt docs`, o grafo de dependências começa nos sources — dá
   para ver "este CSV alimenta este fato".
3. **`dbt source freshness`.** Com `_loaded_at` declarado, o dbt avisa se a carga
   atrasou (a gente liga isso numa etapa futura).
4. **Convenção.** Deixa explícito onde acaba o "dado de terceiros" e começa a
   responsabilidade do dbt.

**Regra:** só os models de `staging/` podem usar `source()`. Do `intermediate/`
pra frente, tudo é `ref()`. Assim existe exatamente **um** ponto de contato com
cada fonte bruta.

## Ingestão idempotente

```python
con.execute(
    f"""
    CREATE OR REPLACE TABLE raw.{table} AS
    SELECT *,
           current_timestamp AS _loaded_at,
           ?                 AS _source_file
    FROM read_csv_auto(?)
    """,
    [arquivo, str(caminho_arquivo)],
)
```

- **`CREATE OR REPLACE`** — rodar o script 2x dá o mesmo resultado (derruba e
  recria). Simula "chegou a pasta de segunda-feira, recarrego tudo do zero".
- **`read_csv_auto`** — o DuckDB amostra as primeiras linhas e adivinha os tipos.
  Rápido e quase sempre certo. Na bronze a gente **aceita o palpite** (bronze não
  julga); corrigir tipo é problema do staging.
- **`?` como placeholder** — o DuckDB cuida das aspas e do escape. Nome da tabela
  (`raw.{table}`) é identificador e vem de um dict fixo → f-string ok; nome de
  arquivo e caminho são *valores* → parâmetro.

### Colunas de auditoria

Padrão bronze: cada tabela `raw` ganha duas colunas técnicas.

| Coluna | O que guarda | Para quê |
|---|---|---|
| `_loaded_at` | timestamp da carga | rastrear "entrou quando"; base do `source freshness` |
| `_source_file` | nome do arquivo de origem | rastrear "veio de qual arquivo"; detectar carga parcial |

Prefixo `_` e snake_case para separar de colunas de negócio (dá para filtrar com
`columns('_%')` depois).

## O que a inferência do DuckDB fez com os dados do Olist

| Situação | Resultado | Ação no staging |
|---|---|---|
| BOM no CSV de tradução | removido automaticamente — 1ª coluna limpa | nada |
| `price`, `freight_value`, `payment_value` | `DOUBLE`, valores em **reais** (não centavos) | `CAST(... AS DECIMAL(10,2))` — float acumula erro em `SUM` |
| CEP-prefixo | `VARCHAR`, zero à esquerda preservado (`01003`) | manter texto — CEP não se soma |
| timestamps de `orders` | 5 colunas `TIMESTAMP` corretas | nada |
| `_loaded_at` | `TIMESTAMP WITH TIME ZONE` (`current_timestamp` traz fuso) | decidir se normaliza p/ `TIMESTAMP` |

Lição: **confirmar no dado antes de aplicar a solução pronta.** A macro
`centavos_para_reais()` da arquitetura de referência não é necessária aqui — os
valores já estão em reais.

## Comandos

```bash
make ingest        # roda ingest/ingest.py — carrega raw.*
make build         # roda dbt build
make all           # ingest + build

dbt list --resource-type source     # lista as sources declaradas
dbt build                           # com 0 models: "Found 9 sources / Nothing to do"

python scripts/explorar.py          # UI web do DuckDB (read-only) p/ navegar as tabelas
```

## Ver também

- [o-que-e-dbt.md](o-que-e-dbt.md) — `ref()`, o DAG, `dbt` como o "T" do ELT
- [bronze-silver-gold.md](bronze-silver-gold.md) — o que entra e sai de cada camada
- [o-que-e-duckdb.md](o-que-e-duckdb.md) — o banco de arquivo único
