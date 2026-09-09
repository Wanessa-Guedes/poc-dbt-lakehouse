-- stg_product_category_name_translation: 1:1 com raw.product_category_name_translation.
-- Só renomeia, reordena e tipa. Sem join, sem dedup, sem regra de negócio.
-- Tabela de-para: categoria PT -> EN. O BOM do CSV já foi resolvido na ingestão
-- (Etapa 2), a 1ª coluna vem limpa.

with source as (
    select *
    from {{ source('olist', 'product_category_name_translation') }}
),
renamed as (
    select
        product_category_name,
        product_category_name_english,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
