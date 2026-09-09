-- stg_products: 1:1 com raw.products. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- product_category_name fica como veio (PT, pode ser nulo); o join com a
-- tradução e o coalesce para 'sem_categoria' são da silver.

with source as (
    select *
    from {{ source('olist', 'products') }}
),
renamed as (
    select
    --chave
        product_id,
    --categoria (em PT, pode ser nula) -- tratamento fica na silver
        product_category_name,
    --atributos do anúncio (corrige o typo "lenght" da fonte)
        product_name_lenght        as product_name_length,
        product_description_lenght as product_description_length,
        product_photos_qty,
    --dimensões físicas
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
