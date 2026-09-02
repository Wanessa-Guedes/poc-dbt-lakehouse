# ADR 0001 — Grão do fato principal = 1 item de pedido

- **Status:** aceito (revisitar quando os marts existirem)
- **Data:** 2026-09-01

## Contexto

Marketplace estilo Olist. Quatro áreas consomem. Operações quer métricas de
entrega **por vendedor**; Growth quer mix **por categoria de produto**. Um
pedido pode conter itens de vendedores e categorias diferentes.

## Decisão

O fato principal `fct_order_items` tem grão de **1 item de pedido**
(`order_id` + `order_item_id`).

## Alternativas descartadas

- **Grão de pedido.** Mais simples, mas impossível fatiar entrega por vendedor
  ou mix por categoria — as perguntas de Operações e Growth morrem. Grão fino
  agrega para cima; o contrário não.
- **Grão de transação de pagamento.** É outro assunto (dinheiro), não o item
  físico. Vai para um fato separado (ver [ADR 0002](adr-0002-pagamentos-fato-separado.md)).

## Consequências

- **Positivas:** todas as 4 perguntas são respondíveis; `preco` e `frete` são
  aditivos nesse grão.
- **Negativas / cuidados:**
  - Métricas de pedido (`no_prazo`, `nota_review`, `dias_para_entrega`,
    `atraso_dias`) **repetem** em cada item do pedido. Regra: nunca `SUM`; usar
    `count(distinct order_id)` ou `AVG` com dedup.
  - Possível fato complementar `fct_pedidos` (grão pedido) para rollups limpos
    dessas métricas. Decisão adiada até os modelos existirem.
  - `order_id` / `order_item_id` ficam como **degenerate dimensions** no fato.

## Pendências ligadas a este ADR

1. Datas role-playing: hoje só `sk_data_compra`; faltam aprovação / entrega
   estimada / entrega real.
2. Papel da `dim_pedido` (quase uma junk/degenerate dimension depois que as
   datas viram FK).
