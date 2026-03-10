// Ponto de entrada: Inicialização e Event Listeners

import { ensureHojeEmDataOperacao } from './utils.js';
import { globalState } from './state.js';
import { loadSalas, loadOperadores, loadComissoes } from './lookups.js';
import {
    setupOperatorsUI,
    bindTipoEventoLogic,
    resetFormMantendoSalaETipo,
    aplicarEstadoSessaoNaUI,
    atualizarVisibilidadeTipoPorSala,
    aplicarRegrasEventoEncerrado
} from './ui.js';
import {
    carregarEstadoSessao,
    entrarModoEdicaoEntrada,
    cancelarEdicaoEntrada,
    salvarEntrada,
} from './actions.js';

document.addEventListener("DOMContentLoaded", async function () {

    // =========================================================================
    // 1. Mapeamento de Elementos do DOM (Objeto Central)
    // =========================================================================
    const elements = {
        form: document.getElementById("form-roa"),

        // Inputs Principais
        salaSelect: document.getElementById("sala_id"),
        dataOperacaoInput: document.getElementById("data_operacao"),
        horarioPautaInput: document.getElementById("horario_pauta"),
        horaInicioInput: document.getElementById("hora_inicio"),
        horaFimInput: document.getElementById("hora_fim"),
        horaEntradaInput: document.getElementById("hora_entrada"),
        horaSaidaInput: document.getElementById("hora_saida"),
        nomeEventoInput: document.getElementById("nome_evento"),
        usb01Input: document.getElementById("usb_01"),
        usb02Input: document.getElementById("usb_02"),
        observacoesInput: document.getElementById("observacoes"),
        comissaoSelect: document.getElementById("comissao_id"),
        responsavelEventoInput: document.getElementById("responsavel_evento"),

        // Operadores
        operador1Select: document.getElementById("operador_1"),
        operador2Select: document.getElementById("operador_2"),
        operador3Select: document.getElementById("operador_3"),

        // Botões
        btnVoltar: document.getElementById("btnVoltar"),
        btnCancelarEdicao: document.getElementById("btnCancelarEdicao"),
        btnLimpar: document.getElementById("btnLimpar"),
        btnSalvarRegistro: document.getElementById("btnSalvarRegistro"),
        btnSalvarEdicao: document.getElementById("btnSalvarEdicao"),
        btnEditarEntrada1: document.getElementById("btnEditarEntrada1"),
        btnEditarEntrada2: document.getElementById("btnEditarEntrada2"),

        // Botões de Controle de Operadores (UI)
        btnAddTop: document.getElementById("btn-add-top"),
        btnAddTopLegend: document.getElementById("btn-add-top-legend"),
        btnAddOp2: document.getElementById("btn-add-op-2"),
        btnRemoveOp2: document.getElementById("btn-remove-op-2"),

        // Seções e Elementos de Layout
        sectionAnormalidade: document.getElementById("section-anormalidade"),
        headerOperadores: document.getElementById("info-operadores-sessao"),
        modoEdicaoInfo: document.getElementById("info-modo-edicao"),
        row2: document.getElementById("op-row-2"),
        row3: document.getElementById("op-row-3"),
        divTipoComissao: document.getElementById("div-tipo-comissao")
    };

    // =========================================================================
    // 2. Configuração de Eventos Globais (Page Lifecycle)
    // =========================================================================

    // Corrige estado dos botões ao voltar do histórico (ex: RAOA)
    window.addEventListener("pageshow", function () {
        if (elements.btnSalvarEdicao && elements.btnSalvarEdicao.textContent.trim() === "Salvando...") {
            elements.btnSalvarEdicao.disabled = false;
            elements.btnSalvarEdicao.textContent = "Salvar Edição";
        }
        if (elements.btnSalvarRegistro && elements.btnSalvarRegistro.textContent.trim() === "Salvando...") {
            elements.btnSalvarRegistro.disabled = false;
            elements.btnSalvarRegistro.textContent = "Salvar registro";
        }
        if (elements.salaSelect && elements.salaSelect.value) {
            carregarEstadoSessao(elements.salaSelect.value, elements);
        }
    });

    // Impede submit padrão do form
    if (elements.form) {
        elements.form.addEventListener("submit", (ev) => ev.preventDefault());
    }

    // Botão Voltar
    if (elements.btnVoltar) {
        elements.btnVoltar.addEventListener("click", function () {
            if (window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = "/";
            }
        });
    }

    // =========================================================================
    // 3. Binding de Ações (Botões Principais)
    // =========================================================================

    if (elements.btnEditarEntrada1) {
        elements.btnEditarEntrada1.addEventListener("click", () => entrarModoEdicaoEntrada(1, elements));
    }

    if (elements.btnEditarEntrada2) {
        elements.btnEditarEntrada2.addEventListener("click", () => entrarModoEdicaoEntrada(2, elements));
    }

    if (elements.btnCancelarEdicao) {
        elements.btnCancelarEdicao.addEventListener("click", () => cancelarEdicaoEntrada(elements));
    }

    if (elements.btnLimpar) {
        elements.btnLimpar.addEventListener("click", () => resetFormMantendoSalaETipo(elements));
    }

    if (elements.btnSalvarRegistro) {
        elements.btnSalvarRegistro.addEventListener("click", () => salvarEntrada("criacao", elements));
    }

    if (elements.btnSalvarEdicao) {
        elements.btnSalvarEdicao.addEventListener("click", () => salvarEntrada("edicao", elements));
    }

    // =========================================================================
    // 4. Lógica de UI e Lookups
    // =========================================================================

    // Sync em tempo real: Evento Encerrado + Horários da Operação
    function syncEventoEncerrado() {
        aplicarRegrasEventoEncerrado(elements, globalState.uiState.sessaoAberta);
    }

    document.querySelectorAll('input[name="evento_encerrado"]').forEach(function (r) {
        r.addEventListener("change", syncEventoEncerrado);
    });

    if (elements.horaInicioInput) {
        elements.horaInicioInput.addEventListener("input", syncEventoEncerrado);
    }
    if (elements.horaFimInput) {
        elements.horaFimInput.addEventListener("input", syncEventoEncerrado);
    }

    // Data padrão
    ensureHojeEmDataOperacao(elements.dataOperacaoInput);

    // Configura botões de adicionar/remover operadores
    setupOperatorsUI(elements);

    // Lógica de mudança de tipo de evento (Rádios e Dropdowns)
    // Passamos uma callback para carregarEstadoSessao caso a sala mude implicitamente
    bindTipoEventoLogic(elements.salaSelect, elements.sectionAnormalidade, (salaId) => {
        carregarEstadoSessao(salaId, elements);
    });

    // Carregamento de dados iniciais
    await Promise.all([
        loadSalas(elements.salaSelect),
        loadOperadores(elements.operador1Select, elements.operador2Select, elements.operador3Select),
        loadComissoes(elements.comissaoSelect, elements.salaSelect)
    ]);

    // =========================================================================
    // 5. Lógica da Seleção de Sala (Principal Trigger)
    // =========================================================================

    if (elements.salaSelect) {
        // Habilita caso tenha vindo desabilitado
        if (!elements.salaSelect.disabled) elements.salaSelect.disabled = false;

        // Verifica Query String (sala_id)
        const params = new URLSearchParams(window.location.search || "");
        const salaFromQuery = params.get("sala_id");
        if (salaFromQuery) {
            elements.salaSelect.value = salaFromQuery;
        }

        // Listener de mudança de sala
        elements.salaSelect.addEventListener("change", function () {
            const val = elements.salaSelect.value;
            globalState.modoEdicaoEntradaSeq = null; // Reseta modo edição ao trocar sala

            resetFormMantendoSalaETipo(elements);

            if (!val) {
                // Sala vazia -> Limpa estado
                globalState.estadoSessao = null;
                globalState.uiState.situacao_operador = "sem_sessao";
                globalState.uiState.sessaoAberta = false;

                aplicarEstadoSessaoNaUI(elements, globalState);
                atualizarVisibilidadeTipoPorSala(elements.salaSelect, elements.comissaoSelect);
                return;
            }

            // Atualiza visual e busca dados
            atualizarVisibilidadeTipoPorSala(elements.salaSelect, elements.comissaoSelect);
            carregarEstadoSessao(val, elements);
        });

        // Trigger inicial se já houver sala selecionada (via query string)
        if (elements.salaSelect.value) {
            await carregarEstadoSessao(elements.salaSelect.value, elements);
            atualizarVisibilidadeTipoPorSala(elements.salaSelect, elements.comissaoSelect);
        } else {
            aplicarEstadoSessaoNaUI(elements, globalState);
        }

    } else {
        // Fallback se não houver select de sala na tela
        aplicarEstadoSessaoNaUI(elements, globalState);
    }
});