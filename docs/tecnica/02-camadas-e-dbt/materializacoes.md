# Materializações

Mesmo `SELECT`, diferentes formas de o dbt **persistir o resultado** no banco.
É sempre um trade-off entre três coisas:

- **custo de construir** (o que acontece no `dbt run`)
- **custo de ler** (o que acontece quando alguém consulta a tabela)
- **frescor** (o dado reflete a fonte agora, ou só depois do próximo run?)

## As quatro

| Materialização | O dbt roda | Ocupa espaço | Construir | Ler | Frescor |
|---|---|---|---|---|---|
| **view** | `CREATE VIEW` | não | instantâneo | lento (a query roda toda vez que se consulta) | sempre atual |
| **table** | `CREATE TABLE AS SELECT` | sim | caro (reprocessa tudo a cada `run`) | rápido | do último `run` |
| **ephemeral** | nada — vira CTE colado dentro de quem faz `ref()` nele | não | — | — | sempre atual |
| **incremental** | `CREATE TABLE` na 1ª vez; depois só processa linhas novas | sim | barato após a 1ª vez | rápido | do último `run` |

## Como escolher

- **view** — o padrão para o que ninguém consulta diretamente: `staging` e
  `intermediate`. Construir é de graça e sempre reflete a fonte.
- **table** — para o que é consultado com frequência e precisa ser rápido: os
  `marts` (`fct_*`, `dim_*`). O BI bate neles o tempo todo; vale pagar o custo
  de reconstruir a cada carga para a leitura ser rápida.
- **ephemeral** — lógica pequena e reaproveitável que não precisa existir como
  objeto no banco. Cuidado: não dá para consultar nem testar diretamente.
- **incremental** — fato grande onde reprocessar tudo a cada run dói (milhões de
  linhas). Mais complexo: exige uma cláusula `is_incremental()` e uma
  `unique_key`. Na POC, começar sem; migrar `fct_order_items` para incremental
  só se o `run` ficar lento.

## Onde se define

Três níveis, do mais geral para o mais específico (o mais específico vence):

1. **`dbt_project.yml`** — por pasta:
   ```yaml
   models:
     poc_dbt_lakehouse:
       staging:
         +materialized: view
       marts:
         +materialized: table
   ```
2. **No `.yml` da pasta** (`models/marts/_marts.yml`) — por model.
3. **No topo do `.sql`** — só aquele model:
   ```sql
   {{ config(materialized='incremental', unique_key='order_item_sk') }}
   ```

## Ligação com bronze / silver / gold

O bloco `models:` do `dbt_project.yml` é o mapa de camadas virando config:

| Camada | Pasta | Materialização |
|---|---|---|
| bronze | `staging/` | view |
| silver | `intermediate/` | view (ou ephemeral) |
| gold | `marts/` | table |
