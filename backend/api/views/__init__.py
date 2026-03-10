from .auth import login_view, whoami_view, logout_view, html_guard_view
from .operacao import (
    lookup_registro_operacao_view,
    registro_operacao_audio_view,
    estado_sessao_operacao_audio_view,
    salvar_entrada_operacao_audio_view,
    finalizar_sessao_operacao_audio_view,
    entrada_operacao_editar_view,
)
from .checklist import checklist_registro_view, checklist_itens_tipo_view, checklist_editar_view
from .anormalidade import registro_anormalidade_view
from .admin import admin_operador_novo, admin_administrador_novo, dashboard_operacoes_entradas_view
from . import operador_dashboard
from .lookup import lookup_operadores, lookup_salas, comissoes_lookup_view
