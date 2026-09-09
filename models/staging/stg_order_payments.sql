-- stg_order_payments: 1:1 com raw.order_payments. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- Grão provável do fato de pagamentos = 1 transação (order_id + payment_sequential).

with source as (
    select *
    from {{ source('olist', 'order_payments') }}
),
renamed as (
    select
    --chaves
        order_id,
        payment_sequential,
    --atributos do pagamento
        payment_type,
        payment_installments,
    --valor: DOUBLE na fonte -> DECIMAL pra não acumular erro em SUM.
        cast(payment_value as decimal(10,2)) as payment_value,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
