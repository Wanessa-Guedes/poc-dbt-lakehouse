# ADR 0002 — Pagamentos em fato separado

- **Status:** aceito (grão a confirmar — ver Consequências)
- **Data:** 2026-09-01

## Contexto

`order_payments` tem 1 linha por **transação** de pagamento. Um pedido pode ter
várias (voucher + cartão). Financeiro quer: valor pago vs valor do pedido,
formas de pagamento, parcelamento.

Se eu juntasse pagamento no `fct_order_items` (grão de item), o `payment_value`
se repetiria em cada item e qualquer `SUM` dobraria o valor.

## Decisão

Pagamentos vivem num fato próprio, **não** no `fct_order_items`.

## Alternativas descartadas

- **Pagamento como colunas no `fct_order_items`.** Fan-out: valor de pagamento
  não tem grão de item. Descartado.
- **Dobrar as colunas de pagamento na `dim_pedido`.** Funciona para o total,
  mas mistura medida (aditiva) dentro de dimensão — anti-padrão. Aceitável só
  como atalho de POC.

## Consequências

- Preciso de uma **conformidade** entre os dois fatos: `dim_pedido` e `dim_data`
  são compartilhadas.
- Teste de reconciliação: `sum(preco + frete)` por pedido no `fct_order_items`
  ≈ `valor_itens_total` no fato de pagamento.

## Pendência: qual grão?

- **Opção A — grão pedido** (`valor_pago_total`, `valor_itens_total`,
  `tipo_pagto_dominante`, `parcelas_max`). Simples, mas **perde o mix** de
  formas de pagamento que o Financeiro pediu explicitamente.
- **Opção B — grão transação** (`order_id`, `payment_sequential`,
  `payment_type`, `payment_installments`, `payment_value`). "Mix por forma de
  pagamento" vira `group by` direto. O total do pedido vira rollup ou um
  `fct_pedidos` à parte.
- **Inclinação atual:** Opção B (grão transação), porque atende o requisito sem
  jogar informação fora.
