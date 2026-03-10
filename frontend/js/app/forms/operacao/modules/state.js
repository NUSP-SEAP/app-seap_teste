// Gerenciamento de Estado e Lógica de Decisão Pura

/**
 * Objeto central de estado.
 * Como são módulos, exportamos um objeto constante que mantém as propriedades mutáveis.
 */
export const globalState = {
    estadoSessao: null,
    // 1 = editando 1ª entrada; 2 = editando 2ª; null = não está editando
    modoEdicaoEntradaSeq: null,
    uiState: {
        situacao_operador: "sem_sessao",   // "sem_sessao" | "sem_entrada" | "uma_entrada" | "duas_entradas"
        sessaoAberta: false,
    }
};

/**
 * Define o tipo de evento baseado na seleção da Sala e da Comissão.
 * Requer os elementos DOM select como parametros pois não são mais globais neste escopo.
 */
export function getTipoEventoSelecionado(salaSelect, comissaoSelect) {
    if (!salaSelect || !salaSelect.value) {
        return "operacao";
    }

    const optSala = salaSelect.options[salaSelect.selectedIndex] || null;
    const textoSala = (
        (optSala && (optSala.textContent || optSala.innerText || optSala.label)) ||
        ""
    ).toLowerCase();

    const isAuditorio = /audit[oó]rio/.test(textoSala);
    const isPlenario = /plen[áa]rio(?!\s*\d)/.test(textoSala);

    if (isAuditorio) {
        return "outros";
    }

    if (isPlenario) {
        return "operacao";
    }

    // Demais salas: depende do "Tipo" (dropdown comissao_id)
    if (comissaoSelect && comissaoSelect.value) {
        const optTipo = comissaoSelect.options[comissaoSelect.selectedIndex] || null;
        const textoTipo = (
            (optTipo && (optTipo.textContent || optTipo.innerText || optTipo.label)) ||
            ""
        ).toLowerCase();

        if (textoTipo.includes("cessão de sala") || textoTipo.includes("cessao de sala")) {
            return "cessao";
        }
    }

    return "operacao";
}

export function setTipoEventoSelecionado(_tipo) {
    // Mantida apenas por compatibilidade: não há mais rádios de "tipo_evento" na UI.
    // A lógica de tipo agora é derivada de sala + dropdown "Tipo".
}

export function derivarSituacaoOperador(estado) {
    // Sem estado algum para essa sala
    if (!estado) return "sem_sessao";

    const entradasOperador = Array.isArray(estado.entradas_operador)
        ? estado.entradas_operador
        : [];

    const temSessao = !!estado.existe_sessao_aberta;

    // Nenhuma sessão aberta e nenhuma entrada do operador
    if (!temSessao && entradasOperador.length === 0) {
        return "sem_sessao";
    }

    // Sessão existe (ou há contexto de sessão), mas o operador ainda não registrou nada
    if (entradasOperador.length === 0) {
        return "sem_entrada";
    }

    // Operador com 1 ou 2+ entradas
    if (entradasOperador.length === 1) return "uma_entrada";
    return "duas_entradas";
}