// app/js/app/forms/operacao/index/ui.js
// Parte 1: Configuração inicial, visibilidade de seções e resets

import { ensureHojeEmDataOperacao, $$ } from './utils.js';
import { globalState, derivarSituacaoOperador, REGEX_AUDITORIO, REGEX_PLENARIO } from './state.js';

// =============================================================================
// Evento Encerrado: controla hora_fim, hora_entrada, hora_saida
// =============================================================================

export function aplicarRegrasEventoEncerrado(elements, sessaoAberta) {
    const { salaSelect, horaInicioInput, horaFimInput, horaEntradaInput, horaSaidaInput } = elements;

    // Sem sala selecionada: campos já gerenciados por aplicarBloqueioPorSala
    if (!salaSelect || !salaSelect.value) return;

    const radioEncerrado = document.querySelector('input[name="evento_encerrado"]:checked');
    const encerrado = radioEncerrado ? radioEncerrado.value === "sim" : false;

    // --- Término do evento (hora_fim): obrigatório quando encerrado, desabilitado quando não ---
    const labelHoraFim = document.querySelector('label[for="hora_fim"]');
    if (horaFimInput) {
        if (encerrado) {
            horaFimInput.disabled = false;
            horaFimInput.required = true;
            if (labelHoraFim) labelHoraFim.classList.add("required");
        } else {
            horaFimInput.disabled = true;
            horaFimInput.required = false;
            horaFimInput.value = "";
            if (labelHoraFim) labelHoraFim.classList.remove("required");
        }
    }

    // --- Início da operação (hora_entrada) ---
    // readonly quando sala não tem sessão aberta (1º operador → espelha início do evento)
    // manual quando há sessão aberta (operador subsequente pode ter entrado em horário diferente)
    const horaEntradaReadonly = !sessaoAberta;
    const labelHoraEntrada = document.querySelector('label[for="hora_entrada"]');
    if (horaEntradaInput) {
        horaEntradaInput.readOnly = horaEntradaReadonly;
        horaEntradaInput.required = !horaEntradaReadonly;
        if (labelHoraEntrada) {
            if (!horaEntradaReadonly) labelHoraEntrada.classList.add("required");
            else labelHoraEntrada.classList.remove("required");
        }
        if (horaEntradaReadonly) {
            horaEntradaInput.value = horaInicioInput ? (horaInicioInput.value || "") : "";
        }
    }

    // --- Término da operação (hora_saida) ---
    // readonly quando evento encerrado (espelha término do evento)
    // manual quando evento não encerrado (operador pode ter parado antes)
    const horaSaidaReadonly = encerrado;
    const labelHoraSaida = document.querySelector('label[for="hora_saida"]');
    if (horaSaidaInput) {
        horaSaidaInput.readOnly = horaSaidaReadonly;
        horaSaidaInput.required = !horaSaidaReadonly;
        if (labelHoraSaida) {
            if (!horaSaidaReadonly) labelHoraSaida.classList.add("required");
            else labelHoraSaida.classList.remove("required");
        }
        if (horaSaidaReadonly) {
            horaSaidaInput.value = horaFimInput ? (horaFimInput.value || "") : "";
        }
    }
}

// =============================================================================
// Helper: Setup da UI de Operadores (Linhas 2 e 3)
// =============================================================================

export function setupOperatorsUI(elements) {
    const {
        row2, row3, btnAddTop, btnAddTopLegend,
        btnAddOp2, btnRemoveOp2, operador2Select, operador3Select
    } = elements;

    // Funções internas auxiliares (closure)
    function showRow2() {
        if (!row2) return;
        row2.style.display = "grid";
        if (btnAddTop) btnAddTop.style.visibility = "hidden";
        if (btnAddTopLegend) btnAddTopLegend.style.visibility = "hidden";
    }

    function hideRow2() {
        if (!row2) return;
        row2.style.display = "none";
        if (operador2Select) operador2Select.value = "";
        hideRow3();
        if (btnAddTop) btnAddTop.style.visibility = "visible";
        if (btnAddTopLegend) btnAddTopLegend.style.visibility = "visible";
    }

    function showRow3() {
        if (!row3) return;
        row3.style.display = "grid";
    }

    function hideRow3() {
        if (!row3) return;
        row3.style.display = "none";
        if (operador3Select) operador3Select.value = "";
    }

    // Bindings locais
    if (btnAddTop) btnAddTop.addEventListener("click", showRow2);
    if (btnAddTopLegend) btnAddTopLegend.addEventListener("click", showRow2);
    if (btnAddOp2) btnAddOp2.addEventListener("click", showRow3);
    if (btnRemoveOp2) btnRemoveOp2.addEventListener("click", hideRow2);
}

// =============================================================================
// Lógica de Visibilidade: Tipo de Evento e Anormalidade
// =============================================================================

function atualizarTipoEventoUI(sectionAnormalidade) {
    // Nova regra: "Houve anormalidade?" sempre visível.
    if (!sectionAnormalidade) return;

    sectionAnormalidade.style.display = "";

    // Garante que haja sempre um valor selecionado (padrão = "não")
    const radioSelecionado = document.querySelector(
        'input[name="houve_anormalidade"]:checked'
    );
    if (!radioSelecionado) {
        const radioNao = document.querySelector(
            'input[name="houve_anormalidade"][value="nao"]'
        );
        if (radioNao) {
            radioNao.checked = true;
        }
    }
}

/**
 * Adiciona listeners aos radios de tipo_evento.
 * Recebe 'callbackCarregarSessao' para evitar dependência circular com actions.js
 */
export function bindTipoEventoLogic(salaSelect, sectionAnormalidade, callbackCarregarSessao) {
    const radios = $$('input[name="tipo_evento"]');
    radios.forEach((r) => {
        r.addEventListener("change", function () {
            const oldSala = salaSelect ? salaSelect.value : null;

            atualizarTipoEventoUI(sectionAnormalidade);

            // Se mudar para "Outros Eventos" (força Plenário) ou voltar, a sala muda.
            // Precisamos recarregar o estado da sessão da NOVA sala.
            if (salaSelect && salaSelect.value && salaSelect.value !== oldSala) {
                if (typeof callbackCarregarSessao === 'function') {
                    callbackCarregarSessao(salaSelect.value);
                }
            }
        });
    });
    atualizarTipoEventoUI(sectionAnormalidade);
}

export function atualizarVisibilidadeTipoPorSala(salaSelect, comissaoSelect) {
    if (!comissaoSelect || !salaSelect) return;

    // Container externo do bloco "Tipo"
    const divTipo = document.getElementById("div-tipo-comissao");
    const temSala = !!salaSelect.value;

    // Sem sala selecionada: esconde o bloco e limpa valor
    if (!temSala) {
        if (divTipo) divTipo.classList.add("hidden");
        comissaoSelect.value = "";
        comissaoSelect.disabled = true;
        if (comissaoSelect.dataset) {
            delete comissaoSelect.dataset.lockSessao;
        }
        return;
    }

    // Sala selecionada: decide se mostra ou não baseado em Auditório / Plenário
    const optSala = salaSelect.options[salaSelect.selectedIndex] || null;
    const textoSala = (
        (optSala && (optSala.textContent || optSala.innerText || optSala.label)) ||
        ""
    ).toLowerCase();

    const isAuditorio = REGEX_AUDITORIO.test(textoSala);
    const isPlenario = REGEX_PLENARIO.test(textoSala);

    if (isAuditorio || isPlenario) {
        // Auditório ou Plenário → "Tipo" fica oculto e desabilitado
        if (divTipo) divTipo.classList.add("hidden");
        comissaoSelect.value = "";
        comissaoSelect.disabled = true;
        if (comissaoSelect.dataset) {
            delete comissaoSelect.dataset.lockSessao;
        }
    } else {
        // Qualquer outra sala → "Tipo" é obrigatório e visível
        if (divTipo) divTipo.classList.remove("hidden");

        // Se a sessão marcou o campo como travado, mantemos o disable.
        if (comissaoSelect.dataset && comissaoSelect.dataset.lockSessao === "true") {
            comissaoSelect.disabled = true;
        } else {
            comissaoSelect.disabled = false;
        }
    }

    // O tipo_evento depende de sala + comissão, então recalculamos a UI
    const sectionAnormalidade = document.getElementById("section-anormalidade");
    atualizarTipoEventoUI(sectionAnormalidade);
}

// =============================================================================
// Resets
// =============================================================================

export function resetFormMantendoSalaETipo(elements) {
    const { form, salaSelect, comissaoSelect, dataOperacaoInput, sectionAnormalidade } = elements;
    if (!form) return;

    const salaValue = salaSelect ? salaSelect.value : "";

    form.reset();

    if (salaSelect) {
        salaSelect.value = salaValue;
    }

    ensureHojeEmDataOperacao(dataOperacaoInput);
    atualizarTipoEventoUI(sectionAnormalidade);
    atualizarVisibilidadeTipoPorSala(salaSelect, comissaoSelect);
    aplicarRegrasEventoEncerrado(elements, globalState.uiState.sessaoAberta);
}

// =============================================================================
// Cabeçalhos e Indicadores
// =============================================================================

function atualizarIndicadorModoEdicao(modoEl, estadoSessao, modoEdicaoEntradaSeq) {
    if (!modoEl) return;

    // Se não há sessão aberta, esconde o indicador
    if (!estadoSessao || !estadoSessao.existe_sessao_aberta) {
        // Espelha o comportamento do index.js original:
        // sai do modo edição quando não há sessão.
        globalState.modoEdicaoEntradaSeq = null;

        modoEl.style.display = "none";
        modoEl.textContent = "";
        return;
    }

    // Se estiver editando 1ª ou 2ª entrada, mostra no canto direito
    if (modoEdicaoEntradaSeq === 1 || modoEdicaoEntradaSeq === 2) {
        const ordinal = modoEdicaoEntradaSeq === 1 ? "1º" : "2º";
        modoEl.textContent = "Editando " + ordinal + " Registro";
        modoEl.style.display = "";
    } else {
        modoEl.textContent = "";
        modoEl.style.display = "none";
    }
}

export function atualizarCabecalhoOperadoresSessao(headerEl, modoEl, estadoSessao, modoEdicaoEntradaSeq) {
    if (!headerEl) {
        atualizarIndicadorModoEdicao(modoEl, estadoSessao, modoEdicaoEntradaSeq);
        return;
    }

    // Se não há estado carregado ou não há sessão aberta, esconde o cabeçalho
    if (!estadoSessao || !estadoSessao.existe_sessao_aberta) {
        headerEl.style.display = "none";
        headerEl.textContent = "";
        atualizarIndicadorModoEdicao(modoEl, estadoSessao, modoEdicaoEntradaSeq);
        return;
    }

    let entradas = Array.isArray(estadoSessao.entradas_sessao)
        ? estadoSessao.entradas_sessao.slice()
        : [];

    // Normaliza para array de nomes: usa entradas_sessao (com ordenação) ou fallback por strings
    let nomes;
    if (entradas.length) {
        entradas.sort((a, b) => {
            const oa = typeof a.ordem === "number" ? a.ordem : parseInt(a.ordem || a.seq || 0, 10);
            const ob = typeof b.ordem === "number" ? b.ordem : parseInt(b.ordem || b.seq || 0, 10);
            if (oa !== ob) return oa - ob;
            return (a.entrada_id || a.id || 0) - (b.entrada_id || b.id || 0);
        });
        nomes = entradas.map(e => (e && e.operador_nome) ? e.operador_nome : "—");
    } else {
        nomes = Array.isArray(estadoSessao.nomes_operadores_sessao)
            ? estadoSessao.nomes_operadores_sessao
            : [];
    }

    if (!nomes.length) {
        headerEl.style.display = "none";
        headerEl.textContent = "";
        atualizarIndicadorModoEdicao(modoEl, estadoSessao, modoEdicaoEntradaSeq);
        return;
    }

    const ordinais = { 2: "Segundo", 3: "Terceiro", 4: "Quarto", 5: "Quinto", 6: "Sexto", 7: "Sétimo", 8: "Oitavo", 9: "Nono", 10: "Décimo" };
    const linhas = ["Registro aberto por " + nomes[0] + "."];
    const descricoes = [];
    for (let i = 1; i < nomes.length; i++) {
        const posicao = i + 1;
        const prefixo = ordinais[posicao] || posicao + "º";
        descricoes.push(prefixo + " registro feito por " + nomes[i]);
    }
    for (let j = 0; j < descricoes.length; j += 2) {
        if (j + 1 < descricoes.length) {
            linhas.push(descricoes[j] + " • " + descricoes[j + 1]);
        } else {
            linhas.push(descricoes[j]);
        }
    }

    headerEl.innerHTML = linhas.join("<br>");
    headerEl.style.display = "";
    atualizarIndicadorModoEdicao(modoEl, estadoSessao, modoEdicaoEntradaSeq);
}

// =============================================================================
// Bloqueios e Estados de Campos
// =============================================================================

function aplicarBloqueioPorSala(elements) {
    const {
        form, salaSelect, comissaoSelect, btnLimpar, btnSalvarRegistro,
        btnSalvarEdicao, btnVoltar
    } = elements;

    if (!form || !salaSelect) return;
    const temSala = !!salaSelect.value;

    // 1) Campos: tudo visível, mas travado sem sala
    const campos = form.querySelectorAll("input, select, textarea");
    campos.forEach((el) => {
        if (el === salaSelect) {
            el.disabled = false;
            if ("readOnly" in el) el.readOnly = false;
            return;
        }
        const disabled = !temSala;
        el.disabled = disabled;
        if (!disabled && "readOnly" in el) {
            el.readOnly = false;
        }
    });

    // 2) Botões
    if (!temSala) {
        if (btnLimpar) { btnLimpar.style.display = "none"; btnLimpar.disabled = true; }
        if (btnSalvarRegistro) { btnSalvarRegistro.style.display = "none"; btnSalvarRegistro.disabled = true; }
        if (btnSalvarEdicao) { btnSalvarEdicao.style.display = "none"; btnSalvarEdicao.disabled = true; }
        if (btnVoltar) { btnVoltar.style.display = ""; btnVoltar.disabled = false; }
    } else {
        if (btnLimpar) { btnLimpar.style.display = ""; btnLimpar.disabled = false; }
        if (btnSalvarRegistro) { btnSalvarRegistro.style.display = ""; }
        if (btnSalvarEdicao) { btnSalvarEdicao.disabled = false; }
        if (btnVoltar) { btnVoltar.style.display = ""; btnVoltar.disabled = false; }
    }

    atualizarVisibilidadeTipoPorSala(salaSelect, comissaoSelect);
}

function aplicarModoOperadorComDuasEntradas(elements) {
    const { form, salaSelect, btnSalvarRegistro, btnSalvarEdicao, btnLimpar, btnCancelarEdicao, btnEditarEntrada1, btnEditarEntrada2 } = elements;
    if (!form) return;

    // 1) Zera todos os campos (menos sala) e trava
    const campos = form.querySelectorAll("input, textarea, select");
    campos.forEach((el) => {
        if (el === salaSelect) return;
        if (el.tagName === "SELECT") {
            el.value = "";
        } else if (el.type === "radio" || el.type === "checkbox") {
            el.checked = false;
        } else {
            el.value = "";
        }
        el.readOnly = true;
        el.disabled = true;
    });

    if (salaSelect) {
        salaSelect.disabled = false;
        salaSelect.readOnly = false;
    }

    // 2) Botões
    if (btnSalvarRegistro) btnSalvarRegistro.style.display = "none";
    if (btnSalvarEdicao) btnSalvarEdicao.style.display = "none";
    if (btnLimpar) btnLimpar.style.display = "none";
    if (btnCancelarEdicao) btnCancelarEdicao.style.display = "none";

    if (btnEditarEntrada1) { btnEditarEntrada1.style.display = ""; btnEditarEntrada1.disabled = false; }
    if (btnEditarEntrada2) { btnEditarEntrada2.style.display = ""; btnEditarEntrada2.disabled = false; }
}

export function aplicarEstadoSessaoNaUI(elements, state) {
    const {
        salaSelect, btnEditarEntrada1, btnEditarEntrada2, btnCancelarEdicao, btnSalvarRegistro,
        btnSalvarEdicao, headerOperadores, modoEdicaoInfo, sectionAnormalidade
    } = elements;

    // 0) Esconde botões de edição / cancelar por padrão
    if (btnEditarEntrada1) { btnEditarEntrada1.style.display = "none"; btnEditarEntrada1.disabled = false; }
    if (btnEditarEntrada2) { btnEditarEntrada2.style.display = "none"; btnEditarEntrada2.disabled = false; }
    if (btnCancelarEdicao) { btnCancelarEdicao.style.display = "none"; btnCancelarEdicao.disabled = false; }

    // 1) Bloqueio base por sala
    aplicarBloqueioPorSala(elements);

    // Se não há sala selecionada
    if (!salaSelect || !salaSelect.value) {
        // espelha o comportamento do index.js original
        state.estadoSessao = null;
        if (state.uiState) {
            state.uiState.situacao_operador = "sem_sessao";
            state.uiState.sessaoAberta = false;
        }

        atualizarCabecalhoOperadoresSessao(headerOperadores, modoEdicaoInfo, null, null);
        return;
    }

    const { estadoSessao } = state;

    bloquearCabecalhoSeSessaoAberta(elements, estadoSessao);
    // 2) Reset de botões base
    if (btnSalvarRegistro) {
        btnSalvarRegistro.style.display = "";
        btnSalvarRegistro.disabled = false;
        btnSalvarRegistro.textContent = "Salvar registro";
    }
    if (btnSalvarEdicao) { btnSalvarEdicao.style.display = "none"; btnSalvarEdicao.disabled = false; }

    // 3) Não há estado conhecido ainda para essa sala
    if (!estadoSessao) {
        if (state.uiState) {
            state.uiState.situacao_operador = "sem_sessao";
            state.uiState.sessaoAberta = false;
        }
        atualizarTipoEventoUI(sectionAnormalidade);
        atualizarCabecalhoOperadoresSessao(
            headerOperadores,
            modoEdicaoInfo,
            null,
            null
        );
        aplicarRegrasEventoEncerrado(elements, false);
        return;
    }

    // 4) Deriva situação do operador e se a sessão está aberta
    const situacao = derivarSituacaoOperador(estadoSessao);
    const sessaoAberta = !!estadoSessao.existe_sessao_aberta;

    if (state.uiState) { state.uiState.situacao_operador = situacao; state.uiState.sessaoAberta = sessaoAberta; }

    // Rádios de tipo sempre habilitados
    const radiosTipo = document.querySelectorAll('input[name="tipo_evento"]');
    radiosTipo.forEach((r) => { r.disabled = false; });
    atualizarTipoEventoUI(sectionAnormalidade);

    // === CASO 1: ainda NÃO existe sessão (sem_sessao) ===
    if (situacao === "sem_sessao") {
        if (btnSalvarRegistro) {
            btnSalvarRegistro.style.display = "";
            btnSalvarRegistro.disabled = false;
            btnSalvarRegistro.textContent = "Salvar registro";
        }
        if (btnSalvarEdicao) { btnSalvarEdicao.style.display = "none"; btnSalvarEdicao.disabled = false; }

        atualizarCabecalhoOperadoresSessao(
            headerOperadores,
            modoEdicaoInfo,
            estadoSessao,
            state.modoEdicaoEntradaSeq
        );
        aplicarRegrasEventoEncerrado(elements, false);
        return;
    }

    // === CASO 2: sessão existe, operador ainda sem entrada ===
    if (situacao === "sem_entrada") {
        if (btnSalvarRegistro) {
            btnSalvarRegistro.style.display = "";
            btnSalvarRegistro.disabled = false;
            btnSalvarRegistro.textContent = "Salvar registro";
        }
        if (btnSalvarEdicao) {
            btnSalvarEdicao.style.display = "none";
            btnSalvarEdicao.disabled = false;
        }
        if (btnEditarEntrada1) { btnEditarEntrada1.style.display = "none"; }
        if (btnEditarEntrada2) { btnEditarEntrada2.style.display = "none"; }

        // Regra nova:
        // - 2º operador herda os dados do 1º
        // - 3º operador herda do 2º
        // - e assim sucessivamente...
        // Sempre usando a ÚLTIMA entrada da sessão.
        // "Houve anormalidade?" NÃO é herdado.
        preencherFormularioComUltimaEntradaDaSessao(elements, estadoSessao);

        atualizarCabecalhoOperadoresSessao(
            headerOperadores,
            modoEdicaoInfo,
            estadoSessao,
            state.modoEdicaoEntradaSeq
        );
        aplicarRegrasEventoEncerrado(elements, true);
        return;
    }

    // === CASO 3: operador com 1ª entrada ===
    if (situacao === "uma_entrada") {
        if (btnSalvarRegistro) {
            btnSalvarRegistro.style.display = "";
            btnSalvarRegistro.disabled = false;
            btnSalvarRegistro.textContent = "Novo registro (2ª entrada)";
        }
        if (btnSalvarEdicao) { btnSalvarEdicao.style.display = "none"; btnSalvarEdicao.disabled = false; }

        // Verifica se a 1ª entrada está em aberto (sem horário de término)
        const entradasOp = Array.isArray(estadoSessao.entradas_operador) ? estadoSessao.entradas_operador : [];
        const entrada1 = entradasOp.find(e => e.seq === 1);
        const entrada1EmAberto = entrada1 && !entrada1.horario_termino;

        // Esconde botão de editar se a entrada está em aberto
        if (btnEditarEntrada1) {
            if (entrada1EmAberto) {
                btnEditarEntrada1.style.display = "none";
            } else {
                btnEditarEntrada1.style.display = "";
                btnEditarEntrada1.disabled = false;
            }
        }
        if (btnEditarEntrada2) { btnEditarEntrada2.style.display = "none"; }

        // Se a entrada está em aberto, pré-preenche o formulário com os dados da entrada
        // mantendo em branco: horário de término, trilhas, observações e anormalidade em "Não"
        if (entrada1EmAberto) {
            const entradaCopia = { ...entrada1 };
            delete entradaCopia.houve_anormalidade;
            delete entradaCopia.horario_termino;
            delete entradaCopia.usb_01;
            delete entradaCopia.usb_02;
            delete entradaCopia.observacoes;
            preencherFormularioComEntrada(elements, entradaCopia, estadoSessao);

            const radioNao = document.querySelector('input[name="houve_anormalidade"][value="nao"]');
            if (radioNao) radioNao.checked = true;
        }

        atualizarCabecalhoOperadoresSessao(
            headerOperadores,
            modoEdicaoInfo,
            estadoSessao,
            state.modoEdicaoEntradaSeq
        );
        aplicarRegrasEventoEncerrado(elements, true);
        return;
    }

    // === CASO 4: operador com 2 entradas ===
    if (situacao === "duas_entradas") {
        aplicarModoOperadorComDuasEntradas(elements);

        // Esconde botões de editar para entradas em aberto (sem horário de término)
        const entradasOp2 = Array.isArray(estadoSessao.entradas_operador) ? estadoSessao.entradas_operador : [];
        const ent1 = entradasOp2.find(e => e.seq === 1);
        const ent2 = entradasOp2.find(e => e.seq === 2);
        if (btnEditarEntrada1 && ent1 && !ent1.horario_termino) {
            btnEditarEntrada1.style.display = "none";
        }
        if (btnEditarEntrada2 && ent2 && !ent2.horario_termino) {
            btnEditarEntrada2.style.display = "none";
        }

        atualizarCabecalhoOperadoresSessao(
            headerOperadores,
            modoEdicaoInfo,
            estadoSessao,
            state.modoEdicaoEntradaSeq
        );
        return;
    }

    // Fallback de segurança
    atualizarCabecalhoOperadoresSessao(
        headerOperadores,
        modoEdicaoInfo,
        estadoSessao,
        state.modoEdicaoEntradaSeq
    );
}

function preencherFormularioComUltimaEntradaDaSessao(elements, estadoSessao) {
    if (!estadoSessao) return;

    const entradasSessao = Array.isArray(estadoSessao.entradas_sessao)
        ? estadoSessao.entradas_sessao
        : [];

    if (!entradasSessao || entradasSessao.length === 0) {
        return;
    }

    // Última entrada (lista já vem ordenada do backend por ordem do operador + id)
    const ultima = entradasSessao[entradasSessao.length - 1];
    if (!ultima) return;

    // Cópia superficial para não modificar o objeto em estadoSessao
    const entradaCopia = { ...ultima };

    // Campos que NÃO devem ser herdados (ficam em branco para novo preenchimento)
    delete entradaCopia.houve_anormalidade;
    delete entradaCopia.horario_termino;
    delete entradaCopia.usb_01;
    delete entradaCopia.usb_02;
    delete entradaCopia.observacoes;
    delete entradaCopia.hora_entrada;
    delete entradaCopia.hora_saida;

    preencherFormularioComEntrada(elements, entradaCopia, estadoSessao);

    // Garante "Houve anormalidade?" marcado em "Não"
    const radioNao = document.querySelector('input[name="houve_anormalidade"][value="nao"]');
    if (radioNao) radioNao.checked = true;

    // Garante "Evento Encerrado" marcado em "Sim" (padrão para novos registros)
    const radioEncSim = document.querySelector('input[name="evento_encerrado"][value="sim"]');
    if (radioEncSim) radioEncSim.checked = true;
}

// =============================================================================
// Preenchimento de Formulário
// =============================================================================

export function preencherFormularioComEntrada(elements, entrada, estadoSessao) {
    if (!entrada) return;
    const { comissaoSelect, sectionAnormalidade, salaSelect } = elements;

    // 1) Data
    const inputData = document.querySelector('input[name="data_operacao"]');
    if (inputData) {
        const dataValor = (estadoSessao && estadoSessao.data) || entrada.data_operacao || "";
        if (dataValor) inputData.value = dataValor;
    }

    // 2) Campos diretos
    const mapDiretos = {
        horario_pauta: 'input[name="horario_pauta"]',
        nome_evento: 'input[name="nome_evento"]',
        usb_01: 'input[name="usb_01"]',
        usb_02: 'input[name="usb_02"]',
        observacoes: 'textarea[name="observacoes"]',
        responsavel_evento: 'input[name="responsavel_evento"]'
    };
    Object.entries(mapDiretos).forEach(([campo, seletor]) => {
        const el = document.querySelector(seletor);
        if (el && Object.prototype.hasOwnProperty.call(entrada, campo)) {
            el.value = entrada[campo] || "";
        }
    });

    // 3) Comissao
    if (comissaoSelect && Object.prototype.hasOwnProperty.call(entrada, "comissao_id")) {
        comissaoSelect.value = entrada.comissao_id || "";
    }

    // 4) Horários
    const inputHoraInicio = document.querySelector('input[name="hora_inicio"]');
    if (inputHoraInicio && "horario_inicio" in entrada) inputHoraInicio.value = entrada.horario_inicio || "";
    const inputHoraFim = document.querySelector('input[name="hora_fim"]');
    if (inputHoraFim && "horario_termino" in entrada) inputHoraFim.value = entrada.horario_termino || "";

    // 5) Tipo Evento
    if (entrada.tipo_evento) {
        const radioTipo = document.querySelector(`input[name="tipo_evento"][value="${entrada.tipo_evento}"]`);
        if (radioTipo) radioTipo.checked = true;
    }

    // 6) Anormalidade
    if (typeof entrada.houve_anormalidade !== "undefined" && entrada.houve_anormalidade !== null) {
        const valorHouve = entrada.houve_anormalidade ? "sim" : "nao";
        const radioHouve = document.querySelector(`input[name="houve_anormalidade"][value="${valorHouve}"]`);
        if (radioHouve) radioHouve.checked = true;
    }

    // 7) Evento Encerrado: derivado de horario_termino
    const temTermino = !!(entrada.horario_termino);
    const radioEncVal = temTermino ? "sim" : "nao";
    const radioEnc = document.querySelector(`input[name="evento_encerrado"][value="${radioEncVal}"]`);
    if (radioEnc) radioEnc.checked = true;

    // 8) Horários da operação (manual: preenchidos antes de aplicarRegrasEventoEncerrado
    //    para preservar valores quando o campo é manual/editável)
    const inputHoraEntrada = document.querySelector('input[name="hora_entrada"]');
    if (inputHoraEntrada && Object.prototype.hasOwnProperty.call(entrada, "hora_entrada")) {
        inputHoraEntrada.value = entrada.hora_entrada || "";
    }
    const inputHoraSaida = document.querySelector('input[name="hora_saida"]');
    if (inputHoraSaida && Object.prototype.hasOwnProperty.call(entrada, "hora_saida")) {
        inputHoraSaida.value = entrada.hora_saida || "";
    }

    if (salaSelect && comissaoSelect) {
        atualizarVisibilidadeTipoPorSala(salaSelect, comissaoSelect);
    }
    atualizarTipoEventoUI(sectionAnormalidade);
}

function bloquearCabecalhoSeSessaoAberta(elements, estadoSessao) {
    const {
        dataOperacaoInput,
        horarioPautaInput,
        horaInicioInput,
        nomeEventoInput,
        responsavelEventoInput,
        comissaoSelect,
        salaSelect,
    } = elements;

    // Sempre garantimos que os campos básicos permaneçam editáveis.
    // O "bloqueio" pós-sessão agora só se aplica à Atividade Legislativa
    // (comissaoSelect) quando a sala NÃO é Plenário/Auditório.
    if (!estadoSessao || !estadoSessao.existe_sessao_aberta) {
        [nomeEventoInput, responsavelEventoInput, dataOperacaoInput, horarioPautaInput, horaInicioInput]
            .forEach((el) => { if (el) el.readOnly = false; });

        if (comissaoSelect) {
            comissaoSelect.disabled = false;
            if (comissaoSelect.dataset) {
                delete comissaoSelect.dataset.lockSessao;
            }
        }
        return;
    }

    // Sessão aberta: usamos os dados da sessão apenas como "default"
    // (se o campo estiver vazio), mas mantemos os campos editáveis.
    const aplicarDefault = (input, valor) => {
        if (!input) return;
        if (!input.value) {
            input.value = valor || "";
        }
        input.readOnly = false;
    };

    aplicarDefault(nomeEventoInput, estadoSessao.nome_evento);
    aplicarDefault(responsavelEventoInput, estadoSessao.responsavel_evento);
    aplicarDefault(dataOperacaoInput, estadoSessao.data);
    aplicarDefault(horarioPautaInput, estadoSessao.horario_pauta);
    aplicarDefault(horaInicioInput, estadoSessao.horario_inicio);

    if (!comissaoSelect) return;

    // Verifica se o "Local" atual é Plenário ou Auditório
    let isAuditorio = false;
    let isPlenario = false;

    if (salaSelect && salaSelect.options && salaSelect.selectedIndex >= 0) {
        const optSala = salaSelect.options[salaSelect.selectedIndex] || null;
        const textoSala = (
            (optSala && (optSala.textContent || optSala.innerText || optSala.label)) ||
            ""
        ).toLowerCase();

        isAuditorio = REGEX_AUDITORIO.test(textoSala);
        isPlenario = REGEX_PLENARIO.test(textoSala);
    }

    const val = estadoSessao.comissao_id;

    if (isAuditorio || isPlenario) {
        // Plenário / Auditório: nenhum campo é travado pela sessão
        comissaoSelect.disabled = false;
        if (comissaoSelect.dataset) {
            delete comissaoSelect.dataset.lockSessao;
        }
    } else if (val !== null && val !== undefined && val !== "") {
        // Demais salas: Atividade Legislativa travada com o valor da sessão
        comissaoSelect.value = String(val);
        comissaoSelect.disabled = true;
        if (comissaoSelect.dataset) {
            comissaoSelect.dataset.lockSessao = "true";
        }
    } else {
        // Sessões antigas podem não ter comissao_id; deixa livre
        comissaoSelect.disabled = false;
        if (comissaoSelect.dataset) {
            delete comissaoSelect.dataset.lockSessao;
        }
    }
}