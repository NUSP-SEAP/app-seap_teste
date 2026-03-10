// === Lookups ===
const SALAS_URL = AppConfig.apiUrl(AppConfig.endpoints.lookups.salas);
const REGISTRO_ANORMALIDADE_URL = AppConfig.apiUrl(AppConfig.endpoints.forms.anormalidade);
const REGISTRO_LOOKUP_URL = AppConfig.apiUrl(AppConfig.endpoints.lookups.registroOperacao);

/**
 * Lê o token JWT do front (Auth ou localStorage)
 */
function getToken() {
    try {
        if (window.Auth && typeof Auth.loadToken === "function") {
            const t = Auth.loadToken();
            if (t) return t;
        }
    } catch (e) {
        console.error("Erro ao carregar token via Auth:", e);
    }

    return (
        localStorage.getItem("auth_token") ||
        localStorage.getItem("token") ||
        ""
    );
}

/**
 * fetch com Authorization
 */
async function authFetch(url, options = {}) {
    if (window.Auth && typeof Auth.authFetch === "function") {
        return Auth.authFetch(url, options);
    }

    const headers = Object.assign({}, options.headers || {});
    const tok = getToken();
    if (tok) headers["Authorization"] = "Bearer " + tok;
    return fetch(url, Object.assign({}, options, { headers }));
}

/**
 * Lê IDs da querystring
 */
function getQueryId(paramName) {
    try {
        const params = new URLSearchParams(window.location.search);
        const val = params.get(paramName);
        if (!val) return null;
        const n = Number(val);
        if (!Number.isFinite(n) || n <= 0) return null;
        return String(n);
    } catch (e) {
        return null;
    }
}

/**
 * Carrega salas e seleciona (se houver) uma sala preferida
 */
async function loadSalas(prefId = null) {
    const sel = document.getElementById("sala_id_display");
    const hidden = document.getElementById("sala_id");

    if (!sel) return;

    sel.innerHTML = '<option value="">Carregando...</option>';

    try {
        const r = await authFetch(SALAS_URL, { method: "GET" });
        const json = await r.json().catch(() => ({}));

        const rows = Array.isArray(json?.data) ? json.data : [];

        sel.innerHTML =
            '<option value="">Selecione...</option>' +
            rows.map((s) => `<option value="${s.id}">${s.nome}</option>`).join("");

        if (prefId) {
            sel.value = String(prefId);
            if (hidden) hidden.value = String(prefId);
        } else {
            if (hidden) hidden.value = sel.value || "";
        }

        sel.disabled = true; // Sempre travado nesta tela
    } catch (e) {
        sel.innerHTML = '<option value="">[Erro ao carregar]</option>';
    }
}

/**
 * Busca dados básicos do registro de operação para o cabeçalho
 */
async function loadRegistroOperacao(registroId, entradaId) {
    try {
        const params = new URLSearchParams();
        params.set("id", String(registroId));
        if (entradaId) params.set("entrada_id", String(entradaId));

        const url = `${REGISTRO_LOOKUP_URL}?${params.toString()}`;
        const resp = await authFetch(url, { method: "GET" });
        const json = await resp.json().catch(() => ({}));

        if (!resp.ok || json.ok === false || !json.data) {
            return null;
        }
        return json.data;
    } catch (e) {
        console.error("Erro inesperado ao buscar registro:", e);
        return null;
    }
}

/**
 * Tenta carregar uma anormalidade existente para a entrada_id informada.
 */
async function loadAnormalidadeExistente(entradaId) {
    if (!entradaId) return null;
    try {
        const url = `${REGISTRO_ANORMALIDADE_URL}?entrada_id=${encodeURIComponent(entradaId)}`;
        const resp = await authFetch(url, { method: "GET" });

        if (resp.status === 404) return null;

        const json = await resp.json().catch(() => ({}));
        if (!resp.ok || json.ok === false) return null;

        const data = json.data || json;
        preencherFormularioAnormalidade(data);
        return data;
    } catch (e) {
        return null;
    }
}

/**
 * Preenche o formulário (Edição)
 */
function preencherFormularioAnormalidade(data) {
    const setVal = (id, value) => {
        const el = document.getElementById(id);
        if (el && value !== undefined && value !== null) el.value = String(value);
    };

    const setRadio = (name, val) => {
        let v = val === true || val === "true" || val === "sim" || val === 1 ? "sim" : "nao";
        const radio = document.querySelector(`input[name="${name}"][value="${v}"]`);
        if (radio) {
            radio.checked = true;
            radio.dispatchEvent(new Event("change")); // Atualiza toggles
        }
    };

    // Cabeçalho
    setVal("data", data.data);
    setVal("sala_id", data.sala_id);
    setVal("sala_id_display", data.sala_id);
    setVal("nome_evento_display", data.nome_evento);
    setVal("nome_evento", data.nome_evento);

    // Campos principais
    setVal("hora_inicio_anormalidade", data.hora_inicio_anormalidade);
    setVal("descricao_anormalidade", data.descricao_anormalidade);
    setVal("responsavel_evento", data.responsavel_evento);

    // Condicionais
    setRadio("houve_prejuizo", data.houve_prejuizo);
    setVal("descricao_prejuizo", data.descricao_prejuizo);

    setRadio("houve_reclamacao", data.houve_reclamacao);
    setVal("autores_conteudo_reclamacao", data.autores_conteudo_reclamacao);

    setRadio("acionou_manutencao", data.acionou_manutencao);
    setVal("hora_acionamento_manutencao", data.hora_acionamento_manutencao);

    setRadio("resolvida_pelo_operador", data.resolvida_pelo_operador);
    setVal("procedimentos_adotados", data.procedimentos_adotados);

    // ID para update
    const form = document.getElementById("form-raoa");
    if (form && data.id) {
        let hid = form.querySelector('input[name="id"]');
        if (!hid) {
            hid = document.createElement("input");
            hid.type = "hidden";
            hid.name = "id";
            hid.id = "registro_anormalidade_id";
            form.appendChild(hid);
        }
        hid.value = String(data.id);
    }
}

/**
 * Regras de exibição condicional
 */
function bindToggles() {
    const toggles = [
        {
            name: "houve_prejuizo",
            target: "grp_descricao_prejuizo",
            required: ["descricao_prejuizo"],
        },
        {
            name: "houve_reclamacao",
            target: "grp_autores_conteudo_reclamacao",
            required: ["autores_conteudo_reclamacao"],
        },
        {
            name: "acionou_manutencao",
            target: "grp_hora_acionamento",
            required: ["hora_acionamento_manutencao"],
        },
        {
            name: "resolvida_pelo_operador",
            target: "grp_procedimentos_adotados",
            required: ["procedimentos_adotados"],
        },
    ];

    toggles.forEach((t) => {
        const groupEl = document.getElementById(t.target);
        if (!groupEl) return;

        const radios = document.querySelectorAll(`input[name="${t.name}"]`);

        const apply = () => {
            const yes = document.querySelector(`input[name="${t.name}"][value="sim"]`);
            const show = !!yes && yes.checked;

            groupEl.classList.toggle("hidden", !show);

            (t.required || []).forEach((fieldId) => {
                const field = document.getElementById(fieldId);
                if (field) {
                    if (show) {
                        field.setAttribute("required", "required");
                    } else {
                        field.removeAttribute("required");
                        field.value = "";
                    }
                }
            });
        };

        radios.forEach((r) => r.addEventListener("change", apply));
        apply();
    });
}

// === Inicialização ===
document.addEventListener("DOMContentLoaded", async () => {
    bindToggles();

    const registroId = getQueryId("registro_id");
    const entradaId = getQueryId("entrada_id");

    // Preenche hiddens
    if (registroId) document.getElementById("registro_id").value = registroId;
    if (entradaId) document.getElementById("entrada_id").value = entradaId;

    if (registroId) {
        document.getElementById("registro-ref").textContent = "Vinculado ao registro de operação nº " + registroId;
    }

    let prefSalaId = null;

    // Carrega dados do registro (cabeçalho)
    if (registroId) {
        const info = await loadRegistroOperacao(registroId, entradaId);
        if (info) {
            if (info.data) document.getElementById("data").value = info.data;
            if (info.nome_evento) {
                document.getElementById("nome_evento_display").value = info.nome_evento;
                document.getElementById("nome_evento").value = info.nome_evento;
            }
            if (info.sala_id) {
                prefSalaId = info.sala_id;
                document.getElementById("sala_id").value = String(info.sala_id);
            }
        }
    }

    await loadSalas(prefSalaId);

    // Verifica se já existe RAOA (Modo Edição)
    let modo = "novo";
    if (entradaId) {
        const raoa = await loadAnormalidadeExistente(entradaId);
        if (raoa && raoa.id) modo = "edicao";
    }

    const form = document.getElementById("form-raoa");

    // Submit
    form.addEventListener("submit", async (ev) => {
        ev.preventDefault();
        if (!form.checkValidity()) {
            form.reportValidity();
            return;
        }

        const btn = form.querySelector('button[type="submit"]');
        const oldTxt = btn.textContent;
        btn.disabled = true;
        btn.textContent = "Salvando...";

        try {
            const resp = await authFetch(REGISTRO_ANORMALIDADE_URL, {
                method: "POST",
                body: new FormData(form),
            });

            const data = await resp.json().catch(() => ({}));

            if (!resp.ok || data.ok === false) {
                const err = data.error || (data.errors ? JSON.stringify(data.errors) : "Erro desconhecido");
                alert("Erro ao salvar: " + err);
                btn.disabled = false;
                btn.textContent = oldTxt;
                return;
            }

            alert("Registro de anormalidade salvo com sucesso!");
            window.location.href = "/home.html";

        } catch (e) {
            console.error(e);
            alert("Erro de conexão ao salvar.");
            btn.disabled = false;
            btn.textContent = oldTxt;
        }
    });

    // Botão Voltar
    document.getElementById("btn-voltar").addEventListener("click", () => {
        window.location.href = "/home.html";
    });
});