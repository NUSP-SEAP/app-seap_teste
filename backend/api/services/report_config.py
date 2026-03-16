"""
Configurações compartilhadas entre os services de relatório (PDF e DOCX).

Cores, pesos de coluna e constantes visuais centralizadas para garantir
consistência entre formatos e facilitar manutenção.
"""

# ---------------------------------------------------------------------------
# Cores (hex)
# ---------------------------------------------------------------------------
HEADER_FILL = "#dbeafe"       # fundo do header de tabela
HEADER_DETAIL_FILL = "#bfdbfe"  # fundo do header de sub-tabela (itens/entradas)
DETAIL_BAR_FILL = "#e0f2fe"   # barra "Detalhes da Verificação" / "Entradas da Operação"
DATA_ROW_FILL = "#f8fafc"     # fundo da linha de dados principal (master/detail)
GRID_COLOR = "#cbd5e1"        # cor da grade

# Cores semânticas
COLOR_GREEN = "#16a34a"
COLOR_RED = "#dc2626"
COLOR_BLUE = "#2563eb"
COLOR_MUTED = "#64748b"
COLOR_DARK = "#0f172a"
COLOR_SLATE = "#334155"

# ---------------------------------------------------------------------------
# Pesos de coluna por relatório
# (usados para calcular larguras proporcionais)
# ---------------------------------------------------------------------------

# Operadores: Nome, E-mail
COLS_OPERADORES = [60, 40]

# Checklists (master): Local, Data, Verificado por, Inicio, Termino, Duracao, Status
COLS_CHECKLISTS_MASTER = [70, 60, 150, 45, 50, 60, 50]

# Checklists (itens): Item verificado, Status, Descricao
COLS_CHECKLISTS_ITENS = [45, 15, 40]

# Anormalidades: Data, Local, Registrado por, Descricao, Solucionada, Prejuizo, Reclamacao
COLS_ANORMALIDADES = [70, 60, 110, 170, 70, 60, 70]

# Operacoes Sessoes (master): Local, Data, 1o Registro por, Checklist?, Em Aberto?
COLS_OPERACOES_SESSOES_MASTER = [90, 60, 200, 80, 80]

# Operacoes Sessoes (entradas): No, Operador, Tipo, Evento, Pauta, Inicio, Fim, Anormalidade?
COLS_OPERACOES_SESSOES_ENTRADAS = [35, 115, 65, 165, 45, 45, 45, 55]

# Operacoes Entradas (flat): Local, Data, Operador, Tipo, Evento, Pauta, Inicio, Fim, Anormalidade?
COLS_OPERACOES_ENTRADAS = [80, 60, 110, 70, 170, 45, 45, 45, 70]

# Meus Checklists (operador): Sala, Data, Qtde. OK, Qtde. Falha
COLS_MEUS_CHECKLISTS = [180, 80, 100, 100]

# Minhas Operacoes (operador): Sala, Data, Inicio Operacao, Fim Operacao, Anormalidade?
COLS_MINHAS_OPERACOES = [150, 70, 90, 90, 80]
