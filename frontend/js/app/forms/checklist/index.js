(function () {
    "use strict";

    // ====== Estado da Aplicação ======
    const state = {
        salaId: null,
        salaNome: "",       // Para exibição
        itens: [],          // Lista de itens carregada do backend
        currentIndex: 0,    // Índice do item atual no array
        respostas: {},      // Armazena as respostas: { item_id: { status, descricao, valor_texto } }
        startTime: null     // Data/Hora de início (Auditável, invisível)
    };

    // ====== UI Helpers ======
    const $ = (id) => document.getElementById(id);

    // Formata Date -> HH:MM:SS
    const pad2 = (n) => String(n).padStart(2, '0');
    const hhmmss = (d) => {
        if (!d) return null;
        return `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
    };

    // ====== Lógica de API ======

    // Busca Salas
    async function loadSalas() {
        const url = AppConfig.apiUrl(AppConfig.endpoints.lookups.salas);
        const sel = $("sala_id");
        sel.innerHTML = '<option value="">Carregando...</option>';

        try {
            let resp;
            if (window.Auth && Auth.authFetch) resp = await Auth.authFetch(url, { method: 'GET' });
            else resp = await fetch(url, { method: 'GET' });

            const json = await resp.json().catch(() => ({}));
            const rows = Array.isArray(json?.data) ? json.data : (Array.isArray(json) ? json : []);

            const opts = ['<option value="">Selecione...</option>'].concat(
                rows.map(r => `<option value="${r.id}">${r.nome}</option>`)
            ).join('');

            sel.innerHTML = opts;
            sel.disabled = false;
        } catch (e) {
            console.error(e);
            sel.innerHTML = '<option value="">Falha ao carregar</option>';
        }
    }

    // Busca Itens Específicos da Sala
    async function loadItensPorSala(salaId) {
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.forms.checklistItensTipo)}?sala_id=${salaId}`;
        try {
            let resp;
            if (window.Auth && Auth.authFetch) resp = await Auth.authFetch(url, { method: 'GET' });
            else resp = await fetch(url, { method: 'GET' });

            const json = await resp.json();
            if (!json.ok) throw new Error(json.error || "Erro ao buscar itens");

            return Array.isArray(json.data) ? json.data : [];
        } catch (e) {
            console.error("Erro ao carregar itens do local:", e);
            alert("Erro ao carregar configuração do local. Tente novamente.");
            return [];
        }
    }

    // ====== Lógica do Wizard (Passo a Passo) ======

    async function startWizard() {
        if (!state.salaId) return;

        // 1. Busca configuração
        const btnStart = $("btn-start-wizard");
        const originalText = btnStart.textContent;
        btnStart.disabled = true;
        btnStart.textContent = "Carregando...";

        const itens = await loadItensPorSala(state.salaId);

        if (!itens || itens.length === 0) {
            alert("Este local não possui itens de verificação configurados.");
            btnStart.textContent = originalText;
            btnStart.disabled = false;
            return;
        }

        state.itens = itens;
        state.currentIndex = 0;

        // Se já tiver respostas (usuário foi e voltou), mantemos. Senão, zera.
        // Neste ponto (startWizard), assume-se um fluxo novo ou reiniciado. 
        // Se quiser persistir dados ao voltar para o Setup e avançar de novo, não zere aqui.
        // state.respostas = {}; // Comentado para permitir ir e voltar sem perder

        // 2. Registra Início (Auditável) - Se já existir, não sobrescreve (preserva o primeiro clique)
        if (!state.startTime) {
            state.startTime = new Date();
        }

        // 3. Atualiza UI
        $("step-setup").classList.add("hidden");
        $("step-wizard").classList.remove("hidden");

        // Exibe Nome da Sala
        const sel = $("sala_id");
        state.salaNome = sel.options[sel.selectedIndex].text;
        $("wizard-sala-nome").textContent = state.salaNome;

        // Contadores
        const elTotal = $("wizard-total");
        if (elTotal) elTotal.textContent = state.itens.length;

        btnStart.disabled = false;
        btnStart.textContent = originalText;

        renderCurrentItem();
    }

    function renderCurrentItem() {
        const item = state.itens[state.currentIndex];

        // Recupera resposta salva (se houver) para preencher os campos
        const savedData = state.respostas[item.id] || null;

        // Atualiza contador visual
        const elIdx = $("wizard-current-idx");
        if (elIdx) elIdx.textContent = state.currentIndex + 1;

        // Container
        const container = $("wizard-container");
        container.innerHTML = "";

        // Título
        const h2 = document.createElement("h2");
        h2.className = "wizard-item-title";
        h2.textContent = item.nome;
        container.appendChild(h2);

        // Área de Input
        const inputArea = document.createElement("div");
        inputArea.id = "wizard-input-area";
        container.appendChild(inputArea);

        const btnNext = $("btn-wizard-next");

        // Renderiza
        if (item.tipo_widget === 'text') {
            renderTextInput(inputArea, item, btnNext, savedData);
        } else {
            renderRadioInput(inputArea, item, btnNext, savedData);
        }
    }

    // --- Renderizador: TEXTO ---
    function renderTextInput(container, item, btnNext, savedData) {
        const input = document.createElement("input");
        input.type = "text";
        input.id = "wiz_text_val";
        input.className = "wizard-text-input";
        input.placeholder = "Digite o valor...";
        input.autocomplete = "off";

        // Restaura valor
        if (savedData && savedData.valor_texto) {
            input.value = savedData.valor_texto;
        }

        container.appendChild(input);

        // Foco
        setTimeout(() => input.focus(), 100);

        const validate = () => {
            const val = input.value.trim();
            const isObrigatorio = false; // Todos os itens são opcionais
            btnNext.disabled = (isObrigatorio && val.length === 0);
        };

        input.addEventListener("input", validate);

        // Valida estado inicial (se veio preenchido, libera botão)
        validate();
    }

    // --- Renderizador: RADIO (Ok/Falha) ---
    function renderRadioInput(container, item, btnNext, savedData) {
        container.innerHTML = `
            <div class="wizard-radios">
                <label class="radio-card">
                    <input type="radio" name="wiz_radio" value="Ok">
                    <span class="radio-label">✅ Ok</span>
                </label>
                <label class="radio-card">
                    <input type="radio" name="wiz_radio" value="Falha">
                    <span class="radio-label">❌ Falha</span>
                </label>
            </div>
            <div id="wiz_falha_container" class="hidden" style="margin-top: 15px;">
                <label class="required">Descrição da falha:</label>
                <textarea id="wiz_desc_falha" rows="3" placeholder="Descreva o problema (mínimo 10 caracteres)..."></textarea>
                <p id="wiz_falha_hint" class="hidden" style="color: #dc2626; font-size: 0.85rem; margin-top: 5px;">Insira no mínimo 10 caracteres para continuar</p>
            </div>
        `;

        const radios = container.querySelectorAll("input[name='wiz_radio']");
        const areaFalha = container.querySelector("#wiz_falha_container");
        const txtFalha = container.querySelector("#wiz_desc_falha");

        // --- Restaura Estado Anterior ---
        if (savedData) {
            if (savedData.status === "Ok") {
                const r = container.querySelector("input[value='Ok']");
                if (r) r.checked = true;
                btnNext.disabled = false;
            } else if (savedData.status === "Falha") {
                const r = container.querySelector("input[value='Falha']");
                if (r) r.checked = true;
                areaFalha.classList.remove("hidden");
                txtFalha.value = savedData.descricao_falha || "";

                // Valida se já libera o botão
                if (txtFalha.value.length >= 10) btnNext.disabled = false;
            }
        } else {
            // Se não tem dados salvos, bloqueia botão
            btnNext.disabled = true;
        }

        const handleRadioChange = (e) => {
            const val = e.target.value;
            if (val === "Ok") {
                areaFalha.classList.add("hidden");
                txtFalha.value = "";
                btnNext.disabled = false;
                btnNext.focus();
            } else {
                areaFalha.classList.remove("hidden");
                txtFalha.focus();
                btnNext.disabled = true; // Precisa digitar descrição
            }
        };

        const hintFalha = container.querySelector("#wiz_falha_hint");

        const handleTextFalha = () => {
            const len = txtFalha.value.trim().length;
            if (len >= 10) {
                btnNext.disabled = false;
                hintFalha.classList.add("hidden");
            } else {
                btnNext.disabled = true;
                // Exibe o aviso apenas se o usuário já começou a digitar
                if (len > 0) {
                    hintFalha.classList.remove("hidden");
                } else {
                    hintFalha.classList.add("hidden");
                }
            }
        };

        radios.forEach(r => r.addEventListener("change", handleRadioChange));
        txtFalha.addEventListener("input", handleTextFalha);
    }

    // --- Navegação: Avançar ---
    function nextStep() {
        const item = state.itens[state.currentIndex];

        // Salva dados atuais
        const respostaData = {
            item_tipo_id: item.id,
            status: null,
            descricao_falha: null,
            valor_texto: null
        };

        if (item.tipo_widget === 'text') {
            respostaData.valor_texto = $("wiz_text_val").value.trim();
            respostaData.status = "Ok";
        } else {
            const checked = document.querySelector("input[name='wiz_radio']:checked");
            if (!checked) return;
            respostaData.status = checked.value;
            if (respostaData.status === "Falha") {
                respostaData.descricao_falha = $("wiz_desc_falha").value.trim();
            }
        }

        state.respostas[item.id] = respostaData;

        // Avança
        if (state.currentIndex < state.itens.length - 1) {
            state.currentIndex++;
            renderCurrentItem();
        } else {
            finishWizardFlow();
        }
    }

    // --- Navegação: Voltar ---
    function prevStep() {
        if (state.currentIndex > 0) {
            // Volta um item no Wizard
            state.currentIndex--;
            renderCurrentItem();
        } else {
            // Volta para a seleção de sala (Setup)
            $("step-wizard").classList.add("hidden");
            $("step-setup").classList.remove("hidden");
            // Nota: Não zeramos state.respostas propositalmente para manter o preenchimento se ele voltar.
        }
    }

    // --- Tela Final ---
    function finishWizardFlow() {
        $("step-wizard").classList.add("hidden");
        $("step-finish").classList.remove("hidden");
        setTimeout(() => $("observacoes").focus(), 100);
    }

    function backFromFinish() {
        // Volta para o último item do wizard
        $("step-finish").classList.add("hidden");
        $("step-wizard").classList.remove("hidden");
        // currentIndex já estará no último índice, basta renderizar
        renderCurrentItem();
    }


    // ====== Submit Final ======
    async function submitData() {
        const btn = $("btn-save-all");
        const originalTxt = btn.textContent;
        btn.disabled = true;
        btn.textContent = "Salvando...";

        try {
            const payload = {
                data_operacao: $("data_operacao").value,
                sala_id: parseInt(state.salaId, 10),
                // Auditabilidade invisível
                hora_inicio_testes: hhmmss(state.startTime),
                hora_termino_testes: hhmmss(new Date()),
                observacoes: $("observacoes").value || null,
                itens: Object.values(state.respostas)
            };

            const url = AppConfig.apiUrl(AppConfig.endpoints.forms.checklist);

            let resp;
            const headers = { 'Content-Type': 'application/json' };

            if (window.Auth && Auth.authFetch) {
                resp = await Auth.authFetch(url, {
                    method: 'POST',
                    headers: headers,
                    body: JSON.stringify(payload)
                });
            } else {
                const token = localStorage.getItem('auth_token');
                if (token) headers['Authorization'] = 'Bearer ' + token;
                resp = await fetch(url, { method: 'POST', headers, body: JSON.stringify(payload) });
            }

            if (resp.status === 401 || resp.status === 403) {
                alert("Sessão expirada.");
                window.location.href = "/index.html";
                return;
            }

            const json = await resp.json().catch(() => ({}));

            if (resp.ok && json.ok) {
                alert("Checklist salvo com sucesso!");
                window.location.href = "/home.html";
            } else {
                const msg = json.message || json.error || "Erro ao salvar.";
                console.warn("Erro backend:", json);
                alert("Não foi possível salvar: " + msg);
            }

        } catch (e) {
            console.error(e);
            alert("Erro de conexão ao salvar.");
        } finally {
            btn.disabled = false;
            btn.textContent = originalTxt;
        }
    }


    // ====== Init ======
    document.addEventListener("DOMContentLoaded", async () => {
        const dateInput = $("data_operacao");
        if (dateInput) dateInput.valueAsDate = new Date();

        await loadSalas();

        // Listeners Setup
        const selSala = $("sala_id");
        if (selSala) {
            selSala.addEventListener("change", (e) => {
                state.salaId = e.target.value;
                const btnStart = $("btn-start-wizard");
                if (state.salaId) {
                    btnStart.disabled = false;
                    btnStart.classList.remove("btn-secondary"); // Estilo visual
                    btnStart.classList.add("btn-primary");
                } else {
                    btnStart.disabled = true;
                }
            });
        }

        $("btn-start-wizard").addEventListener("click", startWizard);

        // Listeners Wizard
        $("btn-wizard-next").addEventListener("click", nextStep);
        $("btn-wizard-prev").addEventListener("click", prevStep);

        // Listeners Finish
        $("btn-finish-back").addEventListener("click", backFromFinish);
        $("btn-save-all").addEventListener("click", submitData); // Botão do form final

        // Bloqueia Submit padrão do Form
        const form = document.getElementById("form-checklist");
        if (form) {
            form.addEventListener("submit", (e) => {
                e.preventDefault();
                // Não chama submitData() aqui — o salvamento só ocorre pelo clique no botão
            });
        }
    });

})();