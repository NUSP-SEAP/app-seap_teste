from django.urls import path
from . import views

urlpatterns = [
    # Login / sessão / whoami
    path("login", views.login_view, name="login"),
    path("whoami", views.whoami_view, name="whoami"),
    # Guard server-side para páginas HTML (usado pelo Nginx auth_request)
    path(
        "auth/html-guard",
        views.html_guard_view,
        name="auth_html_guard",
    ),

    # Lookups (uso direto e via /api/)
    path("forms/lookup/operadores", views.lookup_operadores, name="lookup_operadores"),
    path("forms/lookup/salas", views.lookup_salas, name="lookup_salas"),
    path(
        "forms/lookup/registro-operacao",
        views.lookup_registro_operacao_view,
        name="lookup_registro_operacao",
    ),
    path(
        "forms/lookup/comissoes",
        views.comissoes_lookup_view,
        name="lookups-comissoes",
    ),

    # Admin
    path("admin/operadores/novo", views.admin.admin_operador_novo, name="admin_operador_novo"),
    path("admin/admins/novo", views.admin.admin_administrador_novo, name="admin_administrador_novo"),
    path(
        "admin/dashboard/operadores",
        views.admin.dashboard_operadores_view,
        name="admin_dashboard_operadores"
    ),
    path(
        "admin/dashboard/checklists",
        views.admin.dashboard_checklists_view,
        name="admin_dashboard_checklists"
    ),
    path(
        "admin/dashboard/operacoes",
        views.admin.dashboard_operacoes_view,
        name="admin_dashboard_operacoes"
    ),
    path("admin/dashboard/operadores/relatorio",
        views.admin.dashboard_operadores_relatorio_view,
        name="dashboard_operadores_relatorio"
    ),
    path("admin/dashboard/checklists/relatorio",
        views.admin.dashboard_checklists_relatorio_view,
        name="dashboard_checklists_relatorio"
    ),
    path("admin/dashboard/anormalidades/lista/relatorio",
        views.admin.dashboard_anormalidades_relatorio_view, 
        name="dashboard_anormalidades_relatorio"
    ),
    path(
        "admin/dashboard/operacoes/relatorio",
        views.admin.dashboard_operacoes_relatorio_view,
        name="dashboard_operacoes_relatorio"
    ),
    path(
        "admin/dashboard/operacoes/entradas/relatorio",
        views.admin.dashboard_operacoes_entradas_relatorio_view,
        name="dashboard_operacoes_entradas_relatorio"
    ),
    path(
        "admin/operacao/detalhe",
        views.admin.operacao_detalhe_view,
        name="admin_operacao_detalhe"
    ),
    path("admin/operacoes/rds/anos", views.admin.rds_anos_view, name="admin_rds_anos"),
    path("admin/operacoes/rds/meses", views.admin.rds_meses_view, name="admin_rds_meses"),
    path("admin/operacoes/rds/gerar", views.admin.rds_gerar_view, name="admin_rds_gerar"),
    path(
        "admin/checklist/detalhe",
        views.admin.checklist_detalhe_view,
        name="admin_checklist_detalhe"
    ),

     # Dashboard - Anormalidades
    path(
        "admin/dashboard/anormalidades/salas",
        views.admin.dashboard_anormalidades_salas_view,
        name="admin_dashboard_anormalidades_salas"
    ),
    path(
        "admin/dashboard/anormalidades/lista",
        views.admin.dashboard_anormalidades_lista_view,
        name="admin_dashboard_anormalidades_lista"
    ),
    path(
        "admin/dashboard/operacoes/entradas",
        views.admin.dashboard_operacoes_entradas_view,
        name="admin_dashboard_operacoes_entradas",
    ),
    path(
        "admin/anormalidade/detalhe",
        views.admin.anormalidade_detalhe_view,
        name="admin_anormalidade_detalhe"
    ),
    path(
        "admin/anormalidade/observacao-supervisor",
        views.admin.anormalidade_observacao_supervisor_view,
        name="admin_anormalidade_observacao_supervisor",
    ),
    path(
        "admin/anormalidade/observacao-chefe",
        views.admin.anormalidade_observacao_chefe_view,
        name="admin_anormalidade_observacao_chefe",
    ),
    path(
        "admin/form-edit/<str:entidade>/list",
        views.admin.form_edit_list_view,
        name="admin_form_edit_list",
    ),
    path(
        "admin/form-edit/<str:entidade>/save",
        views.admin.form_edit_save_view,
        name="admin_form_edit_save",
    ),
    # Configuração de Itens por Sala
    path(
        "admin/form-edit/sala-config/<str:sala_id>/list",
        views.admin.sala_config_list_view,
        name="admin_sala_config_list",
    ),
    path(
        "admin/form-edit/sala-config/<str:sala_id>/save",
        views.admin.sala_config_save_view,
        name="admin_sala_config_save",
    ),
    path(
        "admin/form-edit/sala-config/aplicar-todas",
        views.admin.sala_config_aplicar_todas_view,
        name="admin_sala_config_aplicar_todas",
    ),
    # Registro de Operação de Áudio (form original)
    path(
        "operacao/registro",
        views.registro_operacao_audio_view,
        name="registro_operacao_audio",
    ),

    # -----------------------------
    # Novo conjunto de endpoints JSON da Operação de Áudio
    # -----------------------------

    # 1) Estado da sessão de operação de áudio (sala + operador)
    path(
        "operacao/audio/estado-sessao",
        views.estado_sessao_operacao_audio_view,
        name="operacao_audio_estado_sessao",
    ),

    # 2) Salvar entrada de operação (criação/edição)
    path(
        "operacao/audio/salvar-entrada",
        views.salvar_entrada_operacao_audio_view,
        name="operacao_audio_salvar_entrada",
    ),

    # 3) Finalizar sessão da operação de áudio da sala
    path(
        "operacao/audio/finalizar-sessao",
        views.finalizar_sessao_operacao_audio_view,
        name="operacao_audio_finalizar_sessao",
    ),

    # 4) Editar entrada existente (tela de detalhe)
    path(
        "operacao/audio/editar-entrada",
        views.entrada_operacao_editar_view,
        name="operacao_audio_editar_entrada",
    ),

    # Checklist – Testes Diários
    path(
        "forms/checklist/registro",
        views.checklist_registro_view,
        name="forms_checklist_registro",
    ),

    # Registro de Anormalidade na Operação de Áudio
    path(
        "operacao/anormalidade/registro",
        views.registro_anormalidade_view,
        name="operacao_registro_anormalidade",
    ),
    path(
        "forms/checklist/itens-tipo",
        views.checklist_itens_tipo_view,
        name="forms_checklist_itens_tipo",
    ),
    path(
        "forms/checklist/editar",
        views.checklist_editar_view,
        name="forms_checklist_editar",
    ),
    # --- Operador Dashboard (Meus Registros) ---
    path(
        "operador/meus-checklists",
        views.operador_dashboard.meus_checklists_view,
        name="operador_meus_checklists",
    ),
    path(
        "operador/meus-checklists/relatorio",
        views.operador_dashboard.meus_checklists_relatorio_view,
        name="operador_meus_checklists_relatorio",
    ),
    path(
        "operador/checklist/detalhe",
        views.operador_dashboard.meu_checklist_detalhe_view,
        name="operador_checklist_detalhe",
    ),
    path(
        "operador/minhas-operacoes",
        views.operador_dashboard.minhas_operacoes_view,
        name="operador_minhas_operacoes",
    ),
    path(
        "operador/minhas-operacoes/relatorio",
        views.operador_dashboard.minhas_operacoes_relatorio_view,
        name="operador_minhas_operacoes_relatorio",
    ),
    path(
        "operador/operacao/detalhe",
        views.operador_dashboard.minha_operacao_detalhe_view,
        name="operador_operacao_detalhe",
    ),
    path(
        "operador/anormalidade/detalhe",
        views.operador_dashboard.minha_anormalidade_detalhe_view,
        name="operador_anormalidade_detalhe",
    ),

    # Refresh token (renova JWT de sessão ativa)
    path("auth/refresh", views.refresh_view, name="auth_refresh"),

    # Logout
    path("auth/logout", views.logout_view, name="logout"),
]