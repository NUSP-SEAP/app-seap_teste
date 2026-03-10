// app/js/app/forms/operacao/index/actions.js
// Ações do usuário e processamento (Salvar, Editar, Finalizar, Carregar Estado)

import { safeJson, ensureHojeEmDataOperacao } from './utils.js';
import { globalState, getTipoEventoSelecionado } from './state.js';
import {
    aplicarEstadoSessaoNaUI,
    atualizarCabecalhoOperadoresSessao,
    preencherFormularioComEntrada,
    resetFormMantendoSalaETipo,
    aplicarRegrasEventoEncerrado
} from './ui.js';

// Endpoints
const ESTADO_SESSAO_URL = AppConfig.apiUrl(AppConfig.endpoints.operacaoAudio.estadoSessao);
const SALVAR_ENTRADA_URL = AppConfig.apiUrl(AppConfig.endpoints.operacaoAudio.salvarEntrada);

// =============================================================================
// Carregar Estado
// =============================================================================

export async function carregarEstadoSessao(salaId, elements) {
    if (!salaId) {
        globalState.estadoSessao = null;
        globalState.uiState.situacao_operador = "sem_sessao";
        globalState.uiState.sessaoAberta = false;
        aplicarEstadoSessaoNaUI(elements, globalState);
        return;
    }

    const url = ESTADO_SESSAO_URL + "?sala_id=" + encodeURIComponent(String(salaId));

    try {
        let resp;
        if (window.Auth && typeof Auth.authFetch === "function") {
            resp = await Auth.authFetch(url, { method: "GET" });
        } else {
            resp = await fetch(url, { method: "GET" });
        }

        const json = await safeJson(resp);
        if (!resp.ok) {
            console.error("Falha HTTP ao buscar estado da sessão:", resp.status, json);
            if (resp.status === 401 || resp.status === 403) {
                alert("Sua sessão expirou ou você não está autenticado. Faça login novamente.");
            } else {
                alert("Erro ao buscar estado da sessão de operação de áudio.");
            }
            globalState.estadoSessao = null;
            aplicarEstadoSessaoNaUI(elements, globalState);
            return;
        }

        if (!json || json.ok === false) {
            const msg = (json && (json.message || json.detail || json.error)) || "Erro ao buscar estado da sessão.";
            alert(msg);
            globalState.estadoSessao = null;
            aplicarEstadoSessaoNaUI(elements, globalState);
            return;
        }

        globalState.estadoSessao = json.data || null;
        aplicarEstadoSessaoNaUI(elements, globalState);

    } catch (e) {
        console.error("Erro inesperado ao buscar estado da sessão:", e);
        alert("Erro inesperado ao buscar estado da sessão de operação de áudio.");
        globalState.estadoSessao = null;
        aplicarEstadoSessaoNaUI(elements, globalState);
    }
}

// =============================================================================
// Modo Edição
// =============================================================================

export function entrarModoEdicaoEntrada(seq, elements) {
    const { estadoSessao } = globalState;
    const { form, salaSelect, btnSalvarRegistro, btnEditarEntrada1, btnEditarEntrada2, btnFinalizarSessao, btnCancelarEdicao, btnLimpar, btnSalvarEdicao, headerOperadores, modoEdicaoInfo } = elements;

    if (!estadoSessao || !Array.isArray(estadoSessao.entradas_operador)) {
        alert("Não foi possível localizar as entradas do operador nessa sessão.");
        return;
    }

    const entrada = estadoSessao.entradas_operador.find((e) => e.seq === seq);
    if (!entrada) {
        alert(`Não encontrei a ${seq}ª entrada para edição.`);
        return;
    }

    // Habilita campos para edição (mantendo a sala editável)
    if (form) {
        const campos = form.querySelectorAll("input, textarea, select");
        campos.forEach((el) => {
            if (el === salaSelect) return;
            el.disabled = false;
            if ("readOnly" in el) {
                el.readOnly = false;
            }
        });
    }

    // Preenche o formulário
    preencherFormularioComEntrada(elements, entrada, estadoSessao);

    // Aplica regras de Evento Encerrado com base nos dados da entrada carregada
    const sessaoAberta = !!(estadoSessao && estadoSessao.existe_sessao_aberta);
    aplicarRegrasEventoEncerrado(elements, sessaoAberta);

    // Atualiza estado global
    globalState.modoEdicaoEntradaSeq = seq;

    // Ajusta botões
    if (btnSalvarRegistro) btnSalvarRegistro.style.display = "none";
    if (btnEditarEntrada1) btnEditarEntrada1.style.display = "none";
    if (btnEditarEntrada2) btnEditarEntrada2.style.display = "none";
    if (btnFinalizarSessao) btnFinalizarSessao.style.display = "none";

    if (btnCancelarEdicao) {
        btnCancelarEdicao.style.display = "";
        btnCancelarEdicao.disabled = false;
    }
    if (btnLimpar) {
        btnLimpar.style.display = "";
        btnLimpar.disabled = false;
    }
    if (btnSalvarEdicao) {
        btnSalvarEdicao.style.display = "";
        btnSalvarEdicao.disabled = false;
        btnSalvarEdicao.textContent = "Salvar Edição";
    }

    atualizarCabecalhoOperadoresSessao(headerOperadores, modoEdicaoInfo, estadoSessao, globalState.modoEdicaoEntradaSeq);
}

export function cancelarEdicaoEntrada(elements) {
    globalState.modoEdicaoEntradaSeq = null;
    resetFormMantendoSalaETipo(elements);
    aplicarEstadoSessaoNaUI(elements, globalState);
}

// =============================================================================
// Salvar Entrada
// =============================================================================

export async function salvarEntrada(modo, elements, opcoes) {
    opcoes = opcoes || {};
    const suprimirValidacaoHtml5 = !!opcoes.suprimirValidacaoHtml5;
    const suprimirAlertDeErro = !!opcoes.suprimirAlertDeErro;

    const {
        form, salaSelect, comissaoSelect, dataOperacaoInput, horarioPautaInput,
        horaInicioInput, horaFimInput, horaEntradaInput, horaSaidaInput,
        nomeEventoInput, usb01Input, usb02Input,
        observacoesInput, responsavelEventoInput, btnSalvarEdicao, btnSalvarRegistro
    } = elements;

    if (!form) return;
    if (!salaSelect || !salaSelect.value) {
        alert("Selecione um local antes de salvar o registro.");
        return;
    }

    // Validação HTML5
    if (!form.checkValidity()) {
        if (!suprimirValidacaoHtml5) {
            form.reportValidity();
        }
        return;
    }

    const salaId = salaSelect.value;

    // Validação extra: Tipo obrigatório
    if (comissaoSelect && salaSelect && salaId) {
        const optSala = salaSelect.options[salaSelect.selectedIndex] || null;
        const textoSala = ((optSala && (optSala.textContent || optSala.innerText || optSala.label)) || "").toLowerCase();
        const isAuditorio = /audit[oó]rio/.test(textoSala);
        const isPlenario = /plen[áa]rio(?!\s*\d)/.test(textoSala);
        const exigeTipo = !isAuditorio && !isPlenario;

        if (exigeTipo && !comissaoSelect.value) {
            if (!suprimirValidacaoHtml5) {
                alert("Selecione o Tipo antes de salvar o registro.");
                comissaoSelect.focus();
            }
            return;
        }
    }

    // Tipo do evento
    let tipoEvento = (getTipoEventoSelecionado(salaSelect, comissaoSelect) || "operacao").toLowerCase();

    const radioAnom = document.querySelector('input[name="houve_anormalidade"]:checked');
    const houveAnormalidadeRaw = radioAnom ? (radioAnom.value || "nao") : "nao";

    // Operador Logado
    let operadorId = null;
    try {
        if (window.Auth && typeof Auth.loadUser === "function") {
            const me = Auth.loadUser();
            if (me && me.ok && me.user && me.user.id) {
                operadorId = me.user.id;
            }
        }
    } catch (e) {
        console.error("Erro ao obter operador logado:", e);
    }

    if (!operadorId) {
        alert("Não foi possível identificar o operador logado. Tente fazer login novamente.");
        return;
    }

    // Payload
    const payload = {
        operador_id: operadorId,
        data_operacao: dataOperacaoInput ? dataOperacaoInput.value : "",
        horario_pauta: horarioPautaInput ? horarioPautaInput.value : "",
        hora_inicio: horaInicioInput ? horaInicioInput.value : "",
        hora_fim: horaFimInput ? horaFimInput.value : "",
        hora_entrada: horaEntradaInput ? horaEntradaInput.value : "",
        hora_saida: horaSaidaInput ? horaSaidaInput.value : "",
        sala_id: salaId,
        nome_evento: nomeEventoInput ? nomeEventoInput.value : "",
        observacoes: observacoesInput ? observacoesInput.value : "",
        usb_01: usb01Input ? usb01Input.value : "",
        usb_02: usb02Input ? usb02Input.value : "",
        responsavel_evento: responsavelEventoInput ? responsavelEventoInput.value : "",
        comissao_id: comissaoSelect ? (comissaoSelect.value || null) : null,
        tipo_evento: tipoEvento,
        houve_anormalidade: houveAnormalidadeRaw,
    };

    // Modo edição: injeta entrada_id
    if (modo === "edicao" && globalState.estadoSessao) {
        const entradasOperador = Array.isArray(globalState.estadoSessao.entradas_operador)
            ? globalState.estadoSessao.entradas_operador
            : [];

        if (!entradasOperador.length) {
            alert("Não há entradas deste operador para serem editadas nesta sessão.");
            return;
        }

        let entrada = null;
        if (globalState.modoEdicaoEntradaSeq === 1 || globalState.modoEdicaoEntradaSeq === 2) {
            entrada = entradasOperador.find((e) => e.seq === globalState.modoEdicaoEntradaSeq) || null;
        }
        if (!entrada) {
            entrada = entradasOperador[0];
        }

        const entradaId = entrada && entrada.entrada_id;
        if (!entradaId) {
            alert("Não foi possível determinar qual entrada editar.");
            return;
        }
        payload.entrada_id = String(entradaId);
    }

    // Envio
    const btnPrincipal = modo === "edicao" ? (btnSalvarEdicao || btnSalvarRegistro) : btnSalvarRegistro;

    try {
        if (btnPrincipal) {
            btnPrincipal.disabled = true;
            btnPrincipal.textContent = "Salvando...";
        }

        let resp;
        const options = {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        };

        if (window.Auth && typeof Auth.authFetch === "function") {
            resp = await Auth.authFetch(SALVAR_ENTRADA_URL, options);
        } else {
            resp = await fetch(SALVAR_ENTRADA_URL, options);
        }

        const json = await safeJson(resp);
        if (!resp.ok || !json || json.ok === false) {
            console.error("Erro ao salvar entrada:", json);
            if (!suprimirAlertDeErro) {
                if (json && json.errors && typeof json.errors === "object") {
                    const linhas = Object.entries(json.errors).map(([c, m]) => `${c}: ${m}`).join("\n");
                    alert("Erro ao salvar o registro:\n\n" + linhas);
                } else {
                    const msg = (json && (json.message || json.detail || json.error)) || "Falha ao salvar o registro.";
                    alert(msg);
                }
            }
            return;
        }

        const registroId = json.registro_id;
        const entradaId = json.entrada_id;
        const houveAnomalia = json.houve_anormalidade === true || json.houve_anormalidade === "true";
        const tipoEventoEfetivo = (json.tipo_evento || tipoEvento || "operacao").toLowerCase();
        const isEdicao = !!json.is_edicao;
        const deveAbrirAnomalia = houveAnomalia && (tipoEventoEfetivo === "operacao" || tipoEventoEfetivo === "outros");

        let msgBase = isEdicao ? "Edição salva com sucesso." : "Registro salvo com sucesso.";

        if (deveAbrirAnomalia) {
            alert(msgBase + "\n\nRedirecionando para Registro de Anormalidade.");
            resetFormMantendoSalaETipo(elements);
            const params = new URLSearchParams();
            params.set("registro_id", String(registroId));
            if (entradaId) {
                params.set("entrada_id", String(entradaId));
                params.set("modo", "novo");
            }
            window.location.href = "/forms/operacao/anormalidade.html?" + params.toString();
        } else {
            // [ALTERADO] Redireciona para Home se não houver anormalidade
            alert(msgBase);
            window.location.href = "/home.html";
        }

    } catch (e) {
        console.error("Erro inesperado ao salvar entrada de operação:", e);
        alert("Erro inesperado ao salvar o registro de operação de áudio. Tente novamente.");
    } finally {
        if (btnPrincipal) {
            btnPrincipal.disabled = false;
        }
    }
}

// =============================================================================
// Finalizar Sessão
// =============================================================================

// export async function finalizarSessao(elements) {
//     const { salaSelect, btnFinalizarSessao, form, dataOperacaoInput } = elements;

//     if (!salaSelect || !salaSelect.value) {
//         alert("Selecione uma sala antes de finalizar o registro da operação.");
//         return;
//     }

//     const salaId = salaSelect.value;

//     // Sempre recarrega o estado da sessão para esta sala
//     await carregarEstadoSessao(salaId, elements);

//     const { estadoSessao, uiState } = globalState;
//     const sessaoAberta = !!(estadoSessao && estadoSessao.existe_sessao_aberta);

//     // Preferência: se o back já mandou situacao_operador, usamos,
//     // senão usamos o valor derivado que está em uiState.
//     let situacaoOperador = "sem_sessao";
//     if (estadoSessao && estadoSessao.situacao_operador) {
//         situacaoOperador = estadoSessao.situacao_operador;
//     } else if (uiState && uiState.situacao_operador) {
//         situacaoOperador = uiState.situacao_operador;
//     }

//     // Mesma regra do index.js original:
//     // só pode finalizar se existir sessão aberta
//     // E o operador tiver pelo menos um registro.
//     if (!sessaoAberta || situacaoOperador === "sem_entrada") {
//         alert("Somente usuários com registro nesta sala/operação podem finalizar.");
//         return;
//     }

//     const payload = { sala_id: salaId };

//     try {
//         if (btnFinalizarSessao) {
//             btnFinalizarSessao.disabled = true;
//             btnFinalizarSessao.textContent = "Finalizando...";
//         }

//         let resp;
//         const options = {
//             method: "POST",
//             headers: { "Content-Type": "application/json" },
//             body: JSON.stringify(payload),
//         };

//         if (window.Auth && typeof Auth.authFetch === "function") {
//             resp = await Auth.authFetch(FINALIZAR_SESSAO_URL, options);
//         } else {
//             resp = await fetch(FINALIZAR_SESSAO_URL, options);
//         }

//         const json = await safeJson(resp);
//         if (!resp.ok || !json || json.ok === false) {
//             const msg =
//                 (json && (json.message || json.detail || json.error)) ||
//                 "Falha ao finalizar o registro da sala/operação.";
//             alert(msg);
//             return;
//         }

//         alert("Registro da Sala/Operação finalizado com sucesso.");

//         // Depois de finalizar, voltamos para o estado "sem sala"
//         globalState.modoEdicaoEntradaSeq = null;

//         if (form) {
//             form.reset();
//         }

//         if (salaSelect) {
//             salaSelect.value = "";
//         }

//         globalState.estadoSessao = null;
//         globalState.uiState.situacao_operador = "sem_sessao";
//         globalState.uiState.sessaoAberta = false;

//         // Garante a mesma compatibilidade do index.js original
//         ensureHojeEmDataOperacao(dataOperacaoInput);

//         // Reaplica bloqueios / visuais para o estado "sem sala"
//         aplicarEstadoSessaoNaUI(elements, globalState);
//     } catch (e) {
//         console.error("Erro inesperado ao finalizar sessão:", e);
//         alert("Erro inesperado ao finalizar a sessão.");
//     } finally {
//         if (btnFinalizarSessao) {
//             btnFinalizarSessao.disabled = false;
//             btnFinalizarSessao.textContent =
//                 "Finalizar Registro da Sala/Operação";
//         }
//     }
// }
