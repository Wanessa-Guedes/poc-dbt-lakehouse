# Degenerate e junk dimensions

## Degenerate dimension (DD)

Um identificador que você quer **manter no fato para filtrar/agrupar**, mas que
não tem atributos próprios — então não vale criar uma tabela de dimensão só
para ele.

Na POC: `order_id` e `order_item_id`. Ficam como colunas do `fct_order_items`,
sem `dim_pedido` correspondente (a menos que `dim_pedido` ganhe atributos reais
— ver abaixo). Servem para:

- `count(distinct order_id)` = número de pedidos
- rastrear uma linha de volta ao sistema de origem

Regra: DD é **coluna do fato**, não FK.

## Junk dimension

Quando você tem várias flags / enums de baixa cardinalidade soltas
(`is_presente`, `canal`, `tipo_frete`, `status`...), em vez de um monte de
colunas no fato ou uma dimensão para cada, você junta tudo numa só dimensão
"junk" com uma linha por **combinação** que aparece.

```
dim_pedido_flags
  sk_pedido_flags
  status_atual        (delivered, shipped, canceled, ...)
  tem_review          (true/false)
  multi_vendedor      (true/false)
```

Poucas dezenas de linhas, um FK só no fato.

## Aplicando na `dim_pedido` da POC

Hoje minha `dim_pedido` tem: `order_id`, `status_atual`, e 4 datas.

- As **4 datas** deveriam virar os FKs role-playing para `dim_data`
  (ver [role-playing-dates.md](role-playing-dates.md)), não colunas aqui.
- Sobra `order_id` (degenerate) + `status_atual` (enum de baixa cardinalidade).
- Ou seja: `dim_pedido` está no limite entre "não precisa existir" (só DD no
  fato) e "vira uma junk dimension" se eu adicionar outras flags de pedido.

**Decisão em aberto** — ver
[star-schema critique](../decisoes/adr-0001-grao-order-item.md).

## Medida de pedido no grão de item

`no_prazo`, `dias_para_entrega`, `nota_review` são do pedido. No
`fct_order_items` elas se **repetem** em cada item do mesmo pedido.

- Nunca `SUM`. Use `count(distinct order_id)` como denominador, ou `AVG` com
  dedup por `order_id`.
- Alternativa mais limpa: essas medidas vivem num `fct_pedidos` (grão pedido) e
  o fato de item fica só com o aditivo. Trade-off: "% no prazo por vendedor"
  precisa do grão item, então provavelmente `no_prazo` existe nos dois.
