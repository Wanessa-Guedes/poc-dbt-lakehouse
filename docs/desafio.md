# Desafio simulado — Plataforma de analytics de pedidos (POC 1)

> Leia como se fosse um brief que você recebeu ao entrar no time.
> Sua entrega: um desenho de arquitetura + meia página de decisões.
> **Não** escreva código ainda. Não vou te dar a resposta — você monta.

---

## Contexto

Você entrou como engenheira de dados numa **marketplace brasileira** (modelo
Olist): conecta pequenos lojistas aos grandes marketplaces. ~100k pedidos nos
últimos 2 anos.

Hoje os dados vivem só no **banco transacional**. O time de BI puxa CSV na mão
toda segunda-feira e monta planilha. Ninguém confia nos números: cada área
calcula "pedido entregue no prazo" de um jeito diferente e os relatórios não
batem entre si.

Te pediram para montar uma base de dados analítica confiável.

## Quem pede o quê

| Área | O que quer acompanhar | Frequência |
|---|---|---|
| **Operações** | % de pedidos entregues no prazo, dias médios de entrega — por região e por vendedor | semanal, com opção de ver por dia |
| **Growth** | recompra de clientes (coorte), ticket médio, mix por categoria de produto | mensal |
| **Financeiro** | valor do pedido × valor pago, formas de pagamento, parcelamento | semanal |
| **CX** | nota de review cruzada com atraso na entrega | semanal |
| Todos | "os números têm que bater entre os relatórios" | — |

## Os dados que você recebe

Extração dos CSVs do transacional, uma pasta nova por segunda-feira. Tabelas:

- **orders** — 1 linha por pedido. Timestamps: compra, aprovação, envio,
  entrega estimada, entrega real. `status` como texto (`delivered`, `shipped`,
  `canceled`, `invoiced`, ...). **O status é sobrescrito na origem:** quando um
  pedido passa de `shipped` para `delivered`, a linha anterior deixa de existir.
- **order_items** — 1 linha por item do pedido (`order_id` + número do item).
  Preço e frete por item. Unidade monetária a confirmar (centavos? reais?). O
  mesmo produto pode aparecer repetido no pedido.
- **order_payments** — 1 linha por transação de pagamento. Um pedido pode ter
  várias (voucher + cartão, por ex.). Tem `payment_installments`, `payment_value`,
  `payment_type`.
- **order_reviews** — nota 1–5 + comentário. **Alguns pedidos têm mais de um
  review; muitos não têm nenhum.**
- **customers** — cuidado: a marketplace gera um `customer_id` **novo a cada
  pedido**; o identificador estável do cliente é `customer_unique_id`.
  CEP-prefixo, cidade, estado.
- **products** — categoria **em português**, dimensões, peso, nº de fotos.
  Categoria às vezes **nula**.
- **sellers** — CEP-prefixo, cidade, estado.
- **geolocation** — lat/long por CEP-prefixo. **Vários registros por prefixo**
  (um por ponto capturado).
- **product_category_name_translation** — categoria PT → EN.

Você também descobre, conversando com o time:

- a extração de segunda às vezes traz **linhas duplicadas** de pedidos (retry do
  job de export na origem);
- alguns pedidos têm data de entrega **anterior** à data de aprovação — sujeira;
- a carga de CSV pode chegar **atrasada ou parcial** em algum dia.

## Restrições

- **Sem verba** para data warehouse cloud agora. Roda na máquina de quem for
  usar e no CI.
- O time de BI escreve **SQL**; não sabe Spark.
- Tem que ser **reproduzível em um comando** por qualquer pessoa do time.
- Toda mudança no modelo passa por **PR revisado** e **não pode quebrar** o que
  já funciona.
- Auditoria exige: *"quero conseguir dizer quando um pedido mudou de status ao
  longo do tempo"*.

---

## O que se espera da sua proposta

Responda no desenho + texto:

1. **Camadas de transformação:** quais são, o que entra e o que sai de cada uma,
   e **onde mora a regra de negócio**.
2. **Modelo de consumo para o BI:** qual o **grão** da(s) tabela(s) de fato?
   Quais dimensões? Como o BI responde às 4 perguntas das áreas?
3. **Consistência:** como você garante que "pedido no prazo" dá **o mesmo
   número** para Operações e para CX?
4. **Tratamento de cada problema dos dados:**
   duplicata da extração · status sobrescrito · pedido sujo (entrega antes da
   aprovação) · carga atrasada/parcial · cliente com id volátil · categoria
   nula e em português · múltiplos reviews por pedido · geolocation
   multivalorado.
5. **Proteção da base:** o que roda automaticamente para um PR não quebrar
   nada? O que exatamente é verificado?
6. **Escopo:** o que você **não** vai fazer agora, de propósito.

## Formato da resposta

- **1 diagrama** — caixas e setas (à mão, mermaid, draw.io, tanto faz).
- **~meia página de decisões:** o que escolheu e por quê; o que descartou.
- **Lista de riscos / perguntas** que você levaria para as áreas **antes** de
  construir.

---

Quando terminar o desenho, me traz. Eu critico, a gente mapeia cada peça para o
conceito de dbt correspondente, e só então fazemos o scaffold na pasta que você
criou.
