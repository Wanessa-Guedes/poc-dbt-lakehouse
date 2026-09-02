# Grão e fato

## Definição

**Grão** = o que representa **uma linha** da tabela de fato. Você define em
uma frase, no nível de negócio, antes de escolher colunas:

> "Uma linha = um item dentro de um pedido."

Só depois disso você decide dimensões e métricas. Grão primeiro, sempre.

## Como escolhi na POC

As áreas pedem:

| Área | Pergunta | Nível que a pergunta vive |
|---|---|---|
| Operações | % no prazo, dias de entrega **por vendedor** | item (um pedido pode ter vários vendedores) |
| Growth | mix **por categoria de produto** | item (um pedido pode ter várias categorias) |
| Financeiro | valor pago vs valor do pedido | pedido |
| CX | nota de review vs atraso | pedido |

Duas perguntas precisam descer até o **item** → o fato principal
`fct_order_items` tem grão de item. As de pedido resolvo em um fato separado
de grão pedido (ver [adr-0002](../decisoes/adr-0002-pagamentos-fato-separado.md)).

## Regra prática

- **Grão fino agrega para cima** (item → pedido → dia). O contrário não existe:
  se o fato já nasce no grão de pedido, não dá para recuperar o vendedor do item.
- Escolha o **grão mais fino que o negócio pede**. Nem mais (tabela gigante sem
  uso), nem menos (perde perguntas).
- Todas as métricas da linha têm que fazer sentido **naquele grão**. Se uma
  métrica é "do pedido" e está numa linha de item, ela se repete — cuidado com
  `SUM` (ver [degenerate-e-junk-dimensions.md](degenerate-e-junk-dimensions.md)
  e a nota sobre medidas repetidas).

## Tipos de fato (vocabulário de entrevista)

| Tipo | O que é | Exemplo na POC |
|---|---|---|
| **Transaction** | uma linha por evento | `fct_order_items` |
| **Periodic snapshot** | foto do estado a cada período | (não uso aqui) |
| **Accumulating snapshot** | uma linha por processo, colunas de data que vão sendo preenchidas | poderia modelar o ciclo compra→aprovação→envio→entrega |

## Aditividade das métricas

| Classe | Pode somar? | Exemplo |
|---|---|---|
| Aditiva | em qualquer dimensão | `preco`, `frete` |
| Semi-aditiva | em algumas, não em tempo | saldo de estoque |
| Não-aditiva | nunca soma; use média/razão | `nota_review`, `% no prazo` |
