# Documentação técnica — POC dbt + Lakehouse

Notas de aprendizado enquanto construo a POC. Cada página é curta, com exemplo
sobre os dados reais (marketplace estilo Olist). A ideia é reler antes de
entrevista e servir de portfólio no GitHub.

> **Ordem de leitura sugerida:** modelagem → camadas → qualidade. Os ADRs
> registram *por que* cada decisão foi tomada.
>
> 📓 O [diário de bordo](diario-de-bordo.md) registra cada etapa da construção
> (o que, por quê, resultado, pendências).

## 01 — Modelagem dimensional

| Página | Assunto |
|---|---|
| [grao-e-fato.md](01-modelagem-dimensional/grao-e-fato.md) | O que é grão, como escolher, por que o grão define o fato |
| [role-playing-dates.md](01-modelagem-dimensional/role-playing-dates.md) | Uma `dim_data`, vários papéis (compra, aprovação, entrega...) |
| [degenerate-e-junk-dimensions.md](01-modelagem-dimensional/degenerate-e-junk-dimensions.md) | `order_id` no fato sem virar dimensão; agrupar flags soltas |
| [scd.md](01-modelagem-dimensional/scd.md) | Slowly Changing Dimensions: SCD1 vs SCD2, quando usar cada |
| [surrogate-keys.md](01-modelagem-dimensional/surrogate-keys.md) | Chave técnica vs chave natural; hash vs sequência |

## 02 — Camadas e dbt

| Página | Assunto |
|---|---|
| [o-que-e-dbt.md](02-camadas-e-dbt/o-que-e-dbt.md) | Model = 1 SELECT; `ref()` e o DAG; config; comandos |
| [o-que-e-duckdb.md](02-camadas-e-dbt/o-que-e-duckdb.md) | O "SQLite analítico"; por que serve aqui; limites |
| [materializacoes.md](02-camadas-e-dbt/materializacoes.md) | view / table / ephemeral / incremental — o trade-off |
| [bronze-silver-gold.md](02-camadas-e-dbt/bronze-silver-gold.md) | O que entra e sai de cada camada; mapeamento para dbt |
| [onde-mora-a-regra-de-negocio.md](02-camadas-e-dbt/onde-mora-a-regra-de-negocio.md) | Regra calculada uma vez, na silver; o fato só carrega |

## 03 — Qualidade e testes

| Página | Assunto |
|---|---|
| [dbt-tests.md](03-qualidade-e-testes/dbt-tests.md) | `not_null`, `unique`, `relationships`, testes de reconciliação |

## Decisões (ADR)

| ADR | Decisão |
|---|---|
| [adr-0001](decisoes/adr-0001-grao-order-item.md) | Grão do fato principal = 1 item de pedido |
| [adr-0002](decisoes/adr-0002-pagamentos-fato-separado.md) | Pagamentos em fato separado, não em `fct_order_items` |
