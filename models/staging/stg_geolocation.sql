-- stg_geolocation: 1:1 com raw.geolocation. Só renomeia, reordena e tipa.
-- Sem join, sem dedup, sem regra de negócio (isso é silver).
-- A fonte é MULTIVALORADA: várias linhas por prefixo de CEP. A redução para
-- 1 linha por prefixo (centroide ou primeira) é da silver.

with source as (
    select *
    from {{ source('olist', 'geolocation') }}
),
renamed as (
    select
    --chave (prefixo de CEP, texto)
        geolocation_zip_code_prefix,
    --coordenadas (float é ok: são medições, não entram em SUM)
        geolocation_lat,
        geolocation_lng,
    --localização
        geolocation_city,
        geolocation_state,
    --metadados da ingestão
        _loaded_at::timestamp as _loaded_at,  --normaliza fuso horário
        _source_file
    from source
)

select * from renamed
