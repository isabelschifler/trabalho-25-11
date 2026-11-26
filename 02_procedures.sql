-- =====================================================================
-- 02_procedures.sql  |  Questões 4, 5, 6 e 7
-- =====================================================================
USE grao_da_serra;

-- Questão 4: sp_abrir_pedido
-- Abre um pedido e devolve o número gerado no parâmetro OUT.

DROP PROCEDURE IF EXISTS sp_abrir_pedido;

DELIMITER $$
CREATE PROCEDURE sp_abrir_pedido(
    IN  p_id_cliente     INT,  -- o in seria o paramentro de entrada, leva informação para dentro da procedure
    IN  p_id_funcionario INT,
    OUT p_id_pedido      INT -- traz uma informação de volta para quem chamou.

)
BEGIN
    INSERT INTO pedido (id_cliente, id_funcionario)  -- insere uma nova linha na tabela pedido
    VALUES (p_id_cliente, p_id_funcionario); -- diz quais colunas serão preenchidas.

-- o set vai guardar o valor no parametro e o last_insert devolve um numero automatico gerado
    SET p_id_pedido = LAST_INSERT_ID();
END$$
DELIMITER ;

-- Teste (apenas rodar o select)
CALL sp_abrir_pedido(5, 1, @novo);
SELECT @novo;
SELECT * FROM pedido WHERE id_pedido = @novo;

-- Questão 5: sp_adicionar_item
-- Valida e insere um item no pedido, usando o preço atual do produto.

DROP PROCEDURE IF EXISTS sp_adicionar_item;

DELIMITER $$
CREATE PROCEDURE sp_adicionar_item(
    IN p_id_pedido  INT,  -- o in seria o paramentro de entrada, leva informação para dentro da procedure
    IN p_id_produto INT,
    IN p_quantidade INT
)
BEGIN
    DECLARE v_status    VARCHAR(20);
    DECLARE v_ativo     BOOLEAN;
    DECLARE v_estoque   INT;
    DECLARE v_preco     DECIMAL(8,2);
    DECLARE v_ja_existe INT;

    -- 1) pedido existe e está aberto?
    SELECT status INTO v_status -- seleciona a coluna status da tabela ´pedido e guarda o valor em v status
      FROM pedido
     WHERE id_pedido = p_id_pedido; -- 	coluna da tabela item_pedido= parametro(é o valor que você passa ao chamar a função)

-- nessa linha verifica se o pedido existe
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pedido não encontrado.';
    END IF;

-- se for diferente de aberto entao da erro
    IF v_status <> 'ABERTO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível adicionar itens: o pedido não está aberto.';
    END IF;

    -- 2) produto existe e está ativo?
    SELECT ativo, estoque, preco
      INTO v_ativo, v_estoque, v_preco
      FROM produto
     WHERE id_produto = p_id_produto;

    IF v_ativo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Produto não encontrado.';
    END IF;

    IF v_ativo = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Produto fora do cardápio (inativo).';
    END IF;

    -- 3) quantidade válida?
    IF p_quantidade <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A quantidade deve ser maior que zero.';
    END IF;

    -- 4) tem estoque suficiente?
    IF v_estoque < p_quantidade THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estoque insuficiente para a quantidade pedida.';
    END IF;

    -- 5) o produto já está no pedido? 
    SELECT COUNT(*) INTO v_ja_existe
      FROM item_pedido
     WHERE id_pedido = p_id_pedido
       AND id_produto = p_id_produto;

    IF v_ja_existe > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Este produto já está no pedido. Remova o item e adicione de novo com a nova quantidade.';
    END IF;


    INSERT INTO item_pedido (id_pedido, id_produto, quantidade, preco_unitario)
    VALUES (p_id_pedido, p_id_produto, p_quantidade, v_preco);
END$$
DELIMITER ;

-- Testes 
CALL sp_adicionar_item(@novo, 2, 2);    -- deve funcionar
-- CALL sp_adicionar_item(1, 1, 1);        -- erro: pedido pago
-- CALL sp_adicionar_item(@novo, 15, 1);   -- erro: produto inativo
-- CALL sp_adicionar_item(@novo, 8, 1);    -- erro: sem estoque

-- Questão 6: sp_finalizar_pedido
-- Calcula o valor, aplica o desconto de fidelidade e marca o pedido como PAGO.
-- Depende das funções fn_total_pedido (Q1) e fn_desconto_fidelidade (Q3).

DROP PROCEDURE IF EXISTS sp_finalizar_pedido;

DELIMITER $$

CREATE PROCEDURE sp_finalizar_pedido(IN p_id_pedido INT)   -- o in seria o paramentro de entrada, leva informação para dentro da procedure
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_id_cliente INT;
    DECLARE v_bruto DECIMAL(10,2);
    DECLARE v_desconto DECIMAL(4,2);
    DECLARE v_total DECIMAL(10,2);

    SELECT status, id_cliente
    INTO v_status, v_id_cliente
    FROM pedido
    WHERE id_pedido = p_id_pedido; -- 	coluna da tabela item_pedido= parametro(é o valor que você passa ao chamar a função)

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pedido não encontrado.';

    ELSEIF v_status <> 'ABERTO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Só é possível finalizar pedidos que estão abertos.';
    ELSE
        SET v_bruto = fn_total_pedido(p_id_pedido);  -- Chama a primeira função que criei e guarda o total sem desconto em v_bruto.
        SET v_desconto = fn_desconto_fidelidade(v_id_cliente); -- Chama a segunda função para descobrir o percentual de desconto (10, 5 ou 0) do cliente.
        SET v_total = ROUND(v_bruto * (1 - v_desconto / 100), 2);  -- Calcula o total com desconto

        IF v_bruto = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível finalizar um pedido sem itens.';
        ELSE
            UPDATE pedido
            SET desconto_percentual = v_desconto,
                valor_total = v_total,
                status = 'PAGO'
            WHERE id_pedido = p_id_pedido;
        END IF;
    END IF;

END$$

DELIMITER ;

-- Testes
-- CALL sp_finalizar_pedido(10);   -- PAGO, desconto 5.00, valor_total 25.65
-- CALL sp_finalizar_pedido(9);    -- PAGO, desconto 0.00, valor_total 30.00
-- CALL sp_finalizar_pedido(10);   -- erro: já está pago

-- Questão 7: sp_reajustar_precos_categoria
-- Aplica um percentual (positivo ou negativo) aos preços de uma categoria.

USE grao_da_serra;

DROP PROCEDURE IF EXISTS sp_reajustar_precos_categoria;

DELIMITER $$

CREATE PROCEDURE sp_reajustar_precos_categoria(
    IN p_id_categoria INT,   -- o in seria o paramentro de entrada, leva informação para dentro da procedure
    IN p_percentual DECIMAL(5,2)
)
BEGIN -- verifica se a categoria existe, o valor 1 seria para ver se tem algm linha  
    IF NOT EXISTS (
        SELECT 1
        FROM categoria
        WHERE id_categoria = p_id_categoria
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Categoria não encontrada.';
    ELSEIF p_percentual <= -100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'O percentual não pode ser menor ou igual a -100.';
    ELSE
        UPDATE produto
        SET preco = ROUND(preco * (1 + p_percentual / 100), 2)  -- altera o preço dos produtos
        WHERE id_categoria = p_id_categoria; -- só os produtos da categoria informada são alterados.
    END IF;
END$$

DELIMITER ;

-- Teste
CALL sp_reajustar_precos_categoria(1, 10);

-- SELECT id_produto, nome, preco
-- FROM produto
-- WHERE id_categoria = 1;
