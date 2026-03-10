/**
 * app/js/config.js
 * Centraliza todas as URLs e configurações globais do sistema.
 */
const AppConfig = {
    // A URL base do seu backend (Django atrás do /webhook)
    baseURL: "http://100.126.56.9:8000",

    // Mapeamento de todos os endpoints usados no sistema
    endpoints: {
        auth: {
            login: "/webhook/login",
            logout: "/webhook/auth/logout",
            whoami: "/webhook/whoami"
        },

        admin: {
            novoOperador: "/webhook/admin/operadores/novo",
            novoAdmin: "/webhook/admin/admins/novo"
        },

        // --- NOVOS ENDPOINTS DO DASHBOARD ---
        adminDashboard: {
            operadores: "/webhook/admin/dashboard/operadores",
            operadoresRelatorio: "/webhook/admin/dashboard/operadores/relatorio",
            checklists: "/webhook/admin/dashboard/checklists",
            checklistsRelatorio: "/webhook/admin/dashboard/checklists/relatorio",
            operacoes: "/webhook/admin/dashboard/operacoes",
            operacoesRelatorio: "/webhook/admin/dashboard/operacoes/relatorio",
            operacoesEntradas: "/webhook/admin/dashboard/operacoes/entradas",
            operacoesEntradasRelatorio: "/webhook/admin/dashboard/operacoes/entradas/relatorio",
            detalheOperacao: "/webhook/admin/operacao/detalhe",
            detalheChecklist: "/webhook/admin/checklist/detalhe",
            rds: {
                anos: "/webhook/admin/operacoes/rds/anos",
                meses: "/webhook/admin/operacoes/rds/meses",
                gerar: "/webhook/admin/operacoes/rds/gerar",
            },
            // --- Novos Endpoints de Anormalidade ---
            anormalidades: {
                salas: "/webhook/admin/dashboard/anormalidades/salas",
                lista: "/webhook/admin/dashboard/anormalidades/lista",
                relatorio: "/webhook/admin/dashboard/anormalidades/lista/relatorio",
                detalhe: "/webhook/admin/anormalidade/detalhe",
                observacaoSupervisor: "/webhook/admin/anormalidade/observacao-supervisor",
                observacaoChefe: "/webhook/admin/anormalidade/observacao-chefe"
            },
            formOperacao: "/webhook/admin/form-operacao",
        },

        // Endpoints da tela "Edição de Formulários"
        formEdit: {
            // Base para:
            //   GET  /webhook/admin/form-edit/<entidade>/list
            //   POST /webhook/admin/form-edit/<entidade>/save
            base: "/webhook/admin/form-edit"
        },

        // Rotas de consulta (usadas para preencher <select>)
        lookups: {
            salas: "/webhook/forms/lookup/salas",
            operadores: "/webhook/forms/lookup/operadores",
            comissoes: "/webhook/forms/lookup/comissoes",
            registroOperacao: "/webhook/forms/lookup/registro-operacao"
        },

        // Rotas de submissão de formulários "clássicos"
        forms: {
            cessaoSala: "/webhook/forms/cessao-sala",
            checklist: "/webhook/forms/checklist/registro",
            checklistEditar: "/webhook/forms/checklist/editar",
            checklistItensTipo: "/webhook/forms/checklist/itens-tipo",
            operacao: "/webhook/operacao/registro",
            anormalidade: "/webhook/operacao/anormalidade/registro"
        },

        // Dashboard do Operador (Meus Registros)
        operadorDashboard: {
            meusChecklists: "/webhook/operador/meus-checklists",
            meusChecklistsRelatorio: "/webhook/operador/meus-checklists/relatorio",
            detalheChecklist: "/webhook/operador/checklist/detalhe",
            minhasOperacoes: "/webhook/operador/minhas-operacoes",
            minhasOperacoesRelatorio: "/webhook/operador/minhas-operacoes/relatorio",
            detalheOperacao: "/webhook/operador/operacao/detalhe",
            detalheAnormalidade: "/webhook/operador/anormalidade/detalhe",
        },

        // Novo conjunto de endpoints JSON da Operação de Áudio (Etapa 6)
        operacaoAudio: {
            // GET – estado da sessão (sala + operador)
            estadoSessao: "/webhook/operacao/audio/estado-sessao",

            // POST JSON – criar/editar entrada de operação de áudio
            salvarEntrada: "/webhook/operacao/audio/salvar-entrada",

            // PUT JSON – editar entrada existente (tela de detalhe)
            editarEntrada: "/webhook/operacao/audio/editar-entrada",
        }
    },

    /**
     * Helper para gerar URL completa.
     * Uso: AppConfig.apiUrl(AppConfig.endpoints.auth.login)
     */
    apiUrl: function (endpoint) {
        if (!endpoint) return "";
        const base = this.baseURL.replace(/\/+$/, "");
        const path = endpoint.replace(/^\/+/, "");
        return `${base}/${path}`;
    }
};

// Congela o objeto para evitar modificações acidentais
Object.freeze(AppConfig);
