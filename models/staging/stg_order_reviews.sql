-- stg_order_reviews: 1:1 com raw.order_reviews. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- Um pedido pode ter mais de um review; a agregação para 1 por pedido é da silver.

with source as (
    select *
    from {{ source('olist', 'order_reviews') }}
),
renamed as (
    select
    --chaves
        review_id,
        order_id,
    --conteúdo do review
        review_score,
        review_comment_title,
        review_comment_message,
    --datas
        review_creation_date,
        review_answer_timestamp,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
