# Staging: o padrão de um `stg_*`

A camada `models/staging/` é a **bronze** dentro do dbt: uma view por fonte, 1:1
com a tabela `raw`. É a única camada que toca `source()`. Da `intermediate` pra
frente é tudo `ref()`.

## O que pode e o que não pode

| Pode | Não pode |
|---|---|
| renomear coluna | join com outra tabela |
| reordenar / agrupar colunas | dedup / `row_number()` |
| `cast` de tipo | `CASE` de regra de negócio (ex: "no prazo") |
| normalizar fuso (`::timestamp`) | `coalesce` de categoria, agregação de review |
| corrigir typo do nome de origem (`lenght` → `length`) | filtrar linha suja |

Regra mental: **staging arruma a forma, não julga o conteúdo.** Se `stg_x` tem
número de linhas diferente de `raw.x`, alguma regra vazou pra cá.

## A anatomia (3 CTEs)

```sql
with source as (
    select * from {{ source('olist', 'orders') }}   -- só "pega a fonte"
),
renamed as (
    select                                          -- o trabalho mora aqui
        order_id,
        customer_id,
        _loaded_at::timestamp as _loaded_at,        -- normaliza fuso
        _source_file
    from source
)
select * from renamed                               -- saída sempre no fim
```

- **`source`** fica "burra" (`select *`): um lugar só pra saber de onde vem.
- **`renamed`** lista coluna por coluna — de propósito. Se a Olist adicionar uma
  coluna, o staging **não** muda sozinho; você decide.
- **`select * from renamed`** no fim: pra debugar, troca por `select * from
  source` e roda.

## Decisões deste projeto aplicadas no staging

- **Dinheiro** (`price`, `freight_value`, `payment_value`): `DOUBLE` na fonte →
  `cast(... as decimal(10,2))`. Float acumula erro em `SUM`. Já estão em reais
  (Etapa 2), então **sem** conversão de centavos.
- **`_loaded_at`**: vinha `TIMESTAMP WITH TIME ZONE` (`current_timestamp` da
  ingestão); as datas da fonte são sem fuso → `::timestamp` pra camada ficar
  consistente.
- **Prefixo de CEP**: continua `VARCHAR` (zero à esquerda importa, CEP não se
  soma).
- **Coordenadas** (`geolocation_lat/lng`): continuam `DOUBLE` — são medições, não
  entram em `SUM`.
- **`product_name_lenght` / `_description_lenght`**: typo da origem; renomeados
  para `_length` no staging (é o lugar de arrumar a forma).
- **Colunas que carregam problema conhecido** (`customer_unique_id`,
  `product_category_name` nula/PT, múltiplos reviews, `geolocation`
  multivalorado): só **declaradas** aqui. O tratamento é na silver — ver
  [bronze-silver-gold.md](bronze-silver-gold.md).
