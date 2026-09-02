# Surrogate keys (chaves técnicas)

## O quê e por quê

**Chave natural**: identificador que vem da origem (`customer_unique_id`,
`product_id`).

**Surrogate key (SK)**: chave sem significado de negócio, criada por mim, que é
a PK da dimensão e o que o fato referencia (`sk_cliente`, `sk_produto`).

Por que não usar a natural direto no fato:

1. **Estabilidade** — a origem pode mudar o formato da chave natural; a SK não.
2. **Performance** — join por int/hash é mais barato que por string composta.
3. **SCD2** — com histórico, o mesmo `customer_unique_id` tem várias versões;
   cada versão precisa de uma PK distinta → só a SK resolve.
4. **Linha "desconhecido"** — `sk = -1` para FK sem match, sem depender de NULL.

## Como gerar

| Método | Prós | Contras |
|---|---|---|
| **Hash da chave natural** (`md5`/`sha256`) | determinístico entre runs, sem estado, paraleliza | chave "feia" (string 32+ chars) |
| **Sequência incremental** | chave pequena e legível | precisa de estado; muda se recarregar; ruim em paralelo |

Para dbt, o padrão é **hash**:

```sql
select
  {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }} as sk_cliente,
  ...
```

Com SCD2, inclui a coluna de versão no hash:

```sql
{{ dbt_utils.generate_surrogate_key(['product_id', 'dbt_valid_from']) }}
```

## Regra da POC

- SK por hash com `dbt_utils.generate_surrogate_key()`.
- `dim_data` é exceção: SK = a própria data em `yyyymmdd` (int), legível e útil.
- Toda dimensão tem uma linha `sk = '-1'` / `sk_data = -1` para "desconhecido".
- Teste `unique` + `not_null` na SK de toda dimensão.
