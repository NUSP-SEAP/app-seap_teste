/**
 * js/shared/utils.js
 * Utilitários genéricos compartilhados por todas as páginas do sistema.
 * Exposto via window.Utils para uso por scripts IIFE.
 */
(function () {
    "use strict";

    /** Alias para document.getElementById */
    function $(id) {
        return document.getElementById(id);
    }

    /** Converte data YYYY-MM-DD → DD/MM/YYYY. Retorna "--" para valores vazios. */
    function fmtDate(d) {
        if (!d) return "--";
        const parts = String(d).split("-");
        if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
        return d;
    }

    /** Trunca horário HH:MM:SS → HH:MM. Retorna "" para valores vazios. */
    function fmtTime(t) {
        if (!t) return "";
        return String(t).substring(0, 5);
    }

    /** Escapa caracteres HTML para evitar XSS. */
    function escapeHtml(s) {
        return String(s ?? "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    /**
     * Debounce: adia a execução de `func` até que `wait` ms se passem
     * sem novas chamadas. Usado em inputs de busca.
     */
    function debounce(func, wait) {
        let timeout;
        return function (...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => func.apply(this, args), wait);
        };
    }

    /** Seta o valor de um input/select pelo seu id. */
    function setVal(id, val) {
        const el = document.getElementById(id);
        if (el) el.value = val || "";
    }

    /**
     * Marca o radio button com `name` cujo value corresponde a `val`.
     * Normaliza valores booleanos/string para "sim"/"nao" no campo
     * "houve_anormalidade".
     */
    function setRadio(name, val) {
        if (val === undefined || val === null) return;
        let normalized = String(val).toLowerCase().trim();

        if (name === "houve_anormalidade") {
            if (["true", "t", "1", "sim", "s"].includes(normalized)) {
                normalized = "sim";
            } else {
                normalized = "nao";
            }
        }

        const radios = document.querySelectorAll(`input[name="${name}"]`);
        radios.forEach((radio) => {
            radio.checked = String(radio.value).toLowerCase().trim() === normalized;
        });
    }

    /**
     * Faz parse seguro do corpo JSON de uma resposta fetch.
     * Retorna null em caso de erro de parse.
     */
    async function safeJson(resp) {
        try { return await resp.json(); } catch (_) { return null; }
    }

    window.Utils = { $, fmtDate, fmtTime, escapeHtml, debounce, setVal, setRadio, safeJson };
})();
