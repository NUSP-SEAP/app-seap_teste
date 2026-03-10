// Funções utilitárias e helpers genéricos

/**
 * Seleciona um único elemento no DOM (atalho para querySelector).
 */
export const $ = (sel) => document.querySelector(sel);

/**
 * Seleciona múltiplos elementos no DOM e retorna como Array (atalho para querySelectorAll).
 */
export const $$ = (sel) => Array.from(document.querySelectorAll(sel));

/**
 * Tenta fazer o parse de uma resposta fetch para JSON de forma segura.
 * Retorna null em caso de erro.
 */
export function safeJson(resp) {
    return resp.json().catch(() => null);
}

/**
 * Preenche um elemento <select> com opções baseadas em um array de objetos.
 */
export function fillSelect(selectEl, rows, valueKey, labelKey, placeholder = "Selecione...") {
    if (!selectEl) return;
    const opts = ['<option value="">' + placeholder + "</option>"]
        .concat(
            (rows || []).map(
                (r) =>
                    `<option value="${String(r[valueKey])}">${String(
                        r[labelKey]
                    )}</option>`
            )
        )
        .join("");
    selectEl.innerHTML = opts;
    selectEl.disabled = false;
}

/**
 * Garante que o input de data tenha o dia de hoje preenchido, caso esteja vazio.
 * Recebe o elemento input como argumento.
 */
export function ensureHojeEmDataOperacao(dataOperacaoInput) {
    if (!dataOperacaoInput) return;
    if (!dataOperacaoInput.value) {
        const hoje = new Date();
        try {
            dataOperacaoInput.valueAsDate = hoje;
        } catch {
            const yyyy = hoje.getFullYear();
            const mm = String(hoje.getMonth() + 1).padStart(2, "0");
            const dd = String(hoje.getDate()).padStart(2, "0");
            dataOperacaoInput.value = `${yyyy}-${mm}-${dd}`;
        }
    }
}