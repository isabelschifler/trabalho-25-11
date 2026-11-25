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
  JOIN categoria c ON c.id_categoria = p.id_categoria
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
       COUNT(i.id_produto)          AS qtd_itens,
       fn_total_pedido(p.id_pedido) AS valor_bruto,
       p.desconto_percentual,
       p.valor_total
  FROM pedido p
  JOIN cliente c     ON c.id_cliente     = p.id_cliente
  JOIN funcionario f ON f.id_funcionario = p.id_funcionario
  LEFT JOIN item_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, p.data_pedido, p.status, c.nome, f.nome,
          p.desconto_percentual, p.valor_total;

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
       (p.estoque_minimo - p.estoque) AS faltam
  FROM produto p
  JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE p.ativo = TRUE
   AND p.estoque <= p.estoque_minimo;

-- Teste 
SELECT * FROM vw_produtos_para_repor;


-- Questão 11: vw_vendas_por_categoria
-- Considera só itens de pedidos PAGOS; categorias sem vendas aparecem com 0.

DROP VIEW IF EXISTS vw_vendas_por_categoria;

CREATE VIEW vw_vendas_por_categoria AS
SELECT c.nome AS categoria,
       COALESCE(SUM(v.quantidade), 0)                    AS unidades,
       COALESCE(SUM(v.quantidade * v.preco_unitario), 0) AS faturamento
  FROM categoria c
  LEFT JOIN produto p ON p.id_categoria = c.id_categoria
  LEFT JOIN (SELECT i.id_produto, i.quantidade, i.preco_unitario
               FROM item_pedido i
               JOIN pedido ped ON ped.id_pedido = i.id_pedido
              WHERE ped.status = 'PAGO') v
         ON v.id_produto = p.id_produto
 GROUP BY c.id_categoria, c.nome;

-- Teste 
SELECT * FROM vw_vendas_por_categoria;
