-- stg_sellers: 1:1 com raw.sellers. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).

with source as (
    select *
    from {{ source('olist', 'sellers') }}
),
renamed as (
    select
    --chave
        seller_id,
    --localização (prefixo de CEP é texto)
        seller_zip_code_prefix,
        seller_city,
        seller_state,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
