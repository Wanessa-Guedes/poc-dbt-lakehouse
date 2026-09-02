# Camadas: bronze → silver → gold

## O que entra e o que sai

| Camada | Entra | Sai | Transformação permitida |
|---|---|---|---|
| **Bronze** (raw) | CSV da pasta da semana, convertido para parquet no S3 | cópia fiel, 1 tabela por arquivo | nenhuma regra. Só: tipar colunas, adicionar `_loaded_at`, `_source_file` |
| **Silver** (limpo / conformado) | bronze | dados deduplicados, chaves resolvidas, regras de negócio calculadas | dedup, cast, join de tradução, `CASE` de regra (`no_prazo`), filtro de linha suja |
| **Gold** (consumo) | silver | `fct_*` e `dim_*` no modelo estrela | só reshape para estrela: agrupar no grão, montar SK, montar FK |

Regra mental: **bronze não julga, silver limpa e decide, gold organiza para o BI.**

## Mapeamento para dbt

| Camada | Pasta dbt | Materialização | Nome |
|---|---|---|---|
| Bronze | `models/staging/` | `view` | `stg_orders`, `stg_order_items` |
| Silver | `models/intermediate/` | `view` ou `ephemeral` | `int_orders_enriched`, `int_payments_by_order` |
| Gold | `models/marts/` | `table` | `fct_order_items`, `dim_cliente` |

- `sources` (em `_sources.yml`) apontam para as tabelas bronze no S3/DuckDB.
- `staging` = 1:1 com a source, só renomeia e tipa. Nunca faz join.
- `intermediate` = onde os joins e as regras acontecem. Não é consumido pelo BI.
- `marts` = o que o BI enxerga. Documentado e testado.

## Onde a regra de negócio mora

Uma vez só, na **silver** (`int_orders_enriched`). Detalhe em
[onde-mora-a-regra-de-negocio.md](onde-mora-a-regra-de-negocio.md).

## Tratamento dos problemas dos dados (resumo)

| Problema | Camada | Como |
|---|---|---|
| Duplicata da extração | silver (staging→int) | `row_number()` por PK natural, mantém a mais recente |
| Status sobrescrito na origem | fora da estrela | `dbt snapshot` a cada carga → `status_historical` |
| Entrega antes da aprovação | silver | flag `linha_suspeita`; decidir com a área se exclui ou corrige |
| Carga atrasada / parcial | ingestão + testes | teste de contagem mínima; carga é idempotente por `_source_file` |
| `customer_id` volátil | silver | usa `customer_unique_id` como chave de cliente |
| Categoria nula / em PT | silver | `coalesce(categoria, 'sem_categoria')` → join com translation |
| Múltiplos reviews por pedido | silver | agrega para 1 por pedido (última? média?) — decisão de negócio |
| `geolocation` multivalorado | silver | 1 linha por prefixo de CEP (centroide ou primeira) |
