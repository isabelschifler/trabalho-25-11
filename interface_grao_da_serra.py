"""
Empório & Café Grão da Serra - Interface (Questão 16)
Tecnologia: Python + Tkinter + mysql-connector-python

A interface foi feita em Python com Tkinter e se conecta diretamente ao MySQL pelo conector oficial mysql-connector-python, sem programa intermediário. Os dados de acesso (servidor localhost, porta 3307, usuário, senha e nome do banco grao_da_serra) ficam em um dicionário CONFIG no início do arquivo, e todo o acesso ao banco está concentrado em um único bloco de funções (listarCardapio(), abrirPedido(), etc.), com uma conexão reaproveitada e autocommit ligado. Para chamar uma view, a interface executa um SELECT (por exemplo, SELECT * FROM vw_cardapio) e recebe as linhas como dicionários. Para chamar uma procedure, executa um CALL (por exemplo, CALL sp_adicionar_item(pedido, produto, quantidade)); no caso da sp_abrir_pedido, que tem parâmetro OUT, o número do pedido é lido com um SELECT @novo. Quando uma procedure ou trigger interrompe a operação com SIGNAL, o conector lança uma exceção e a mensagem em português é exibida na barra de mensagens da tela.

"""
import tkinter as tk
from tkinter import ttk, messagebox
import traceback
import mysql.connector

# =====================================================================
# 1) ACESSO A DADOS (único lugar que conversa com o banco)
# =====================================================================
CONFIG = {
    "host": "127.0.0.1",
    "port": 3307,
    "user": "root",
    "password": "1234",   
    "database": "grao_da_serra",
    "charset": "utf8mb4",
}

_conexao = None


def conectar():
    """Abre a conexão (uma só, reaproveitada). autocommit grava cada comando na hora."""
    global _conexao
    if _conexao is None or not _conexao.is_connected():
        _conexao = mysql.connector.connect(**CONFIG, autocommit=True)
    return _conexao


def _consultar(sql, params=()):
    """Executa um SELECT e devolve uma lista de dicionários (nome da coluna -> valor)."""
    cur = conectar().cursor(dictionary=True)
    cur.execute(sql, params)
    linhas = cur.fetchall()
    cur.close()
    return linhas


def _executar(sql, params=()):
    """Executa um comando que não devolve linhas (CALL, DELETE)."""
    cur = conectar().cursor()
    cur.execute(sql, params)
    cur.close()


# ---- Leituras (views e tabelas) ----
def listarCardapio():
    return _consultar("SELECT * FROM vw_cardapio ORDER BY categoria, produto")


def listarClientes():
    return _consultar("SELECT id_cliente, nome FROM cliente ORDER BY nome")


def listarFuncionarios():
    return _consultar("SELECT id_funcionario, nome FROM funcionario ORDER BY nome")


def listarCategorias():
    return _consultar("SELECT id_categoria, nome FROM categoria ORDER BY nome")


def listarPedidos(status=None):
    if status:
        return _consultar("SELECT * FROM vw_pedidos_detalhados WHERE status = %s "
                          "ORDER BY id_pedido DESC", (status,))
    return _consultar("SELECT * FROM vw_pedidos_detalhados ORDER BY id_pedido DESC")


def listarItensPedido(id_pedido):
    return _consultar("SELECT i.id_produto, p.nome AS produto, i.quantidade, i.preco_unitario "
                      "FROM item_pedido i JOIN produto p ON p.id_produto = i.id_produto "
                      "WHERE i.id_pedido = %s", (id_pedido,))


def listarProdutosParaRepor():
    return _consultar("SELECT * FROM vw_produtos_para_repor")


def listarVendasPorCategoria():
    return _consultar("SELECT * FROM vw_vendas_por_categoria")


def listarHistoricoPrecos():
    return _consultar("SELECT * FROM historico_preco ORDER BY id_historico DESC")


# ---- Operações (procedures) ----
def abrirPedido(id_cliente, id_funcionario):
    """CALL sp_abrir_pedido com parâmetro OUT (@novo) e devolve o número do pedido."""
    cur = conectar().cursor()
    cur.execute("CALL sp_abrir_pedido(%s, %s, @novo)", (id_cliente, id_funcionario))
    cur.execute("SELECT @novo")
    numero = cur.fetchone()[0]
    cur.close()
    return numero


def adicionarItem(id_pedido, id_produto, quantidade):
    _executar("CALL sp_adicionar_item(%s, %s, %s)", (id_pedido, id_produto, quantidade))


def removerItem(id_pedido, id_produto):
    _executar("DELETE FROM item_pedido WHERE id_pedido = %s AND id_produto = %s",
              (id_pedido, id_produto))


def finalizarPedido(id_pedido):
    _executar("CALL sp_finalizar_pedido(%s)", (id_pedido,))
    return _consultar("SELECT desconto_percentual, valor_total FROM pedido "
                      "WHERE id_pedido = %s", (id_pedido,))[0]


def reajustarPrecos(id_categoria, percentual):
    _executar("CALL sp_reajustar_precos_categoria(%s, %s)", (id_categoria, percentual))


# =====================================================================
# 2) INTERFACE
# =====================================================================
# Paleta: verde-sálvia, creme e laranja
CREME = "#FBF3E4"
CREME_CARD = "#FFF9EE"
SALVIA = "#A9BFA5"
SALVIA_CLARO = "#DCE7D6"
VERDE = "#4E6F52"
VERDE_ESCURO = "#34503A"
LARANJA = "#E8803F"
LARANJA_ESC = "#CF6D2F"
TEXTO = "#2E3A2F"


def dinheiro(valor):
    return f"R$ {float(valor):.2f}".replace(".", ",")


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Empório & Café Grão da Serra")
        self.geometry("1000x720")
        self.minsize(900, 600)
        self._popup_mostrado = False
        self.configure(bg=CREME)
        self.pedido_atual = None
        self.mapa_produtos = {}

        estilo = ttk.Style(self)
        estilo.theme_use("clam")
        estilo.configure(".", background=CREME, foreground=TEXTO, font=("Segoe UI", 10))
        estilo.configure("TFrame", background=CREME)
        estilo.configure("TLabel", background=CREME, foreground=TEXTO)
        estilo.configure("TNotebook", background=CREME, borderwidth=0)
        estilo.configure("TNotebook.Tab", padding=(18, 9), font=("Segoe UI", 11, "bold"),
                         background=SALVIA_CLARO, foreground=VERDE)
        estilo.map("TNotebook.Tab", background=[("selected", VERDE)],
                   foreground=[("selected", "white")])
        estilo.configure("Treeview", rowheight=28, font=("Segoe UI", 10),
                         background=CREME_CARD, fieldbackground=CREME_CARD, foreground=TEXTO,
                         bordercolor=SALVIA, lightcolor=SALVIA, darkcolor=SALVIA)
        estilo.map("Treeview", background=[("selected", SALVIA)],
                   foreground=[("selected", VERDE_ESCURO)])
        estilo.configure("Treeview.Heading", font=("Segoe UI", 10, "bold"),
                         background=VERDE, foreground="white", relief="flat")
        estilo.map("Treeview.Heading", background=[("active", VERDE_ESCURO)])
        estilo.configure("TButton", font=("Segoe UI", 10, "bold"), padding=(14, 7),
                         background=LARANJA, foreground="white", borderwidth=0)
        estilo.map("TButton", background=[("active", LARANJA_ESC)])
        estilo.configure("TCombobox", fieldbackground=CREME_CARD, background=SALVIA_CLARO)
        estilo.configure("TEntry", fieldbackground=CREME_CARD)
        estilo.configure("TSpinbox", fieldbackground=CREME_CARD)

        # Mensagens do sistema (erros das procedures/triggers aparecem aqui)
        self.msg = tk.Label(self, text="Pronto.", anchor="w", font=("Segoe UI", 11, "bold"),
                            bg=SALVIA_CLARO, fg=VERDE_ESCURO, padx=14, pady=9)
        self.msg.pack(side="bottom", fill="x")

        # Cabeçalho
        topo = tk.Frame(self, bg=SALVIA)
        topo.pack(side="top", fill="x")
        tk.Label(topo, text="🌿 Grão da Serra", bg=SALVIA, fg=VERDE_ESCURO,
                 font=("Georgia", 20, "bold"), padx=18, pady=10).pack(side="left")
        tk.Label(topo, text="Empório & Café  ·  sistema de pedidos", bg=SALVIA, fg=VERDE,
                 font=("Segoe UI", 11)).pack(side="left")

        abas = ttk.Notebook(self)
        abas.pack(fill="both", expand=True, padx=8, pady=8)
        self.aba_cardapio = ttk.Frame(abas)
        self.aba_pedido = ttk.Frame(abas)
        self.aba_pedidos = ttk.Frame(abas)
        self.aba_gerencia = ttk.Frame(abas)
        abas.add(self.aba_cardapio, text="Cardápio")
        abas.add(self.aba_pedido, text="Novo pedido")
        abas.add(self.aba_pedidos, text="Pedidos")
        abas.add(self.aba_gerencia, text="Gerência")

        self.montar_cardapio()
        self.montar_novo_pedido()
        self.montar_pedidos()
        self.montar_gerencia()
        try:
            self.carregar_listas_fixas()
        except Exception as e:
            self.erro_grave(e)
        self.recarregar()

    # ---------- utilitários ----------
    def mostrar(self, texto, erro=False):
        self.msg.config(text=texto, bg="#F9DDD2" if erro else SALVIA_CLARO,
                        fg="#B5472A" if erro else VERDE_ESCURO)

    def erro_grave(self, e):
        """Mostra o erro na barra, no terminal e (uma vez) em uma janelinha."""
        texto = getattr(e, "msg", None) or str(e)
        self.mostrar(texto, erro=True)
        traceback.print_exc()
        if not self._popup_mostrado:
            self._popup_mostrado = True
            messagebox.showerror("Erro ao falar com o banco", texto)

    def tentar(self, funcao, ok=None):
        """Executa uma operação do banco; mostra o erro (SIGNAL) na barra de mensagens."""
        try:
            resultado = funcao()
            if ok:
                self.mostrar(ok)
            return True, resultado
        except mysql.connector.Error as e:
            self.mostrar(e.msg or str(e), erro=True)
            return False, None
        except Exception as e:
            self.erro_grave(e)
            return False, None

    def criar_tree(self, pai, colunas, larguras=None, com_grupo=False):
        quadro = ttk.Frame(pai)
        tree = ttk.Treeview(quadro, columns=colunas, show="tree headings" if com_grupo else "headings")
        for i, c in enumerate(colunas):
            tree.heading(c, text=c.replace("_", " ").title())
            tree.column(c, width=(larguras[i] if larguras else 110), anchor="w")
        if com_grupo:
            tree.heading("#0", text="Categoria")
            tree.column("#0", width=160)
        barra = ttk.Scrollbar(quadro, orient="vertical", command=tree.yview)
        tree.configure(yscrollcommand=barra.set)
        tree.pack(side="left", fill="both", expand=True)
        barra.pack(side="right", fill="y")
        return quadro, tree

    def preencher(self, tree, linhas, colunas):
        tree.delete(*tree.get_children())
        for l in linhas:
            tree.insert("", "end", values=[l[c] for c in colunas])

    # ---------- Tela 1: Cardápio ----------
    def montar_cardapio(self):
        self.col_card = ["produto", "preco", "situacao"]
        quadro, self.t_card = self.criar_tree(self.aba_cardapio, self.col_card,
                                              [320, 110, 130], com_grupo=True)
        quadro.pack(fill="both", expand=True, padx=8, pady=8)
        self.t_card.tag_configure("esgotado", foreground="#A8A8A0")
        self.t_card.tag_configure("repor", foreground=LARANJA_ESC)
        ttk.Label(self.aba_cardapio, text="Cinza = esgotado  |  Laranja = estoque baixo (repor)"
                  ).pack(pady=(0, 8))

    def carregar_cardapio(self):
        self.t_card.delete(*self.t_card.get_children())
        grupos = {}
        for l in listarCardapio():
            if l["categoria"] not in grupos:
                grupos[l["categoria"]] = self.t_card.insert("", "end", text=l["categoria"], open=True)
            tag = {"ESGOTADO": "esgotado", "REPOR": "repor"}.get(l["situacao"], "")
            self.t_card.insert(grupos[l["categoria"]], "end", tags=(tag,),
                               values=(l["produto"], dinheiro(l["preco"]), l["situacao"]))

    # ---------- Tela 2: Novo pedido ----------
    def montar_novo_pedido(self):
        f = ttk.Frame(self.aba_pedido)
        f.pack(fill="both", expand=True, padx=12, pady=12)

        linha1 = ttk.Frame(f)
        linha1.pack(fill="x", pady=4)
        ttk.Label(linha1, text="Cliente:").pack(side="left")
        self.cb_cliente = ttk.Combobox(linha1, state="readonly", width=28)
        self.cb_cliente.pack(side="left", padx=6)
        ttk.Label(linha1, text="Atendente:").pack(side="left")
        self.cb_func = ttk.Combobox(linha1, state="readonly", width=22)
        self.cb_func.pack(side="left", padx=6)
        ttk.Button(linha1, text="Abrir pedido", command=self.acao_abrir).pack(side="left", padx=6)
        self.lbl_pedido = ttk.Label(f, text="Nenhum pedido aberto.", font=("Segoe UI", 12, "bold"))
        self.lbl_pedido.pack(anchor="w", pady=6)

        linha2 = ttk.Frame(f)
        linha2.pack(fill="x", pady=4)
        ttk.Label(linha2, text="Produto:").pack(side="left")
        self.cb_produto = ttk.Combobox(linha2, state="readonly", width=40)
        self.cb_produto.pack(side="left", padx=6)
        ttk.Label(linha2, text="Qtd:").pack(side="left")
        self.sp_qtd = ttk.Spinbox(linha2, from_=1, to=99, width=5)
        self.sp_qtd.set(1)
        self.sp_qtd.pack(side="left", padx=6)
        ttk.Button(linha2, text="Adicionar", command=self.acao_adicionar).pack(side="left", padx=4)
        ttk.Button(linha2, text="Remover item selecionado", command=self.acao_remover).pack(side="left", padx=4)

        self.col_itens = ["id_produto", "produto", "quantidade", "preco_unitario"]
        ttk.Button(f, text="Finalizar pedido", command=self.acao_finalizar).pack(side="bottom", anchor="e")
        quadro, self.t_itens = self.criar_tree(f, self.col_itens, [90, 300, 100, 130])
        quadro.pack(fill="both", expand=True, pady=8)

    def acao_abrir(self):
        if not self.cb_cliente.get() or not self.cb_func.get():
            self.mostrar("Escolha o cliente e o atendente.", erro=True)
            return
        cli = int(self.cb_cliente.get().split(" - ")[0])
        fun = int(self.cb_func.get().split(" - ")[0])
        ok, numero = self.tentar(lambda: abrirPedido(cli, fun))
        if ok:
            self.pedido_atual = numero
            self.lbl_pedido.config(text=f"Pedido em andamento: nº {numero}")
            self.mostrar(f"Pedido {numero} aberto.")
            self.recarregar()

    def acao_adicionar(self):
        if self.pedido_atual is None:
            self.mostrar("Abra um pedido primeiro.", erro=True)
            return
        if not self.cb_produto.get():
            self.mostrar("Escolha um produto.", erro=True)
            return
        prod = self.mapa_produtos[self.cb_produto.get()]
        try:
            qtd = int(self.sp_qtd.get())
        except ValueError:
            self.mostrar("Quantidade inválida.", erro=True)
            return
        ok, _ = self.tentar(lambda: adicionarItem(self.pedido_atual, prod, qtd), "Item adicionado.")
        self.recarregar()

    def acao_remover(self):
        sel = self.t_itens.selection()
        if self.pedido_atual is None or not sel:
            self.mostrar("Selecione um item da lista para remover.", erro=True)
            return
        id_prod = self.t_itens.item(sel[0])["values"][0]
        self.tentar(lambda: removerItem(self.pedido_atual, id_prod), "Item removido.")
        self.recarregar()

    def acao_finalizar(self):
        if self.pedido_atual is None:
            self.mostrar("Abra um pedido primeiro.", erro=True)
            return
        ok, r = self.tentar(lambda: finalizarPedido(self.pedido_atual))
        if ok:
            self.mostrar(f"Pedido {self.pedido_atual} PAGO. Desconto: {r['desconto_percentual']}% | "
                         f"Total: {dinheiro(r['valor_total'])}")
            self.pedido_atual = None
            self.lbl_pedido.config(text="Nenhum pedido aberto.")
        self.recarregar()

    def carregar_itens(self):
        if self.pedido_atual is None:
            self.t_itens.delete(*self.t_itens.get_children())
            return
        self.preencher(self.t_itens, listarItensPedido(self.pedido_atual), self.col_itens)

    # ---------- Tela 3: Pedidos ----------
    def montar_pedidos(self):
        topo = ttk.Frame(self.aba_pedidos)
        topo.pack(fill="x", padx=8, pady=8)
        ttk.Label(topo, text="Filtrar por status:").pack(side="left")
        self.cb_status = ttk.Combobox(topo, state="readonly", width=14,
                                      values=["Todos", "ABERTO", "PAGO", "CANCELADO"])
        self.cb_status.set("Todos")
        self.cb_status.pack(side="left", padx=6)
        self.cb_status.bind("<<ComboboxSelected>>", lambda e: self.carregar_pedidos())
        self.col_ped = ["id_pedido", "data_pedido", "status", "cliente", "atendente",
                        "qtd_itens", "valor_bruto", "desconto_percentual", "valor_total"]
        quadro, self.t_ped = self.criar_tree(self.aba_pedidos, self.col_ped,
                                             [70, 140, 80, 150, 110, 70, 90, 90, 90])
        quadro.pack(fill="both", expand=True, padx=8, pady=(0, 8))

    def carregar_pedidos(self):
        st = self.cb_status.get()
        self.preencher(self.t_ped, listarPedidos(None if st == "Todos" else st), self.col_ped)

    # ---------- Tela 4: Gerência ----------
    def montar_gerencia(self):
        sub = ttk.Notebook(self.aba_gerencia)
        sub.pack(fill="both", expand=True, padx=6, pady=6)
        a1, a2, a3, a4 = (ttk.Frame(sub) for _ in range(4))
        sub.add(a1, text="Produtos para repor")
        sub.add(a2, text="Vendas por categoria")
        sub.add(a3, text="Reajuste de preços")
        sub.add(a4, text="Histórico de preços")

        self.col_repor = ["id_produto", "produto", "categoria", "estoque", "estoque_minimo", "faltam"]
        q, self.t_repor = self.criar_tree(a1, self.col_repor, [80, 250, 140, 80, 110, 80])
        q.pack(fill="both", expand=True, padx=6, pady=6)

        self.col_vend = ["categoria", "unidades", "faturamento"]
        q, self.t_vend = self.criar_tree(a2, self.col_vend, [220, 120, 140])
        q.pack(fill="both", expand=True, padx=6, pady=6)

        form = ttk.Frame(a3)
        form.pack(padx=20, pady=20, anchor="nw")
        ttk.Label(form, text="Categoria:").grid(row=0, column=0, sticky="w", pady=6)
        self.cb_cat = ttk.Combobox(form, state="readonly", width=26)
        self.cb_cat.grid(row=0, column=1, padx=8)
        ttk.Label(form, text="Percentual (%):").grid(row=1, column=0, sticky="w", pady=6)
        self.en_perc = ttk.Entry(form, width=10)
        self.en_perc.grid(row=1, column=1, sticky="w", padx=8)
        ttk.Label(form, text="Use valor negativo para reduzir (ex.: -5).").grid(row=2, column=1, sticky="w")
        ttk.Button(form, text="Aplicar reajuste", command=self.acao_reajustar).grid(row=3, column=1,
                                                                                    sticky="w", pady=12, padx=8)

        self.col_hist = ["id_historico", "id_produto", "preco_antigo", "preco_novo",
                         "data_alteracao", "usuario"]
        q, self.t_hist = self.criar_tree(a4, self.col_hist, [90, 80, 100, 100, 150, 150])
        q.pack(fill="both", expand=True, padx=6, pady=6)

    def acao_reajustar(self):
        if not self.cb_cat.get():
            self.mostrar("Escolha a categoria.", erro=True)
            return
        try:
            perc = float(self.en_perc.get().replace(",", "."))
        except ValueError:
            self.mostrar("Percentual inválido.", erro=True)
            return
        id_cat = int(self.cb_cat.get().split(" - ")[0])
        self.tentar(lambda: reajustarPrecos(id_cat, perc), "Preços reajustados.")
        self.recarregar()

    # ---------- Carga de dados ----------
    def carregar_listas_fixas(self):
        self.cb_cliente["values"] = [f"{c['id_cliente']} - {c['nome']}" for c in listarClientes()]
        self.cb_func["values"] = [f"{f['id_funcionario']} - {f['nome']}" for f in listarFuncionarios()]
        self.cb_cat["values"] = [f"{c['id_categoria']} - {c['nome']}" for c in listarCategorias()]

    def recarregar(self):
        """Recarrega tudo depois de cada operação (os triggers mudam estoque e situação)."""
        def carregar():
            self.carregar_cardapio()
            self.mapa_produtos = {}
            for l in listarCardapio():
                if l["situacao"] != "ESGOTADO":
                    rotulo = f"{l['produto']} ({dinheiro(l['preco'])})"
                    self.mapa_produtos[rotulo] = l["id_produto"]
            self.cb_produto["values"] = list(self.mapa_produtos.keys())
            self.carregar_itens()
            self.carregar_pedidos()
            self.preencher(self.t_repor, listarProdutosParaRepor(), self.col_repor)
            self.preencher(self.t_vend, listarVendasPorCategoria(), self.col_vend)
            self.preencher(self.t_hist, listarHistoricoPrecos(), self.col_hist)
        try:
            carregar()
        except Exception as e:
            self.erro_grave(e)


if __name__ == "__main__":
    App().mainloop()
