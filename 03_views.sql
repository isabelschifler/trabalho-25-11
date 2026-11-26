-- =====================================================================
-- 03_views.sql  |  Questões 8, 9, 10 e 11
-- =====================================================================
USE grao_da_serra;


-- Questão 8: vw_cardapio
-- Somente produtos ativos; não mostra estoque nem estoque mínimo.

DROP VIEW IF EXISTS vw_cardapio;

CREATE VIEW vw_cardapio AS
SELECT p.id_produto, 
       c.nome                           AS categoria,
       p.nome                           AS produto,
       p.preco,
       fn_situacao_estoque(p.id_produto) AS situacao
  FROM produto p
  JOIN categoria c ON c.id_categoria = p.id_categoria   -- O JOIN junta duas tabelas.
  -- p.id_categoria: a categoria à qual o produto pertence --  c.id_categoria: o ID da categoria na tabela categoria
 WHERE p.ativo = TRUE;

-- Teste 
SELECT * FROM vw_cardapio ORDER BY categoria, produto;

-- Questão 9: vw_pedidos_detalhados
-- Uma linha por pedido; pedidos sem itens aparecem com qtd_itens = 0.

DROP VIEW IF EXISTS vw_pedidos_detalhados;

CREATE VIEW vw_pedidos_detalhados AS
SELECT p.id_pedido,
       p.data_pedido,
       p.status,
       c.nome                       AS cliente,
       f.nome                       AS atendente,
       COUNT(i.id_produto)          AS qtd_itens,  -- quantidade de linhas de item do pedido
       fn_total_pedido(p.id_pedido) AS valor_bruto, -- chama a funcao e soma o valor sem desconto
       p.desconto_percentual,    -- desconto aplicado
       p.valor_total
  FROM pedido p
  JOIN cliente c     ON c.id_cliente     = p.id_cliente -- liga o pedido ao seu cliente, para pegar o nome.
  JOIN funcionario f ON f.id_funcionario = p.id_funcionario  -- liga o pedido ao funcionário, para pegar o nome do atendente.
  LEFT JOIN item_pedido i ON i.id_pedido = p.id_pedido -- liga o pedido aos seus itens.
 GROUP BY p.id_pedido, p.data_pedido, p.status, c.nome, f.nome,
          p.desconto_percentual, p.valor_total;  -- vai juntar todas as linhas em um so pedido

-- Teste 
SELECT * FROM vw_pedidos_detalhados WHERE status = 'ABERTO';

-- Questão 10: vw_produtos_para_repor
-- Produtos ativos com estoque menor ou igual ao estoque mínimo.

DROP VIEW IF EXISTS vw_produtos_para_repor;

CREATE VIEW vw_produtos_para_repor AS
SELECT p.id_produto,
       p.nome                      AS produto,
       c.nome                      AS categoria,
       p.estoque,
       p.estoque_minimo,
       (p.estoque_minimo - p.estoque) AS faltam  -- coluna calculada: quanto falta para chegar ao mínimo
  FROM produto p
  JOIN categoria c ON c.id_categoria = p.id_categoria  -- Liga cada produto à sua categoria
 WHERE p.ativo = TRUE  -- ignora os produtos desativados
   AND p.estoque <= p.estoque_minimo;    -- que sejam iguais ou menos que o estoque minimo

-- Teste 
SELECT * FROM vw_produtos_para_repor;


-- Questão 11: vw_vendas_por_categoria
-- Considera só itens de pedidos PAGOS; categorias sem vendas aparecem com 0.

DROP VIEW IF EXISTS vw_vendas_por_categoria;

CREATE VIEW vw_vendas_por_categoria AS
SELECT c.nome AS categoria,
       COALESCE(SUM(v.quantidade), 0)                    AS unidades, -- total de unidades vendidas
       COALESCE(SUM(v.quantidade * v.preco_unitario), 0) AS faturamento  -- valor vendido: soma de quantidade × preço de cada item
  FROM categoria c 
  LEFT JOIN produto p ON p.id_categoria = c.id_categoria  -- liga cada categoria aos seus produtos. Com LEFT JOIN, uma categoria sem produtos continua aparecendo.
  LEFT JOIN (SELECT i.id_produto, i.quantidade, i.preco_unitario  -- liga cada produto às suas vendas. Com LEFT JOIN, um produto que nunca foi vendido também não some.
               FROM item_pedido i
               JOIN pedido ped ON ped.id_pedido = i.id_pedido
              WHERE ped.status = 'PAGO') v
         ON v.id_produto = p.id_produto
 GROUP BY c.id_categoria, c.nome;

-- Teste 
SELECT * FROM vw_vendas_por_categoria;
