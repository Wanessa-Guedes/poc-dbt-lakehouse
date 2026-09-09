-- stg_customers: 1:1 com raw.customers. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- customer_unique_id só é DECLARADO aqui; a decisão de usá-lo como chave
-- de cliente é da silver.

with source as (
    select *
    from {{ source('olist', 'customers') }}
),
renamed as (
    select
    --chaves
        customer_id,
        customer_unique_id,
    --localização (prefixo de CEP é texto: zero à esquerda importa, não se soma)
        customer_zip_code_prefix,
        customer_city,
        customer_state,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
