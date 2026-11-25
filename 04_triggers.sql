-- =====================================================================
-- 04_triggers.sql  |  Questões 12, 13, 14 e 15
-- =====================================================================
USE grao_da_serra;


-- Questão 12: trg_item_baixa_estoque
-- Ao inserir um item, tira a quantidade do estoque do produto.

DROP TRIGGER IF EXISTS trg_item_baixa_estoque;

DELIMITER $$
CREATE TRIGGER trg_item_baixa_estoque
AFTER INSERT ON item_pedido
FOR EACH ROW
BEGIN
    UPDATE produto
       SET estoque = estoque - NEW.quantidade
     WHERE id_produto = NEW.id_produto;
END$$
DELIMITER ;

-- Teste: anote o estoque do produto 9, rode e consulte de novo (deve cair 1)
-- SELECT estoque FROM produto WHERE id_produto = 9;
-- CALL sp_abrir_pedido(5, 1, @novo);
-- CALL sp_adicionar_item(@novo, 9, 1);
-- SELECT estoque FROM produto WHERE id_produto = 9;


-- Questão 13: trg_item_devolve_estoque
-- Ao remover um item, devolve a quantidade ao estoque do produto.

DROP TRIGGER IF EXISTS trg_item_devolve_estoque;

DELIMITER $$
CREATE TRIGGER trg_item_devolve_estoque
AFTER DELETE ON item_pedido
FOR EACH ROW
BEGIN
    UPDATE produto
       SET estoque = estoque + OLD.quantidade
     WHERE id_produto = OLD.id_produto;
END$$
DELIMITER ;

-- Teste: o estoque do produto 9 deve voltar ao valor anterior
-- DELETE FROM item_pedido WHERE id_pedido = @novo AND id_produto = 9;
-- SELECT estoque FROM produto WHERE id_produto = 9;


-- Questão 14: trg_produto_historico_preco
-- Registra no histórico toda alteração de preço (e só de preço).

DROP TRIGGER IF EXISTS trg_produto_historico_preco;

DELIMITER $$
CREATE TRIGGER trg_produto_historico_preco
AFTER UPDATE ON produto
FOR EACH ROW
BEGIN
    IF NEW.preco <> OLD.preco THEN
        INSERT INTO historico_preco (id_produto, preco_antigo, preco_novo, usuario)
        VALUES (NEW.id_produto, OLD.preco, NEW.preco, CURRENT_USER());
    END IF;
END$$
DELIMITER ;

-- Teste
-- CALL sp_reajustar_precos_categoria(1, 5);
-- SELECT * FROM historico_preco;
-- UPDATE produto SET estoque = 199 WHERE id_produto = 1;
-- SELECT COUNT(*) FROM historico_preco;   

-- Questão 15: trg_pedido_bloqueia_alteracao
-- Impede qualquer alteração em pedidos já PAGOS ou CANCELADOS.

DROP TRIGGER IF EXISTS trg_pedido_bloqueia_alteracao;

DELIMITER $$
CREATE TRIGGER trg_pedido_bloqueia_alteracao
BEFORE UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF OLD.status IN ('PAGO', 'CANCELADO') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pedidos pagos ou cancelados não podem ser alterados.';
    END IF;
END$$
DELIMITER ;

-- Teste
-- UPDATE pedido SET valor_total = 1 WHERE id_pedido = 1;
-- CALL sp_abrir_pedido(5, 1, @novo);
-- CALL sp_adicionar_item(@novo, 2, 1);
-- CALL sp_finalizar_pedido(@novo);
