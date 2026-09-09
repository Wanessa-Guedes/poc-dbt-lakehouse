# Testes em dbt

## Para que servem (requisito 5 do desafio)

"O que roda automaticamente para um PR não quebrar nada?" → `dbt build` no CI,
que roda modelos **e** testes. PR só entra se passar.

## Testes genéricos (no `.yml` do modelo)

```yaml
models:
  - name: fct_order_items
    columns:
      - name: order_item_sk
        tests: [unique, not_null]          # testes sem parâmetro: lista de strings
      - name: sk_cliente
        tests:
          - not_null
          - relationships:                 # teste COM parâmetro: vira um mapa
              arguments:                    # dbt >= 1.10: argumentos aninhados aqui
                to: ref('dim_cliente')
                field: sk_cliente
      - name: no_prazo
        tests:
          - accepted_values:
              arguments:
                values: [true, false]
                quote: false
```

Os 4 de fábrica: `unique`, `not_null`, `accepted_values`, `relationships`.
`relationships` = a integridade referencial da estrela (todo FK do fato acha o
pai na dimensão).

> **Sintaxe dos argumentos:** até o dbt 1.9 os parâmetros (`to`, `field`,
> `values`...) iam direto sob o nome do teste. Do 1.10 em diante eles têm que
> ficar sob `arguments:` — a forma antiga ainda roda mas emite
> `MissingArgumentsPropertyInGenericTestDeprecation`. Testes sem parâmetro
> (`unique`, `not_null`) não mudam.

## Testes do `dbt_utils` / `dbt_expectations`

- `dbt_utils.expression_is_true` — regra de coluna arbitrária.
- `dbt_utils.equal_rowcount` / `fewer_rows_than` — comparar tabelas.
- `dbt_expectations.expect_row_values_to_have_recent_data` — a carga chegou?

## Testes singulares (SQL em `tests/`)

Um `.sql` que **não deve retornar linhas**. Ex.: reconciliação entre os dois fatos:

```sql
-- tests/assert_pagamento_bate_com_itens.sql
with itens as (
    select order_id, sum(preco + frete) as total_itens
    from {{ ref('fct_order_items') }}
    group by 1
),
pag as (
    select order_id, valor_itens_total
    from {{ ref('fct_pedidos') }}
)
select p.order_id, p.valor_itens_total, i.total_itens
from pag p
join itens i using (order_id)
where abs(p.valor_itens_total - i.total_itens) > 0.01
```

## Cobertura mínima da POC

| Alvo | Teste |
|---|---|
| SK de toda dimensão | `unique`, `not_null` |
| FK de todo fato | `relationships` + `not_null` (ou aponta para linha `-1`) |
| Grão do fato | `unique` na chave do grão (`order_id` + `order_item_id`) |
| Carga chegou | linha recente em `stg_orders` |
| Contagem mínima | `stg_orders` tem > N linhas (detecta carga parcial) |
| Reconciliação | teste singular pagamentos × itens |
| Enum de status | `accepted_values` na `dim_pedido` / staging |

### O que já está testado no staging (`models/staging/_staging.yml`)

- **PK natural de cada `stg_*`**: `unique` + `not_null` (`order_id`, `product_id`,
  `seller_id`, `customer_id`, `product_category_name`).
- **`review_id`**: só `not_null` — a extração traz duplicata (99.224 linhas /
  98.410 ids), dedup é da silver.
- **Grão composto** (`stg_order_items`, `stg_order_payments`): só `not_null` nas
  duas colunas por enquanto; o `unique` da combinação precisa de
  `dbt_utils.unique_combination_of_columns` (pacote ainda não instalado).
- **FKs entre staging**: `relationships` de `order_items`/`order_payments`/
  `order_reviews` → `stg_orders`, e de `order_items` → `stg_products` /
  `stg_sellers`. Zero órfãos.
- **Enums**: `accepted_values` em `order_status`, `payment_type`, `review_score`.
- **`geolocation`**: sem `unique` (é multivalorado por prefixo de CEP).

`dbt build --select staging` = 9 models + 41 testes, tudo verde.

## Fonte vs modelo

`dbt source freshness` valida se o dado bruto é recente **antes** de rodar.
Roda no início do pipeline para detectar carga atrasada.
