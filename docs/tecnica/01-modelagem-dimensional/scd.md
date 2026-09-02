# Slowly Changing Dimensions (SCD)

Atributo de dimensão muda com o tempo (cliente muda de cidade, produto muda de
categoria, pedido muda de status). SCD é a estratégia de como registrar isso.

## Tipos que importam

| Tipo | O que faz | Perde histórico? | Quando usar |
|---|---|---|---|
| **SCD1** | sobrescreve o valor antigo | sim | valor corrigido, histórico não interessa |
| **SCD2** | fecha a linha antiga, abre uma nova com `valid_from`/`valid_to`/`is_current` | não | precisa saber "como estava na época do fato" |
| **SCD3** | guarda só o valor anterior numa coluna extra | parcial | raro |

## Decisão na POC

- `dim_cliente`, `dim_produto`, `dim_vendedor` → **SCD1** (overwrite).
  É POC, ninguém pediu "categoria do produto **na data da compra**".
- **Histórico de status do pedido** → tratado **fora da estrela**, numa tabela
  `status_historical` no estilo SCD2, alimentada a cada carga comparando o
  status atual da origem com o último status guardado.
  - Motivo: a origem **sobrescreve** o status (quando vai de `shipped` para
    `delivered`, a linha anterior some). Se eu não capturar a cada carga, perco.
  - O requisito de auditoria ("quero dizer quando um pedido mudou de status") é
    respondido por essa tabela, não pela `dim_pedido`.

## SCD2 em dbt

`dbt snapshot` faz SCD2 nativo:

```sql
{% snapshot scd_order_status %}
{{ config(
    target_schema='snapshots',
    unique_key='order_id',
    strategy='check',
    check_cols=['order_status']
) }}
select order_id, order_status from {{ ref('stg_orders') }}
{% endsnapshot %}
```

Roda `dbt snapshot` **antes** do `dbt run` a cada carga. Ele cria/atualiza
`dbt_valid_from`, `dbt_valid_to`, `dbt_scd_id`.

> Cuidado: snapshot lê o estado **no momento em que roda**. Se a carga de
> segunda não rodou, aquela transição de status é perdida para sempre. Documentar
> como risco.
