-- stg_order_items: 1:1 com raw.order_items. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- Grão = 1 item de pedido (order_id + order_item_id).

with source as (
    select *
    from {{ source('olist', 'order_items') }}
),
renamed as (
    select
    --chaves
        order_id,
        order_item_id,
        product_id,
        seller_id,
    --datas
        shipping_limit_date,
    --valores: DOUBLE na fonte -> DECIMAL pra não acumular erro em SUM.
    --Já estão em reais (confirmado na Etapa 2), sem conversão de centavos.
        cast(price as decimal(10,2))         as price,
        cast(freight_value as decimal(10,2)) as freight_value,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
