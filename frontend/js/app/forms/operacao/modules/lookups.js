// Carregamento de dados externos (Salas, Operadores, Comissões)

import { safeJson, fillSelect } from './utils.js';
// Importamos a função de UI pois ela é chamada ao final do carregamento das comissões
import { atualizarVisibilidadeTipoPorSala } from './ui.js';

// Supõe-se que AppConfig seja global (window.AppConfig). 
// Se AppConfig também fosse modularizado, seria importado aqui.
const SALAS_URL = AppConfig.apiUrl(AppConfig.endpoints.lookups.salas);
const OPERADORES_URL = AppConfig.apiUrl(AppConfig.endpoints.lookups.operadores);
const COMISSOES_URL = AppConfig.apiUrl(AppConfig.endpoints.lookups.comissoes);

export async function loadSalas(salaSelect) {
    if (!salaSelect) return;
    salaSelect.innerHTML = '<option value="">Carregando...</option>';
    salaSelect.disabled = true;

    try {
        let resp;
        if (window.Auth && typeof Auth.authFetch === "function") {
            resp = await Auth.authFetch(SALAS_URL, { method: "GET" });
        } else {
            resp = await fetch(SALAS_URL, { method: "GET" });
        }

        const json = await safeJson(resp);
        if (!resp.ok || !json || json.ok === false || !Array.isArray(json.data)) {
            console.error("Falha ao carregar locais:", json);
            salaSelect.innerHTML =
                '<option value="">Falha ao carregar locais</option>';
            return;
        }

        fillSelect(salaSelect, json.data, "id", "nome", "Selecione o local");
    } catch (e) {
        console.error("Erro inesperado ao carregar locais:", e);
        salaSelect.innerHTML =
            '<option value="">Falha ao carregar locais</option>';
    } finally {
        salaSelect.disabled = false;
    }
}

/**
 * Carrega os tipos de evento (comissões).
 * Recebe salaSelect também, pois precisa passá-lo para atualizarVisibilidadeTipoPorSala.
 */
export async function loadComissoes(comissaoSelect, salaSelect) {
    if (!comissaoSelect) return;

    comissaoSelect.disabled = true;
    comissaoSelect.innerHTML = '<option value="">Carregando...</option>';

    try {
        let resp;
        if (window.Auth && typeof Auth.authFetch === "function") {
            resp = await Auth.authFetch(COMISSOES_URL, { method: "GET" });
        } else {
            resp = await fetch(COMISSOES_URL, { method: "GET" });
        }

        const json = await safeJson(resp);
        if (!resp.ok || !json || json.ok === false || !Array.isArray(json.data)) {
            console.error("Falha ao carregar comissões:", json);
            comissaoSelect.innerHTML =
                '<option value="">Falha ao carregar tipos</option>';
            return;
        }

        fillSelect(comissaoSelect, json.data, "id", "nome", "Selecione o tipo");
    } catch (e) {
        console.error("Erro inesperado ao carregar comissões:", e);
        comissaoSelect.innerHTML =
            '<option value="">Falha ao carregar tipos</option>';
    } finally {
        comissaoSelect.disabled = false;
        // Chama a função de UI passando os elementos necessários
        if (typeof atualizarVisibilidadeTipoPorSala === "function") {
            atualizarVisibilidadeTipoPorSala(salaSelect, comissaoSelect);
        }
    }
}

export async function loadOperadores(operador1Select, operador2Select, operador3Select) {
    const selects = [operador1Select, operador2Select, operador3Select].filter(Boolean);
    if (!selects.length) return;

    selects.forEach((sel) => {
        sel.innerHTML = '<option value="">Carregando...</option>';
        sel.disabled = true;
    });

    try {
        let resp;
        if (window.Auth && typeof Auth.authFetch === "function") {
            resp = await Auth.authFetch(OPERADORES_URL, { method: "GET" });
        } else {
            resp = await fetch(OPERADORES_URL, { method: "GET" });
        }

        const json = await safeJson(resp);
        if (!resp.ok || !json || json.ok === false || !Array.isArray(json.data)) {
            console.error("Falha ao carregar operadores:", json);
            selects.forEach((sel) => {
                sel.innerHTML =
                    '<option value="">Falha ao carregar operadores</option>';
            });
            return;
        }

        selects.forEach((sel) => {
            fillSelect(
                sel,
                json.data,
                "id",
                "nome_completo",
                "Selecione o operador"
            );
        });
    } catch (e) {
        console.error("Erro inesperado ao carregar operadores:", e);
        selects.forEach((sel) => {
            sel.innerHTML =
                '<option value="">Falha ao carregar operadores</option>';
        });
    }
}