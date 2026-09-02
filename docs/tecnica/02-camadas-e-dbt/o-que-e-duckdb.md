# O que é o DuckDB

## Em uma frase

Um banco de dados analítico que roda **dentro da sua máquina, como um arquivo
só**. Sem servidor, sem container, sem instalação de serviço.

A analogia: **é o SQLite do mundo analítico (OLAP)**.

| | SQLite | DuckDB |
|---|---|---|
| Formato | 1 arquivo | 1 arquivo (`dev.duckdb`) |
| Servidor | não | não |
| Otimizado para | muitas transações pequenas (OLTP) | agregações sobre muitas linhas (OLAP) |
| Armazenamento | por linha | **colunar** |

## "DuckDB é banco?" — sim

Banco não é sinônimo de servidor. Existem duas arquiteturas:

| | Cliente-servidor | Embutido (in-process) |
|---|---|---|
| Exemplos | Postgres, MySQL, Snowflake, BigQuery | SQLite, DuckDB |
| Como roda | serviço separado, sempre no ar | biblioteca dentro do seu programa |
| Dados | no servidor | num arquivo (`dev.duckdb`) ou na memória |
| Conexão | rede: host, porta, usuário, senha | abre o arquivo |
| Vários escritores simultâneos | sim | um por vez |

Os dois são bancos de verdade: SQL, planejador de query, tabelas, índices,
transações ACID. A diferença é como se instala e conecta, não a "qualidade".

O DuckDB é relacional, ACID, SQL padrão (sintaxe tipo Postgres), armazenamento
colunar. Para o dbt, o que importa é: ele fornece "um banco" para receber o SQL,
sem subir servidor. Em produção troca-se o adapter (dbt-snowflake, dbt-bigquery)
e os models continuam iguais.

## Por que serve para esta POC

O desafio pede: sem verba para DW cloud, roda na máquina de quem usa e no CI, o
time de BI escreve SQL, reproduzível em 1 comando. DuckDB entrega tudo isso:

- **grátis e embutido** — `pip install duckdb`, nada além disso;
- **rápido em analytics** — colunar, vetorizado, usa todos os cores;
- **lê arquivos direto** — `SELECT * FROM 'data/raw/olist_orders_dataset.csv'`
  funciona sem carregar nada antes; lê CSV, Parquet, JSON;
- **SQL padrão** — sintaxe próxima de Postgres.

## Como o dbt usa

O adapter `dbt-duckdb` abre o arquivo `dev.duckdb` (definido em `profiles.yml`),
manda os `CREATE VIEW` / `CREATE TABLE AS` e fecha. Tudo o que o dbt constrói
vive dentro desse arquivo.

Apagou `dev.duckdb` → estado zerado, é só rodar `dbt build` de novo. Por isso ele
está no `.gitignore`: é artefato reconstruível, não fonte.

## Limites (o que dizer numa entrevista)

- É **single-node** e **single-writer**: ótimo para POC, dev e CI; não é um DW
  multiusuário de produção.
- O caminho para produção seria trocar o adapter (dbt-snowflake, dbt-bigquery)
  mantendo os mesmos models — é esse o ponto do dbt: o SQL de transformação não
  muda, só a conexão.
