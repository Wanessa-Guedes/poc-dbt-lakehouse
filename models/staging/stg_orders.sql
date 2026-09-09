-- stg_orders: 1:1 com raw.orders. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).

with source as (
    select *
    from {{ source('olist', 'orders') }}
),
renamed as (
    select
    --chaves
        order_id,
        customer_id,
    --status
        order_status,
    --datas    
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        _loaded_at::timestamp as _loaded_at, --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
