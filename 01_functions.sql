-- =====================================================================
-- 01_functions.sql  |  Questões 1, 2 e 3
-- =====================================================================
USE grao_da_serra;

-- Questão 1: fn_total_pedido
-- Soma quantidade x preco_unitario dos itens do pedido (0 se não houver itens).

DROP FUNCTION IF EXISTS fn_total_pedido;

DELIMITER $$
CREATE FUNCTION fn_total_pedido(p_id_pedido INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);

    -- o coalsce é para quando n tiver linhas ai ele devolver 0

    SELECT COALESCE(SUM(quantidade * preco_unitario), 0)
      INTO v_total
      FROM item_pedido -- indica qual tabela ele vai consultar
     WHERE id_pedido = p_id_pedido; -- 	coluna da tabela item_pedido= parametro(é o valor que você passa ao chamar a função)

    RETURN v_total;
END$$
DELIMITER ;

-- Teste 
SELECT fn_total_pedido(1), fn_total_pedido(3), fn_total_pedido(99);

-- Questão 2: fn_situacao_estoque
-- Devolve 'ESGOTADO', 'REPOR' ou 'OK' conforme o estoque do produto.

DROP FUNCTION IF EXISTS fn_situacao_estoque;

DELIMITER $$
CREATE FUNCTION fn_situacao_estoque(p_id_produto INT)
RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    DECLARE v_estoque INT;
    DECLARE v_minimo  INT;

    SELECT estoque, estoque_minimo
      INTO v_estoque, v_minimo
      FROM produto
     WHERE id_produto = p_id_produto; -- 	coluna da tabela item_pedido= parametro(é o valor que você passa ao chamar a função)

    IF v_estoque = 0 THEN
        RETURN 'ESGOTADO';
    ELSEIF v_estoque <= v_minimo THEN
        RETURN 'REPOR';
    ELSE
        RETURN 'OK';
    END IF;
END$$
DELIMITER ;

-- Teste 
SELECT nome, estoque, estoque_minimo, fn_situacao_estoque(id_produto) FROM produto;

-- Questão 3: fn_desconto_fidelidade
-- 4 ou mais pedidos pagos = 10%; 2 ou 3 = 5%; menos de 2 = 0%.

DROP FUNCTION IF EXISTS fn_desconto_fidelidade;

CREATE FUNCTION fn_desconto_fidelidade(p_id_cliente INT)
RETURNS DECIMAL(4,2)
READS SQL DATA
RETURN (
    SELECT CASE
             WHEN COUNT(*) >= 4 THEN 10
             WHEN COUNT(*) >= 2 THEN 5
             ELSE 0
           END
      FROM pedido
     WHERE id_cliente = p_id_cliente -- 	coluna da tabela item_pedido= parametro(é o valor que você passa ao chamar a função)
       AND status = 'PAGO'
);

-- Teste 
SELECT nome, fn_desconto_fidelidade(id_cliente) FROM cliente;
