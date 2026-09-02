# Onde mora a regra de negócio

## O problema que isso resolve

Hoje cada área calcula "pedido entregue no prazo" de um jeito. Os relatórios não
batem. A causa: a regra está escrita **em vários lugares** (uma vez no Power BI
de Operações, outra num Excel do CX).

## A solução: uma definição, um lugar

A regra é calculada **uma vez**, num modelo da silver, e todo mundo consome
dali. Ninguém recalcula depois.

```sql
-- models/intermediate/int_orders_enriched.sql
select
    order_id,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- a definição oficial de "no prazo", num lugar só:
    case
        when order_delivered_customer_date is null then null      -- ainda não entregue
        when order_delivered_customer_date <= order_estimated_delivery_date then true
        else false
    end as no_prazo,

    date_diff('day',
        order_purchase_timestamp,
        order_delivered_customer_date) as dias_para_entrega,

    date_diff('day',
        order_estimated_delivery_date,
        order_delivered_customer_date) as atraso_dias
from {{ ref('stg_orders') }}
```

O `fct_order_items` faz `join` nesse modelo e **carrega a coluna para baixo**.
Nunca refaz o `CASE`.

```sql
-- models/marts/fct_order_items.sql (trecho)
select
    oi.order_id,
    oi.order_item_id,
    e.no_prazo,          -- vem pronto da silver
    e.dias_para_entrega,
    e.atraso_dias,
    ...
from {{ ref('stg_order_items') }} oi
left join {{ ref('int_orders_enriched') }} e using (order_id)
```

## Por que isso responde ao requisito de consistência

Operações e CX leem a **mesma coluna** `no_prazo` do mesmo fato. Não tem como
divergir — não existe segunda fórmula.

Se amanhã a definição mudar (ex.: "no prazo" passa a ser medido na data de
entrega à transportadora, não ao cliente), muda **um `CASE`**, e todos os
relatórios mudam juntos.

## Perguntas em aberto para as áreas

- Pedido não entregue: `no_prazo` = `null` ou `false`?
- Pedido cancelado entra na conta ou é excluído?
- "No prazo" = data de entrega ao cliente ou handoff à transportadora?
- Linha suja (entrega antes da aprovação): exclui ou corrige?
