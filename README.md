# Empório & Café Grão da Serra

Exercício prático de **Banco de Dados**: functions, procedures, views e triggers em MySQL, mais uma interface em Python conectada ao banco.

A ideia central do trabalho é manter as **regras do negócio dentro do banco de dados**. Assim, qualquer sistema que se conectar a ele (a interface, um totem, um relatório) segue as mesmas regras, sem precisar reprogramá-las.

**Autoria:** Isabel Schifler
**Disciplina:** Banco de Dados | **Professora:** Wilcilene

---

## Sumário

1. [Tecnologias](#tecnologias)
2. [Estrutura do repositório](#estrutura-do-repositório)
3. [O banco de dados](#o-banco-de-dados)
4. [Objetos criados (questões 1 a 15)](#objetos-criados-questões-1-a-15)
5. [Como instalar e executar](#como-instalar-e-executar)
6. [A interface (questão 16)](#a-interface-questão-16)
7. [Como a interface se conecta ao banco](#como-a-interface-se-conecta-ao-banco)
8. [Como testar](#como-testar)
9. [Uso de IA](#uso-de-ia)

---

## Tecnologias

- **MySQL 8** (testado no MySQL 8.0 com MySQL Workbench)
- **Python 3** com **Tkinter** (já vem com o Python) para a interface
- **mysql-connector-python** (conector oficial do MySQL para Python)

## Estrutura do repositório

> Ajuste os nomes abaixo se as pastas do seu repositório forem diferentes.

```
.
├── solucoes.sql                    # Cria o banco, as tabelas e os dados de teste
├── 01_functions.sql                # Questões 1, 2 e 3
├── 02_procedures.sql               # Questões 4, 5, 6 e 7
├── 03_views.sql                    # Questões 8, 9, 10 e 11
├── 04_triggers.sql                 # Questões 12, 13, 14 e 15
├── interface_grao_da_serra.py      # Interface (questão 16)
└── README.md
```

## O banco de dados

Banco: `grao_da_serra`. Tabelas principais:

| Tabela | Para que serve |
|---|---|
| `categoria` | Agrupa os produtos (Cafés, Salgados, Doces etc.) |
| `produto` | Preço, estoque, estoque mínimo e se está ativo no cardápio |
| `cliente` | Quem compra |
| `funcionario` | Quem atende |
| `pedido` | Status (`ABERTO`, `PAGO` ou `CANCELADO`), desconto e valor total |
| `item_pedido` | Produtos de cada pedido, com quantidade e preço no momento da venda |
| `historico_preco` | Registro de cada mudança de preço de um produto |

O preço é copiado para `item_pedido.preco_unitario` de propósito: se o preço do produto mudar depois, os pedidos antigos continuam com o valor original.

## Objetos criados (questões 1 a 15)

### Functions

| Questão | Nome | O que faz |
|---|---|---|
| 1 | `fn_total_pedido(id_pedido)` | Soma quantidade × preço dos itens do pedido (0 se não houver itens) |
| 2 | `fn_situacao_estoque(id_produto)` | Devolve `ESGOTADO`, `REPOR` ou `OK` |
| 3 | `fn_desconto_fidelidade(id_cliente)` | Desconto pelo número de pedidos pagos: 4 ou mais = 10%, 2 ou 3 = 5%, menos de 2 = 0% |

### Procedures

| Questão | Nome | O que faz |
|---|---|---|
| 4 | `sp_abrir_pedido(cliente, funcionario, OUT pedido)` | Abre um pedido e devolve o número gerado |
| 5 | `sp_adicionar_item(pedido, produto, quantidade)` | Valida (pedido aberto, produto ativo, quantidade, estoque, item repetido) e insere com o preço atual |
| 6 | `sp_finalizar_pedido(pedido)` | Calcula o total, aplica o desconto de fidelidade e marca como `PAGO` |
| 7 | `sp_reajustar_precos_categoria(categoria, percentual)` | Aumenta ou reduz os preços de uma categoria |

As validações usam `SIGNAL SQLSTATE '45000'`, que interrompe a operação e devolve uma mensagem em português.

### Views

| Questão | Nome | O que mostra |
|---|---|---|
| 8 | `vw_cardapio` | Produtos ativos, sem estoque, com a situação |
| 9 | `vw_pedidos_detalhados` | Uma linha por pedido, com cliente, atendente, itens e valores |
| 10 | `vw_produtos_para_repor` | Produtos ativos com estoque menor ou igual ao mínimo |
| 11 | `vw_vendas_por_categoria` | Unidades e faturamento por categoria (só pedidos pagos) |

### Triggers

| Questão | Nome | O que faz |
|---|---|---|
| 12 | `trg_item_baixa_estoque` | Ao inserir um item, desconta o estoque |
| 13 | `trg_item_devolve_estoque` | Ao remover um item, devolve ao estoque |
| 14 | `trg_produto_historico_preco` | Registra no histórico toda mudança de preço |
| 15 | `trg_pedido_bloqueia_alteracao` | Impede alterar pedidos `PAGO` ou `CANCELADO` |

## Como instalar e executar

### 1. Criar o banco

No **MySQL Workbench**, abra cada arquivo (**File → Open SQL Script**) e execute o arquivo inteiro (clique no editor, **Ctrl + A** e depois **Ctrl + Shift + Enter**), **nesta ordem**:

1. `solucoes.sql`
2. `01_functions.sql`
3. `02_procedures.sql`
4. `03_views.sql`
5. `04_triggers.sql`

A ordem importa: as procedures e as views usam as functions.

O `solucoes.sql` apaga e recria o banco (`DROP DATABASE`). Por isso, depois de rodá-lo, é preciso rodar de novo os arquivos 01 a 04.

Para conferir se tudo foi criado, rode:

```sql
SHOW FUNCTION STATUS WHERE Db = 'grao_da_serra';              -- 3 functions
SHOW PROCEDURE STATUS WHERE Db = 'grao_da_serra';             -- 4 procedures
SHOW FULL TABLES IN grao_da_serra WHERE Table_type = 'VIEW';  -- 4 views
SHOW TRIGGERS FROM grao_da_serra;                             -- 4 triggers
```

### 2. Instalar o conector do MySQL para Python

```bash
pip install mysql-connector-python
```

### 3. Configurar a conexão

Abra `interface_grao_da_serra.py` e edite o dicionário `CONFIG` no começo do arquivo:

```python
CONFIG = {
    "host": "localhost",
    "port": 3307,                    # porta do seu MySQL (o padrão costuma ser 3306)
    "user": "root",
    "password": "SUA_SENHA_AQUI",    # senha do seu MySQL
    "database": "grao_da_serra",
    "charset": "utf8mb4",
}
```

A porta e a senha são as mesmas usadas na conexão do MySQL Workbench.

### 4. Executar a interface

```bash
python interface_grao_da_serra.py
```

No Windows, se o comando `python` não for reconhecido, use `py interface_grao_da_serra.py`.

## A interface (questão 16)

Programa de computador feito em Python com Tkinter, com quatro telas:

- **Cardápio:** lista a view `vw_cardapio` agrupada por categoria. Produto esgotado aparece em cinza e produto com estoque baixo em laranja.
- **Novo pedido:** escolhe o cliente e o atendente, abre o pedido, adiciona e remove itens e finaliza, mostrando o desconto e o valor total.
- **Pedidos:** lista a view `vw_pedidos_detalhados`, com filtro por status.
- **Gerência:** produtos para repor, vendas por categoria, reajuste de preços por categoria e histórico de preços.

A interface **não calcula nada**: totais, descontos e estoque vêm do banco. Ela só exibe dados e aciona as rotinas. As mensagens de erro das procedures e triggers aparecem em uma barra no rodapé da janela. Depois de cada operação, os dados são recarregados, porque o estoque e a situação dos produtos mudam no banco por causa dos triggers.

O visual usa uma paleta de verde-sálvia, creme e laranja.

## Como a interface se conecta ao banco

A interface foi feita em Python com Tkinter e se conecta diretamente ao MySQL pelo conector oficial `mysql-connector-python`, sem programa intermediário. Os dados de acesso (servidor `localhost`, porta 3307, usuário, senha e nome do banco `grao_da_serra`) ficam em um dicionário `CONFIG` no início do arquivo, e todo o acesso ao banco está concentrado em um único bloco de funções (`listarCardapio()`, `abrirPedido()`, etc.), com uma conexão reaproveitada e `autocommit` ligado.

Para chamar uma **view**, a interface executa um `SELECT` (por exemplo, `SELECT * FROM vw_cardapio`) e recebe as linhas como dicionários. Para chamar uma **procedure**, executa um `CALL` (por exemplo, `CALL sp_adicionar_item(pedido, produto, quantidade)`). No caso da `sp_abrir_pedido`, que tem parâmetro `OUT`, o número do pedido é lido com um `SELECT @novo` na mesma conexão.

Quando uma procedure ou trigger interrompe a operação com `SIGNAL`, o conector lança uma exceção e a mensagem em português é exibida na barra de mensagens da tela.

## Como testar

Com o banco recém-criado (`solucoes.sql` e depois os arquivos 01 a 04):

```sql
-- Abrir um pedido: deve devolver 11, com status ABERTO
CALL sp_abrir_pedido(5, 1, @novo);
SELECT @novo;
SELECT * FROM pedido WHERE id_pedido = @novo;

-- Adicionar um item (use o pedido novo)
CALL sp_adicionar_item(@novo, 2, 2);

-- Finalizar pedidos
CALL sp_finalizar_pedido(10);   -- PAGO, desconto 5.00, valor_total 25.65
CALL sp_finalizar_pedido(9);    -- PAGO, desconto 0.00, valor_total 30.00
CALL sp_finalizar_pedido(10);   -- erro: já está pago

-- Pedido pago não pode ser alterado (trigger da questão 15)
UPDATE pedido SET valor_total = 1 WHERE id_pedido = 1;   -- erro

-- Reajuste de preços e histórico (trigger da questão 14)
CALL sp_reajustar_precos_categoria(1, 10);
SELECT * FROM historico_preco;
```

Erros que a questão 5 deve devolver, cada um com sua mensagem:

```sql
CALL sp_adicionar_item(1, 1, 1);       -- pedido pago
CALL sp_adicionar_item(@novo, 15, 1);  -- produto inativo
CALL sp_adicionar_item(@novo, 8, 1);   -- produto sem estoque
```

Cada `CALL sp_abrir_pedido` cria um pedido novo, então o número aumenta a cada teste. Para voltar ao estado inicial, rode o `solucoes.sql` e depois os arquivos 01 a 04.

## Uso de IA

Conforme permitido no enunciado, uma ferramenta de IA foi usada **apenas na criação da interface** (telas, navegação e estilo). As functions, procedures, views, triggers e a conexão com o banco foram desenvolvidas pelos autores do trabalho.
