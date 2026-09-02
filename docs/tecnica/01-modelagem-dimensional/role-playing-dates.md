# Role-playing dates

## Problema

Um pedido tem várias datas: compra, aprovação, envio, entrega estimada,
entrega real. Cada área ancora a análise numa data diferente:

- Operações: "dias de entrega **da semana passada**" → semana da **entrega real**
- Growth: "coorte de recompra" → mês da **primeira compra**
- Financeiro: "faturamento do mês" → mês da **aprovação**

Se o fato só tem `sk_data_compra`, todas as perguntas viram sobre data de compra
— errado.

## Solução: uma dimensão, vários papéis

Uma única `dim_data` física. O fato tem **vários FKs** apontando para ela:

```
fct_order_items
  ...
  sk_data_compra              -> dim_data
  sk_data_aprovacao           -> dim_data
  sk_data_entrega_estimada    -> dim_data
  sk_data_entrega_real        -> dim_data
```

No BI (ou numa view), cada FK vira uma "cópia" da dimensão com outro nome:
`dim_data_compra`, `dim_data_entrega`, etc. Isso é *role-playing*: a mesma
dimensão desempenhando papéis diferentes.

## Como fazer em dbt

Não duplica a tabela. Materializa `dim_data` uma vez e:

- **Opção A (simples):** no mart de consumo, faz N `JOIN` na mesma `dim_data`
  com aliases diferentes.
- **Opção B:** cria views finas `dim_data_compra as select * from dim_data` só
  para a ferramenta de BI enxergar nomes claros.

## `dim_data` gerada, não extraída

`dim_data` não vem do CSV. Gera com um range de datas (ex.: `2016-01-01` até
hoje + 1 ano) e deriva as colunas:

```
sk_data (yyyymmdd int)  |  data  |  ano  |  trimestre  |  mes  |  dia
dia_semana  |  is_fim_semana  |  is_dia_util  |  is_feriado_br
```

`is_dia_util` / `is_feriado_br` importam se "dias para entrega" for contado em
**dias úteis**. Decisão de negócio a confirmar — se for dias corridos, deixa
documentado e não precisa dos feriados.

## Pegadinha

Pedido não entregue → `sk_data_entrega_real` é **nulo**. Duas saídas:
1. FK nulo (o BI trata como "sem entrega").
2. Uma linha "N/A" em `dim_data` com `sk_data = -1` e todo FK nulo aponta para ela.
   Evita `LEFT JOIN` e mantém contagens consistentes. Preferível.
