# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

POC de aprendizado: um pipeline dbt + DuckDB de ponta a ponta (medallion bronze →
silver → gold + star schema) sobre o dataset público *Olist Brazilian E-Commerce*.
O objetivo é a Wanessa **praticar modelagem dimensional e dbt** respondendo a um
desafio simulado (`docs/desafio.md`) — não é código de produção. Serve de
portfólio e preparação para entrevista.

Idioma do projeto: **português** (código, docs, commits, conversa).

## Como trabalhar aqui (importante)

- **A Wanessa escreve a implementação.** Guie **um milestone por vez**; não faça
  scaffold adiantado de arquivos/pastas que ela ainda não pediu. O papel é
  revisar, explicar o próximo passo e destravar — não entregar o projeto pronto.
- **Crítica gentil:** comece pelo que está certo; no máximo 2–3 ajustes por vez,
  não uma lista.
- **Documente conforme avança:** cada conceito novo vira uma página curta em
  `docs/tecnica/` (organizada por tópico), e cada etapa entra no
  `docs/tecnica/diario-de-bordo.md` no formato Objetivo · O que fizemos · Por quê
  · Resultado · Pendências.
- **NÃO leia os arquivos-gabarito** antes de a Wanessa fechar a versão dela:
  `docs/arquitetura-referencia.md` (marcado ⚠️ GABARITO). O brief em
  `docs/desafio.md` pode ser lido.

## Comandos

Ambiente: virtualenv em `.venv/` (Python 3.14, `dbt-duckdb`). Rodar sempre da
**raiz do repo** — é onde estão `dbt_project.yml` e `profiles.yml`.

```bash
.venv/bin/dbt debug          # valida config + conexão DuckDB
.venv/bin/dbt build          # roda models + testes + seeds + snapshots (o comando "1 comando" do desafio)
.venv/bin/dbt run            # só os models
.venv/bin/dbt test           # só os testes
.venv/bin/dbt run  --select stg_orders          # um model
.venv/bin/dbt test --select fct_order_items     # testes de um model
.venv/bin/dbt build --select staging+           # um model e tudo a jusante
.venv/bin/dbt docs generate && .venv/bin/dbt docs serve   # lineage + docs
.venv/bin/dbt clean          # apaga target/ e dbt_packages/
```

O banco inteiro é o arquivo `dev.duckdb` na raiz (gitignored). Inspecionar:
`.venv/bin/python -c "import duckdb; print(duckdb.connect('dev.duckdb').sql('show all tables'))"`.

## Arquitetura pretendida

Camadas (ver `docs/tecnica/02-camadas-e-dbt/bronze-silver-gold.md`):

| Camada | Pasta | Materialização | Regra |
|---|---|---|---|
| Bronze / staging | `models/staging/` | `view` | 1:1 com a fonte: renomear, tipar, cast de centavos→reais. **Sem join, sem regra de negócio.** |
| Silver / intermediate | `models/intermediate/` | `table` (config atual) | joins, dedup, conformidade, e **onde a regra de negócio é calculada uma vez** |
| Gold / marts | `models/marts/` | `table` | star schema; só reshape para o grão, surrogate keys, FKs |

Config por pasta fica em `dbt_project.yml` (bloco `models:`).

**Decisões de modelagem já tomadas** (ADRs em `docs/tecnica/decisoes/`):

- Grão do fato principal `fct_order_items` = **1 item de pedido**
  (`order_id` + `order_item_id`). Métricas de pedido repetem por item → nunca
  `SUM` nessas colunas.
- Pagamentos vão para um **fato separado** (não em `fct_order_items`), para não
  fazer fan-out do `payment_value`. Grão provável = transação de pagamento.
- "Pedido no prazo" é um único `CASE` na silver; todos os marts carregam a coluna
  pronta. Nunca recalcular a regra a jusante.

Problemas conhecidos dos dados e onde tratar cada um: tabela em
`docs/tecnica/02-camadas-e-dbt/bronze-silver-gold.md` (duplicata de extração,
status sobrescrito na origem → snapshot SCD2, linha suja, `customer_id` volátil →
usar `customer_unique_id`, categoria nula/em PT, múltiplos reviews, geolocation
multivalorado, BOM no CSV de tradução de categoria).

## Estado atual

Ver `docs/tecnica/diario-de-bordo.md` para o ponto exato. Resumo:

- **Etapa 1 (feita):** projeto dbt configurado, `dbt debug` verde.
- **Etapa 2 (feita):** `ingest/ingest.py` carrega os 9 CSVs em `raw.*` no
  `dev.duckdb`; `models/staging/_sources.yml` os declara como `source('olist', ...)`;
  `Makefile` (`make ingest` / `build` / `all`); `scripts/explorar.py` abre a UI
  do DuckDB.
- **Próxima — Etapa 3:** staging (`models/staging/stg_*.sql`), um por fonte.

Ainda **não existem** `models/*.sql`, `macros/`, `snapshots/`, `seeds/`, testes
nem CI.

Os 9 CSVs do Olist estão em `data/raw/` (gitignored; ~120 MB; baixados do Kaggle,
não versionados por licença/tamanho). Valores monetários estão em **reais** (não
centavos); CEP-prefixo é texto.
