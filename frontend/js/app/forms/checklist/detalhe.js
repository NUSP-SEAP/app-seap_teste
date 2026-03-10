(function () {
    "use strict";

    // ====== Pega o ID da URL ======
    const params = new URLSearchParams(window.location.search);
    const checklistId = params.get("checklist_id");

    if (!checklistId) {
        alert("ID de checklist não fornecido.");
        window.close();
        return;
    }

    // ====== Estado ======
    const state = {
        editMode: false,
        originalData: null,   // dados completos vindos da API
        salaId: null,         // sala_id original
        salasLoaded: false,   // se já carregou dropdown de salas
    };

    // ====== Helpers ======
    const $ = (id) => document.getElementById(id);

    const setVal = (id, val) => {
        const el = $(id);
        if (el) el.value = val || "";
    };

    const fmtDate = (d) => {
        if (!d) return "";
        const parts = d.split('-');
        if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
        return d;
    };

    // ====== Carregar dados (readonly) ======
    async function loadData() {
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.operadorDashboard.detalheChecklist)}?checklist_id=${checklistId}`;

        if (!window.Auth || typeof Auth.authFetch !== 'function') {
            console.error("Auth não carregado");
            return;
        }

        try {
            const resp = await Auth.authFetch(url);
            if (!resp.ok) throw new Error("Erro HTTP " + resp.status);

            const json = await resp.json();
            if (!json.ok || !json.data) throw new Error("Dados não encontrados");

            const d = json.data;
            state.originalData = d;
            state.salaId = d.sala_id;

            $("display-id").textContent = d.id;

            // Preenche campos readonly
            setVal("data_operacao", fmtDate(d.data_operacao));
            setVal("sala_nome", d.sala_nome);
            setVal("observacoes", d.observacoes);

            // Renderiza itens em modo leitura
            renderItens(d.itens || []);

            // Indicador geral de edição no header
            renderEditadoBadgeHeader(d.editado);

            // Indicador de edição no campo Observações
            renderObservacoesBadge(d.observacoes_editado);

        } catch (e) {
            alert("Erro ao carregar dados: " + e.message);
            console.error(e);
        }
    }

    // ====== Badge "editado" no header ======
    function renderEditadoBadgeHeader(editado) {
        // Remove badge anterior se existir
        const old = document.querySelector('.header-edited-badge');
        if (old) old.remove();

        if (editado) {
            const badge = document.createElement('span');
            badge.className = 'edited-badge header-edited-badge';
            badge.textContent = 'editado';
            badge.style.marginLeft = '12px';
            const h1 = document.querySelector('h1');
            if (h1) h1.appendChild(badge);
        }
    }

    // ====== Badge "editado" nas Observações ======
    function renderObservacoesBadge(editado) {
        const old = document.querySelector('.obs-edited-badge');
        if (old) old.remove();

        if (editado) {
            const label = document.querySelector('label[for="observacoes"]');
            if (label) {
                const badge = document.createElement('span');
                badge.className = 'edited-badge obs-edited-badge';
                badge.textContent = 'editado';
                label.appendChild(badge);
            }
        }
    }

    // ====== Renderizar itens (modo leitura) ======
    function renderItens(itens) {
        const container = $("checklist-items-container");
        if (!container) return;

        if (itens.length === 0) {
            container.innerHTML = '<div class="muted">Nenhum item registrado.</div>';
            return;
        }

        let html = '';
        itens.forEach(it => {
            const isText = it.tipo_widget === 'text';
            const editedTag = it.editado ? '<span class="edited-badge">editado</span>' : '';

            if (isText) {
                const valor = it.valor_texto || '--';
                html += `
                    <div class="check-item-readonly">
                        <div class="check-header">
                            <span class="check-label">${it.item_nome} ${editedTag}</span>
                        </div>
                        <div class="text-value-box">${valor}</div>
                    </div>
                `;
            } else {
                const statusClass = it.status === 'Ok' ? 'status-ok' : 'status-falha';
                const statusIcon = it.status === 'Ok' ? '✅' : '❌';

                let descHtml = '';
                if (it.status === 'Falha' && it.descricao_falha) {
                    descHtml = `
                        <div class="falha-box">
                            <strong>Descrição da falha:</strong> ${it.descricao_falha}
                        </div>
                    `;
                }

                html += `
                    <div class="check-item-readonly">
                        <div class="check-header">
                            <span class="check-label">${it.item_nome} ${editedTag}</span>
                            <span class="check-status ${statusClass}">
                                ${statusIcon} ${it.status}
                            </span>
                        </div>
                        ${descHtml}
                    </div>
                `;
            }
        });

        container.innerHTML = html;
    }

    // ====== Carregar salas (para dropdown de edição) ======
    async function loadSalas() {
        if (state.salasLoaded) return;

        const url = AppConfig.apiUrl(AppConfig.endpoints.lookups.salas);
        const sel = $("sala_id_edit");

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
            state.salasLoaded = true;
        } catch (e) {
            console.error(e);
            sel.innerHTML = '<option value="">Falha ao carregar</option>';
        }
    }

    // ====== Entrar em modo de edição ======
    async function enterEditMode() {
        state.editMode = true;
        const d = state.originalData;
        const form = $("form-checklist-readonly");
        form.classList.add("editing");

        // 1) Data: esconde text, mostra date picker
        $("data_operacao").classList.add("hidden");
        const dateEdit = $("data_operacao_edit");
        dateEdit.classList.remove("hidden");
        dateEdit.value = d.data_operacao; // YYYY-MM-DD

        // 2) Local: esconde text, mostra dropdown
        $("sala_nome").classList.add("hidden");
        const salaEdit = $("sala_id_edit");
        salaEdit.classList.remove("hidden");
        await loadSalas();
        salaEdit.value = String(state.salaId);

        // 3) Observações: habilita edição
        const obs = $("observacoes");
        obs.removeAttribute("readonly");

        // 4) Itens: renderiza em modo editável
        renderItensEditMode(d.itens || []);

        // 5) Botões
        $("btn-editar").classList.add("hidden");
        $("btn-salvar").classList.remove("hidden");
        $("btn-cancelar").classList.remove("hidden");
    }

    // ====== Sair do modo de edição (cancelar) ======
    function exitEditMode() {
        state.editMode = false;
        const d = state.originalData;
        const form = $("form-checklist-readonly");
        form.classList.remove("editing");

        // 1) Data: mostra text, esconde date picker
        $("data_operacao").classList.remove("hidden");
        $("data_operacao_edit").classList.add("hidden");

        // 2) Local: mostra text, esconde dropdown
        $("sala_nome").classList.remove("hidden");
        $("sala_id_edit").classList.add("hidden");

        // 3) Observações: volta readonly e restaura valor original
        const obs = $("observacoes");
        obs.setAttribute("readonly", "");
        obs.value = d.observacoes || "";

        // 4) Itens: renderiza em modo leitura
        renderItens(d.itens || []);

        // 5) Botões
        $("btn-editar").classList.remove("hidden");
        $("btn-salvar").classList.add("hidden");
        $("btn-cancelar").classList.add("hidden");
    }

    // ====== Renderizar itens (modo edição) ======
    function renderItensEditMode(itens) {
        const container = $("checklist-items-container");
        if (!container) return;
        container.innerHTML = '';

        if (itens.length === 0) {
            container.innerHTML = '<div class="muted">Nenhum item registrado.</div>';
            return;
        }

        itens.forEach(it => {
            const div = document.createElement('div');
            div.className = 'check-item-edit';
            div.dataset.itemTipoId = it.item_tipo_id;

            // Label do item
            const labelRow = document.createElement('div');
            labelRow.className = 'check-header';
            const label = document.createElement('span');
            label.className = 'check-label';
            label.textContent = it.item_nome;
            if (it.editado) {
                const badge = document.createElement('span');
                badge.className = 'edited-badge';
                badge.textContent = 'editado';
                label.appendChild(document.createTextNode(' '));
                label.appendChild(badge);
            }
            labelRow.appendChild(label);
            div.appendChild(labelRow);

            if (it.tipo_widget === 'text') {
                // Input de texto editável
                const input = document.createElement('input');
                input.type = 'text';
                input.className = 'edit-text-input';
                input.dataset.itemTipoId = it.item_tipo_id;
                input.value = it.valor_texto || '';
                input.placeholder = 'Digite o valor...';
                div.appendChild(input);
            } else {
                // Radio buttons Ok/Falha
                const radioName = `status_${it.item_tipo_id}`;
                const controls = document.createElement('div');
                controls.className = 'edit-radio-controls';
                controls.innerHTML = `
                    <label class="radio-card-edit">
                        <input type="radio" name="${radioName}" value="Ok" ${it.status === 'Ok' ? 'checked' : ''}>
                        <span class="radio-label-edit">✅ Ok</span>
                    </label>
                    <label class="radio-card-edit">
                        <input type="radio" name="${radioName}" value="Falha" ${it.status === 'Falha' ? 'checked' : ''}>
                        <span class="radio-label-edit">❌ Falha</span>
                    </label>
                `;
                div.appendChild(controls);

                // Container da descrição de falha
                const falhaDiv = document.createElement('div');
                falhaDiv.className = 'edit-falha-container';
                falhaDiv.style.display = it.status === 'Falha' ? 'block' : 'none';
                falhaDiv.innerHTML = `
                    <label>Descrição da falha:</label>
                    <textarea data-item-tipo-id="${it.item_tipo_id}" rows="3"
                        placeholder="Descreva o problema (mínimo 10 caracteres)...">${it.descricao_falha || ''}</textarea>
                    <p class="falha-hint" style="display: none;">Insira no mínimo 10 caracteres</p>
                `;
                div.appendChild(falhaDiv);

                const textarea = falhaDiv.querySelector('textarea');
                const hint = falhaDiv.querySelector('.falha-hint');

                // Evento: trocar radio
                controls.querySelectorAll('input[type="radio"]').forEach(r => {
                    r.addEventListener('change', (e) => {
                        if (e.target.value === 'Falha') {
                            falhaDiv.style.display = 'block';
                            textarea.focus();
                        } else {
                            falhaDiv.style.display = 'none';
                            textarea.value = '';
                            hint.style.display = 'none';
                        }
                    });
                });

                // Evento: validação da descrição de falha
                textarea.addEventListener('input', () => {
                    const len = textarea.value.trim().length;
                    if (len > 0 && len < 10) {
                        hint.style.display = 'block';
                    } else {
                        hint.style.display = 'none';
                    }
                });
            }

            container.appendChild(div);
        });
    }

    // ====== Coletar dados editados ======
    function collectEditData() {
        const itens = [];
        const container = $("checklist-items-container");
        const cards = container.querySelectorAll('.check-item-edit');

        cards.forEach(card => {
            const itemTipoId = parseInt(card.dataset.itemTipoId, 10);

            // Verifica se é text ou radio
            const textInput = card.querySelector('.edit-text-input');
            if (textInput) {
                itens.push({
                    item_tipo_id: itemTipoId,
                    status: "Ok",
                    descricao_falha: null,
                    valor_texto: textInput.value.trim(),
                });
                return;
            }

            const checked = card.querySelector('input[type="radio"]:checked');
            const status = checked ? checked.value : null;
            let descricao_falha = null;

            if (status === 'Falha') {
                const ta = card.querySelector('.edit-falha-container textarea');
                descricao_falha = ta ? ta.value.trim() : '';
            }

            itens.push({
                item_tipo_id: itemTipoId,
                status: status,
                descricao_falha: descricao_falha,
                valor_texto: null,
            });
        });

        return {
            checklist_id: parseInt(checklistId, 10),
            data_operacao: $("data_operacao_edit").value,
            sala_id: parseInt($("sala_id_edit").value, 10),
            observacoes: $("observacoes").value || null,
            itens: itens,
        };
    }

    // ====== Validar dados antes de enviar ======
    function validateEditData(payload) {
        if (!payload.data_operacao) {
            return { valid: false, message: "A data é obrigatória." };
        }
        if (!payload.sala_id || isNaN(payload.sala_id)) {
            return { valid: false, message: "Selecione um local." };
        }

        for (const it of payload.itens) {
            // Itens de texto são opcionais
            if (it.valor_texto !== null) continue;

            if (!it.status) {
                return { valid: false, message: "Todos os itens precisam de um status (Ok ou Falha)." };
            }
            if (it.status === 'Falha') {
                if (!it.descricao_falha || it.descricao_falha.length < 10) {
                    return {
                        valid: false,
                        message: "Itens marcados como Falha precisam de descrição com no mínimo 10 caracteres."
                    };
                }
            }
        }

        return { valid: true };
    }

    // ====== Enviar edição ======
    async function submitEdit() {
        const payload = collectEditData();
        const validation = validateEditData(payload);

        if (!validation.valid) {
            alert(validation.message);
            return;
        }

        const btn = $("btn-salvar");
        const originalTxt = btn.textContent;
        btn.disabled = true;
        btn.textContent = "Salvando...";

        try {
            const url = AppConfig.apiUrl(AppConfig.endpoints.forms.checklistEditar);

            const resp = await Auth.authFetch(url, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });

            if (resp.status === 401 || resp.status === 403) {
                alert("Sem permissão para editar este registro.");
                return;
            }

            const json = await resp.json().catch(() => ({}));

            if (resp.ok && json.ok) {
                alert("Edição salva com sucesso!");
                // Recarrega dados atualizados
                state.editMode = false;
                const form = $("form-checklist-readonly");
                form.classList.remove("editing");

                // Restaura campos de leitura
                $("data_operacao").classList.remove("hidden");
                $("data_operacao_edit").classList.add("hidden");
                $("sala_nome").classList.remove("hidden");
                $("sala_id_edit").classList.add("hidden");
                $("observacoes").setAttribute("readonly", "");

                // Botões
                $("btn-editar").classList.remove("hidden");
                $("btn-salvar").classList.add("hidden");
                $("btn-cancelar").classList.add("hidden");

                // Recarrega dados do servidor
                await loadData();
            } else {
                const msg = json.message || json.error || "Erro ao salvar.";
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
    document.addEventListener("DOMContentLoaded", () => {
        loadData();

        $("btn-editar").addEventListener("click", enterEditMode);
        $("btn-salvar").addEventListener("click", submitEdit);
        $("btn-cancelar").addEventListener("click", exitEditMode);
    });

})();
