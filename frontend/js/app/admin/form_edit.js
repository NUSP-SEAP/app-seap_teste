(function () {
    "use strict";

    // ============================
    // Configuração das entidades
    // ============================

    const ENTITY_CONFIG = {
        salas: {
            apiKey: "salas",
            tableId: "tb-salas",
            cardId: "card-edit-salas",
            title: "Edição de Salas"
        },
        comissoes: {
            apiKey: "comissoes",
            tableId: "tb-comissoes",
            cardId: "card-edit-comissoes",
            title: "Edição de Comissões"
        },
        sala_config: {
            apiKey: "sala-config",
            tableId: "tb-sala-config-itens",
            cardId: "card-edit-sala-config",
            title: "Edição dos Itens de Verificação",
            sectionId: "sala-config-section"
        }
    };

    const state = {
        activeEntityKey: null,
        entities: {
            salas: {
                loaded: false,
                dirty: false,
                items: [],
                originalItems: [],
                insertIndex: null  // posição da linha em branco entre as ativas
            },
            comissoes: {
                loaded: false,
                dirty: false,
                items: [],
                originalItems: [],
                insertIndex: null
            },
            sala_config: {
                loaded: false,
                dirty: false,
                items: [],
                originalItems: [],
                insertIndex: null,
                salasLoaded: false,
                salas: [],
                selectedSalaId: null
            }
        }
    };

    let dragState = null; // usado para controlar o drag and drop

    // ============================
    // Helpers gerais
    // ============================

    function getFormEditBaseEndpoint() {
        if (typeof AppConfig === "undefined" || !AppConfig.endpoints || !AppConfig.endpoints.formEdit) {
            console.error("Configuração AppConfig.endpoints.formEdit não encontrada.");
            return null;
        }
        return AppConfig.endpoints.formEdit.base;
    }

    async function fetchJson(url, options) {
        if (!window.Auth || typeof Auth.authFetch !== "function") {
            console.error("Auth.authFetch não está disponível");
            return null;
        }
        try {
            const resp = await Auth.authFetch(url, options);
            if (!resp.ok) {
                console.error("HTTP", resp.status, "ao chamar", url);
                return null;
            }
            return await resp.json();
        } catch (e) {
            console.error("Erro ao chamar", url, e);
            return null;
        }
    }

    function cloneItems(items) {
        return (items || []).map(function (it) {
            return {
                id: it.id,
                nome: it.nome,
                ativo: !!it.ativo
            };
        });
    }

    // conta quantos itens ativos existem no topo do array
    function countActive(items) {
        const arr = items || [];
        let i = 0;
        while (i < arr.length && arr[i].ativo) {
            i++;
        }
        return i;
    }

    function markDirty(entityKey, dirty) {
        const ent = state.entities[entityKey];
        if (!ent) return;
        ent.dirty = (dirty === undefined) ? true : !!dirty;
        updateActionsState();
    }

    function updateActionsState() {
        const salvarBtn = document.getElementById("btn-form-edit-salvar");
        const cancelarBtn = document.getElementById("btn-form-edit-cancelar");

        if (!salvarBtn || !cancelarBtn) return;

        const activeKey = state.activeEntityKey;
        if (!activeKey) {
            salvarBtn.disabled = true;
            cancelarBtn.disabled = true;
            return;
        }

        const ent = state.entities[activeKey];
        salvarBtn.disabled = !ent.dirty;
        cancelarBtn.disabled = !ent.dirty;
    }

    function showSectionForEntity(entityKey) {
        const headerEl = document.getElementById("form-edit-header");
        const titleEl = document.getElementById("form-edit-title");
        const actionsEl = document.getElementById("form-edit-actions");
        const btnAplicarTodas = document.getElementById("btn-sala-config-aplicar-todas");

        // esconde todas as tabelas/seções e remove destaque dos cards
        Object.keys(ENTITY_CONFIG).forEach(function (key) {
            const cfg = ENTITY_CONFIG[key];
            const tableId = cfg.tableId;
            const tbl = document.getElementById(tableId);
            if (tbl) {
                tbl.classList.add("hidden");
            }
            // Para sala_config, esconde a seção especial
            if (cfg.sectionId) {
                const section = document.getElementById(cfg.sectionId);
                if (section) section.classList.add("hidden");
            }
            const cardId = cfg.cardId;
            const cardEl = document.getElementById(cardId);
            if (cardEl) {
                cardEl.classList.remove("card-active");
            }
        });

        // Sempre esconde o botão "Aplicar a Todas" inicialmente
        if (btnAplicarTodas) btnAplicarTodas.classList.add("hidden");

        if (!entityKey) {
            if (headerEl) headerEl.classList.add("hidden");
            if (actionsEl) actionsEl.classList.add("hidden");
            updateActionsState();
            return;
        }

        const cfg = ENTITY_CONFIG[entityKey];
        if (!cfg) return;

        const cardEl = document.getElementById(cfg.cardId);

        if (cardEl) cardEl.classList.add("card-active");
        if (headerEl) headerEl.classList.remove("hidden");
        if (titleEl) titleEl.textContent = cfg.title;
        if (actionsEl) actionsEl.classList.remove("hidden");

        // Para sala_config, mostra a seção especial ao invés da tabela diretamente
        if (entityKey === "sala_config") {
            const section = document.getElementById(cfg.sectionId);
            if (section) section.classList.remove("hidden");
            if (btnAplicarTodas) btnAplicarTodas.classList.remove("hidden");
        } else {
            const tbl = document.getElementById(cfg.tableId);
            if (tbl) tbl.classList.remove("hidden");
        }

        updateActionsState();
    }

    // ============================
    // Carregamento de dados
    // ============================

    async function loadEntity(entityKey) {
        const cfg = ENTITY_CONFIG[entityKey];
        if (!cfg) return;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const endpoint = `${base}/${cfg.apiKey}/list`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const tbl = document.getElementById(cfg.tableId);
        if (tbl) {
            const tbody = tbl.querySelector("tbody");
            if (tbody) {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="4" class="empty-state">Carregando...</td>
                    </tr>
                `;
            }
        }

        const json = await fetchJson(url);
        if (!json || !json.success) {
            console.error("Falha ao carregar dados de", entityKey, json);
            if (tbl) {
                const tbody = tbl.querySelector("tbody");
                if (tbody) {
                    tbody.innerHTML = `
                        <tr>
                            <td colspan="4" class="empty-state">
                                Erro ao carregar dados. Tente novamente.
                            </td>
                        </tr>
                    `;
                }
            }
            return;
        }

        const items = (json.items || []).map(function (it) {
            return {
                id: it.id,
                nome: it.nome || "",
                ativo: !!it.ativo
            };
        });

        const ent = state.entities[entityKey];
        ent.items = items;
        ent.originalItems = cloneItems(items);
        ent.loaded = true;
        ent.dirty = false;
        ent.insertIndex = null;

        renderEntityTable(entityKey);
    }

    // ============================
    // Renderização de tabela
    // ============================

    function renderEntityTable(entityKey) {
        // Para sala_config, usa renderização específica
        if (entityKey === "sala_config") {
            renderSalaConfigTable();
            return;
        }

        const cfg = ENTITY_CONFIG[entityKey];
        if (!cfg) return;

        const ent = state.entities[entityKey];
        const tbl = document.getElementById(cfg.tableId);
        if (!tbl) return;

        const tbody = tbl.querySelector("tbody");
        if (!tbody) return;

        const items = ent.items || [];

        // Reorganiza: ativos no topo, inativos depois
        const activeItems = [];
        const inactiveItems = [];
        items.forEach(function (it) {
            if (it.ativo) activeItems.push(it);
            else inactiveItems.push(it);
        });

        const canonical = activeItems.concat(inactiveItems);
        ent.items = canonical;

        const activeCount = activeItems.length;
        let insertIndex = ent.insertIndex;
        if (typeof insertIndex !== "number" || insertIndex < 0 || insertIndex > activeCount) {
            insertIndex = activeCount;
        }
        ent.insertIndex = insertIndex;

        function buildActiveRow(item, index) {
            const pos = index + 1;
            const itemIndex = index;
            const checkedAttr = item.ativo ? "checked" : "";

            const rowClasses = ["form-edit-row"];
            if (item._highlight) {
                rowClasses.push("form-edit-row-moved");
            }

            return `
            <tr class="${rowClasses.join(" ")}"
                data-type="item"
                data-item-index="${itemIndex}"
                data-active-index="${index}"
                draggable="true">
                <td class="drag-cell"><span title="Arrastar para reordenar">⋮⋮</span></td>
                <td class="position-cell">${pos}</td>
                <td class="name-cell">${escapeHtml(item.nome)}</td>
                <td class="ativo-cell">
                    <div class="form-edit-checkbox">
                        <input type="checkbox" class="form-edit-checkbox-ativo" ${checkedAttr}>
                    </div>
                </td>
            </tr>
        `;
        }

        function buildInactiveRow(item, index) {
            const itemIndex = index;
            const checkedAttr = item.ativo ? "checked" : "";

            return `
                <tr class="form-edit-row form-edit-row-inactive" data-type="inactive" data-item-index="${itemIndex}">
                    <td class="drag-cell"><span title="Item desativado">⋮⋮</span></td>
                    <td class="position-cell"></td>
                    <td class="name-cell">${escapeHtml(item.nome)}</td>
                    <td class="ativo-cell">
                        <div class="form-edit-checkbox">
                            <input type="checkbox" class="form-edit-checkbox-ativo" ${checkedAttr}>
                        </div>
                    </td>
                </tr>
            `;
        }

        function buildBlankRow() {
            const inputId = `form-edit-new-name-${entityKey}`;

            return `
                <tr class="form-edit-row form-edit-row-blank" data-type="blank" data-active-index="${insertIndex}" draggable="true">
                    <td class="drag-cell"><span title="Arrastar para escolher a posição do novo item">⋮⋮</span></td>
                    <td class="position-cell"></td>
                    <td class="name-cell">
                        <input type="text" id="${inputId}" class="form-edit-input-name" placeholder="Novo registro...">
                    </td>
                    <td class="ativo-cell">
                        <div class="form-edit-checkbox">
                            <input type="checkbox" disabled>
                        </div>
                    </td>
                </tr>
            `;
        }

        let html = "";

        for (let i = 0; i < activeCount; i++) {
            if (i === insertIndex) {
                html += buildBlankRow();
            }
            html += buildActiveRow(canonical[i], i);
        }
        if (insertIndex === activeCount) {
            html += buildBlankRow();
        }

        for (let i = activeCount; i < canonical.length; i++) {
            html += buildInactiveRow(canonical[i], i);
        }

        if (!html) {
            html = `
                <tr>
                    <td colspan="4" class="empty-state">Nenhum registro cadastrado.</td>
                </tr>
            `;
        }

        tbody.innerHTML = html;

        attachRowEvents(entityKey);
        setupBlankRowInput(entityKey);
        updateActionsState();
    }

    function escapeHtml(str) {
        if (str == null) return "";
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // ============================
    // Eventos das linhas
    // ============================

    function attachRowEvents(entityKey) {
        const cfg = ENTITY_CONFIG[entityKey];
        if (!cfg) return;

        const tbl = document.getElementById(cfg.tableId);
        if (!tbl) return;
        const tbody = tbl.querySelector("tbody");
        if (!tbody) return;

        // Drag & Drop (apenas linhas com draggable="true")
        const draggableRows = tbody.querySelectorAll("tr[draggable='true']");
        draggableRows.forEach(function (tr) {
            tr.addEventListener("dragstart", onRowDragStart);
            tr.addEventListener("dragover", onRowDragOver);
            tr.addEventListener("drop", onRowDrop);
            tr.addEventListener("dragend", onRowDragEnd);
        });

        // Duplo clique para editar nome (somente itens ativos)
        const nameCells = tbody.querySelectorAll("tr[data-type='item'] td.name-cell");
        nameCells.forEach(function (td) {
            td.addEventListener("dblclick", function () {
                startEditName(entityKey, td);
            });
        });

        // Checkbox Ativo/Ativa (itens ativos e inativos)
        const checkboxes = tbody.querySelectorAll("input.form-edit-checkbox-ativo");
        checkboxes.forEach(function (chk) {
            chk.addEventListener("change", function () {
                const row = chk.closest("tr");
                if (!row) return;

                const idx = parseInt(row.getAttribute("data-item-index"), 10);
                if (isNaN(idx)) return;

                handleAtivoChange(entityKey, idx, chk.checked);
            });
        });

    }

    function setupBlankRowInput(entityKey) {
        const input = document.getElementById(`form-edit-new-name-${entityKey}`);
        if (!input) return;

        input.addEventListener("keydown", function (ev) {
            if (ev.key === "Enter") {
                ev.preventDefault();
                input.blur();
            } else if (ev.key === "Escape") {
                ev.preventDefault();
                input.value = "";
            }
        });

        input.addEventListener("blur", function () {
            const value = input.value.trim();
            if (!value) return;
            createNewItemFromBlankRow(entityKey, value);
        });
    }

    function startEditName(entityKey, cell) {
        const row = cell.closest("tr");
        if (!row) return;
        const idx = parseInt(row.getAttribute("data-item-index"), 10);
        if (isNaN(idx)) return;

        const ent = state.entities[entityKey];
        const item = (ent.items || [])[idx];
        if (!item || !item.ativo) return;

        if (cell.querySelector("input")) return;

        const current = item.nome || "";
        const input = document.createElement("input");
        input.type = "text";
        input.value = current;
        input.className = "form-edit-input-name";

        cell.innerHTML = "";
        cell.appendChild(input);
        input.focus();
        input.select();

        function commit() {
            const newVal = input.value.trim();
            if (newVal && newVal !== item.nome) {
                item.nome = newVal;

                // Marca linha como modificada
                item._highlight = true;

                markDirty(entityKey);
            }
            renderEntityTable(entityKey);
        }

        input.addEventListener("blur", commit);
        input.addEventListener("keydown", function (ev) {
            if (ev.key === "Enter") {
                ev.preventDefault();
                input.blur();
            } else if (ev.key === "Escape") {
                ev.preventDefault();
                renderEntityTable(entityKey);
            }
        });
    }

    function handleAtivoChange(entityKey, index, checked) {
        const ent = state.entities[entityKey];
        if (!ent || !Array.isArray(ent.items)) return;

        const items = ent.items.slice();
        const item = items[index];
        if (!item) return;

        const novoAtivo = !!checked;
        if (item.ativo === novoAtivo) {
            return;
        }

        item.ativo = novoAtivo;

        // Marca linha como modificada
        item._highlight = true;

        // Sempre que muda ativo/inativo, a linha em branco volta para o final
        ent.items = items;
        ent.insertIndex = null;

        markDirty(entityKey);
        renderEntityTable(entityKey);
    }


    function createNewItemFromBlankRow(entityKey, nome) {
        const ent = state.entities[entityKey];
        const items = ent.items || [];
        const activeCount = countActive(items);

        let insertIndex = ent.insertIndex;
        if (typeof insertIndex !== "number" || insertIndex < 0 || insertIndex > activeCount) {
            insertIndex = activeCount;
        }

        const novo = {
            id: null,
            nome: nome,
            ativo: true,
            _highlight: true
        };

        // insere o novo item entre as linhas ativas
        items.splice(insertIndex, 0, novo);
        ent.items = items;
        ent.insertIndex = null; // nova linha em branco vai para o final

        markDirty(entityKey);
        renderEntityTable(entityKey);
    }

    // ============================
    // Drag and Drop
    // ============================

    function onRowDragStart(ev) {
        const tr = ev.currentTarget;
        if (!tr) return;

        const table = tr.closest("table");
        if (!table) return;

        const entityKey = table.getAttribute("data-entity-key");
        const type = tr.getAttribute("data-type");
        const activeIndex = parseInt(tr.getAttribute("data-active-index"), 10);

        dragState = {
            entityKey: entityKey,
            type: type,
            fromActiveIndex: isNaN(activeIndex) ? null : activeIndex
        };

        if (ev.dataTransfer) {
            ev.dataTransfer.effectAllowed = "move";
        }
    }

    function onRowDragOver(ev) {
        ev.preventDefault();
        if (ev.dataTransfer) {
            ev.dataTransfer.dropEffect = "move";
        }
    }

    function onRowDrop(ev) {
        ev.preventDefault();

        const tr = ev.currentTarget;
        if (!tr || !dragState) return;

        const targetType = tr.getAttribute("data-type");
        const targetActiveIndex = parseInt(tr.getAttribute("data-active-index"), 10);
        const entityKey = dragState.entityKey;

        if (!entityKey) return;

        if (dragState.type === "item") {
            // Reordenar apenas entre itens ativos
            if (targetType !== "item" && targetType !== "blank") return;

            const fromIdx = dragState.fromActiveIndex;
            let toIdx = isNaN(targetActiveIndex) ? fromIdx : targetActiveIndex;

            if (fromIdx == null || isNaN(fromIdx)) return;
            if (toIdx == null || isNaN(toIdx)) return;
            if (fromIdx === toIdx) return;

            reorderActiveItems(entityKey, fromIdx, toIdx);
            markDirty(entityKey);
            renderEntityTable(entityKey);
        } else if (dragState.type === "blank") {
            // Mover apenas relativo a itens ativos
            if (targetType !== "item") return;

            const toIdx = isNaN(targetActiveIndex) ? null : targetActiveIndex;
            if (toIdx == null) return;

            const ent = state.entities[entityKey];
            const items = ent.items || [];
            const activeCount = countActive(items);

            let newInsert = toIdx;
            if (newInsert < 0) newInsert = 0;
            if (newInsert > activeCount) newInsert = activeCount;

            ent.insertIndex = newInsert;
            // mover a linha em branco não torna "sujo"
            renderEntityTable(entityKey);
        }
    }

    function onRowDragEnd() {
        dragState = null;
    }

    function reorderActiveItems(entityKey, fromActiveIndex, toActiveIndex) {
        if (fromActiveIndex === toActiveIndex) return;

        const ent = state.entities[entityKey];
        const items = ent.items || [];
        if (!items.length) return;

        // considera que os itens ativos estão no topo do array
        const activeCount = countActive(items);
        if (fromActiveIndex < 0 || fromActiveIndex >= activeCount) return;
        if (toActiveIndex < 0 || toActiveIndex >= activeCount) return;

        const movedArr = items.splice(fromActiveIndex, 1);
        if (!movedArr.length) return;
        const moved = movedArr[0];
        items.splice(toActiveIndex, 0, moved);

        // Limpa destaque anterior
        // items.forEach(function (it) {
        //     if (it && typeof it === "object") {
        //         delete it._highlight;
        //     }
        // });

        // Marca o item movido para destaque visual
        moved._highlight = true;

        ent.items = items;
    }

    // ============================
    // Ações dos botões
    // ============================

    async function handleSalvarClick() {
        const entKey = state.activeEntityKey;
        if (!entKey) return;

        const ent = state.entities[entKey];
        if (!ent.dirty) return;

        // Sala config tem handler específico
        if (entKey === "sala_config") {
            await handleSalaConfigSalvar();
            return;
        }

        const cfg = ENTITY_CONFIG[entKey];
        if (!cfg) return;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const endpoint = `${base}/${cfg.apiKey}/save`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const payload = {
            items: (ent.items || []).map(function (it) {
                return {
                    id: it.id,
                    nome: it.nome,
                    ativo: !!it.ativo
                };
            })
        };

        const json = await fetchJson(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(payload)
        });

        if (!json || !json.success) {
            alert("Erro ao salvar alterações. Verifique o console para detalhes.");
            console.error("Erro ao salvar", entKey, json);
            return;
        }

        // Após salvar, recarrega a lista para essa entidade
        await loadEntity(entKey);
        markDirty(entKey, false);
    }

    function handleCancelarClick() {
        const entKey = state.activeEntityKey;
        if (!entKey) return;

        const ent = state.entities[entKey];
        if (!ent.loaded) return;

        if (entKey === "sala_config") {
            ent.items = cloneSalaConfigItems(ent.originalItems);
        } else {
            ent.items = cloneItems(ent.originalItems);
        }

        ent.insertIndex = null;
        ent.dirty = false;

        if (entKey === "sala_config") {
            renderSalaConfigTable();
        } else {
            renderEntityTable(entKey);
        }

        updateActionsState();
    }

    // ============================
    // Configuração de Itens por Sala
    // ============================

    async function loadSalasForConfig() {
        const ent = state.entities.sala_config;
        if (ent.salasLoaded) return;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const endpoint = `${base}/salas/list`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const json = await fetchJson(url);
        if (!json || !json.success) {
            console.error("Falha ao carregar salas", json);
            return;
        }

        ent.salas = (json.items || []).filter(function (sala) {
            return sala.ativo; // Apenas salas ativas
        });
        ent.salasLoaded = true;

        renderSalaSelect();
    }

    function renderSalaSelect() {
        const ent = state.entities.sala_config;
        const select = document.getElementById("sala-config-select");
        if (!select) return;

        const salas = ent.salas || [];

        if (salas.length === 0) {
            select.innerHTML = '<option value="">Nenhum local disponível</option>';
            select.disabled = true;
            return;
        }

        const opts = ['<option value="">Selecione um local...</option>'].concat(
            salas.map(function (sala) {
                return '<option value="' + sala.id + '">' + escapeHtml(sala.nome) + '</option>';
            })
        ).join('');

        select.innerHTML = opts;
        select.disabled = false;

        // Se já tinha uma sala selecionada, restaura
        if (ent.selectedSalaId) {
            select.value = ent.selectedSalaId;
        }
    }

    async function loadSalaConfigItems(salaId) {
        const ent = state.entities.sala_config;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const endpoint = `${base}/sala-config/${salaId}/list`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const tbl = document.getElementById("tb-sala-config-itens");
        if (tbl) {
            const tbody = tbl.querySelector("tbody");
            if (tbody) {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="5" class="empty-state">Carregando configuração...</td>
                    </tr>
                `;
            }
        }

        const json = await fetchJson(url);
        if (!json || !json.success) {
            console.error("Falha ao carregar config da sala", json);
            if (tbl) {
                const tbody = tbl.querySelector("tbody");
                if (tbody) {
                    tbody.innerHTML = `
                        <tr>
                            <td colspan="5" class="empty-state">Erro ao carregar configuração.</td>
                        </tr>
                    `;
                }
            }
            return;
        }

        const items = json.items || [];

        ent.items = items;
        ent.originalItems = cloneSalaConfigItems(items);
        ent.loaded = true;
        ent.dirty = false;
        ent.insertIndex = null;

        renderSalaConfigTable();
    }

    function cloneSalaConfigItems(items) {
        return (items || []).map(function (it) {
            return {
                id: it.id,
                item_tipo_id: it.item_tipo_id,
                nome: it.nome,
                tipo_widget: it.tipo_widget || "radio",
                ativo: !!it.ativo
            };
        });
    }

    function renderSalaConfigTable() {
        const ent = state.entities.sala_config;
        const tbl = document.getElementById("tb-sala-config-itens");
        if (!tbl) return;

        const tbody = tbl.querySelector("tbody");
        if (!tbody) return;

        const items = ent.items || [];

        // Reorganiza: ativos no topo, inativos depois
        const activeItems = [];
        const inactiveItems = [];
        items.forEach(function (it) {
            if (it.ativo) activeItems.push(it);
            else inactiveItems.push(it);
        });

        const canonical = activeItems.concat(inactiveItems);
        ent.items = canonical;

        const activeCount = activeItems.length;
        let insertIndex = ent.insertIndex;
        if (typeof insertIndex !== "number" || insertIndex < 0 || insertIndex > activeCount) {
            insertIndex = activeCount;
        }
        ent.insertIndex = insertIndex;

        function buildActiveRow(item, index) {
            const pos = index + 1;
            const itemIndex = index;
            const checkedAtivo = item.ativo ? "checked" : "";

            const rowClasses = ["form-edit-row"];
            if (item._highlight) {
                rowClasses.push("form-edit-row-moved");
            }

            const tipoWidget = item.tipo_widget || "radio";

            return `
            <tr class="${rowClasses.join(" ")}"
                data-type="item"
                data-item-index="${itemIndex}"
                data-active-index="${index}"
                draggable="true">
                <td class="drag-cell"><span title="Arrastar para reordenar">⋮⋮</span></td>
                <td class="position-cell">${pos}</td>
                <td class="name-cell">${escapeHtml(item.nome)}</td>
                <td class="tipo-cell">
                    <select class="form-edit-select-tipo" data-item-index="${itemIndex}">
                        <option value="radio" ${tipoWidget === "radio" ? "selected" : ""}>Ok/Falha</option>
                        <option value="text" ${tipoWidget === "text" ? "selected" : ""}>Texto livre</option>
                    </select>
                </td>
                <td class="ativo-cell">
                    <div class="form-edit-checkbox">
                        <input type="checkbox" class="form-edit-checkbox-ativo" ${checkedAtivo}>
                    </div>
                </td>
            </tr>
        `;
        }

        function buildInactiveRow(item, index) {
            const itemIndex = index;
            const checkedAtivo = item.ativo ? "checked" : "";
            const tipoLabel = item.tipo_widget === "text" ? "Texto livre" : "Ok/Falha";

            return `
                <tr class="form-edit-row form-edit-row-inactive" data-type="inactive" data-item-index="${itemIndex}">
                    <td class="drag-cell"><span title="Item desativado">⋮⋮</span></td>
                    <td class="position-cell"></td>
                    <td class="name-cell">${escapeHtml(item.nome)}</td>
                    <td class="tipo-cell" style="color: #64748b; font-size: 0.9em;">${tipoLabel}</td>
                    <td class="ativo-cell">
                        <div class="form-edit-checkbox">
                            <input type="checkbox" class="form-edit-checkbox-ativo" ${checkedAtivo}>
                        </div>
                    </td>
                </tr>
            `;
        }

        function buildBlankRow() {
            return `
                <tr class="form-edit-row form-edit-row-blank" data-type="blank" data-active-index="${insertIndex}" draggable="true">
                    <td class="drag-cell"><span title="Arrastar para escolher a posição">⋮⋮</span></td>
                    <td class="position-cell"></td>
                    <td class="name-cell">
                        <input type="text" id="sala-config-new-item-input" class="form-edit-input-name" placeholder="Digite o nome do novo item...">
                    </td>
                    <td class="tipo-cell">
                        <select id="sala-config-new-tipo-input" class="form-edit-select-tipo">
                            <option value="radio">Ok/Falha</option>
                            <option value="text">Texto livre</option>
                        </select>
                    </td>
                    <td class="ativo-cell"></td>
                </tr>
            `;
        }

        let html = "";

        for (let i = 0; i < activeCount; i++) {
            if (i === insertIndex) {
                html += buildBlankRow();
            }
            html += buildActiveRow(canonical[i], i);
        }
        if (insertIndex === activeCount) {
            html += buildBlankRow();
        }

        for (let i = activeCount; i < canonical.length; i++) {
            html += buildInactiveRow(canonical[i], i);
        }

        if (!html) {
            html = `
                <tr>
                    <td colspan="5" class="empty-state">Nenhum item configurado.</td>
                </tr>
            `;
        }

        tbody.innerHTML = html;

        attachSalaConfigRowEvents();
        setupSalaConfigBlankRow();
        updateActionsState();

        // Mostra a tabela e a info
        tbl.classList.remove("hidden");
        const infoEl = document.getElementById("sala-config-info");
        if (infoEl) infoEl.classList.remove("hidden");
    }

    function attachSalaConfigRowEvents() {
        const tbl = document.getElementById("tb-sala-config-itens");
        if (!tbl) return;
        const tbody = tbl.querySelector("tbody");
        if (!tbody) return;

        // Drag & Drop (apenas linhas com draggable="true")
        const draggableRows = tbody.querySelectorAll("tr[draggable='true']");
        draggableRows.forEach(function (tr) {
            tr.addEventListener("dragstart", onRowDragStart);
            tr.addEventListener("dragover", onRowDragOver);
            tr.addEventListener("drop", onRowDrop);
            tr.addEventListener("dragend", onRowDragEnd);
        });

        // Duplo clique para editar nome (somente itens ativos)
        const nameCells = tbody.querySelectorAll("tr[data-type='item'] td.name-cell");
        nameCells.forEach(function (td) {
            td.addEventListener("dblclick", function () {
                startEditSalaConfigName(td);
            });
        });

        // Checkbox Ativo/Ativa
        const checkboxesAtivo = tbody.querySelectorAll("input.form-edit-checkbox-ativo");
        checkboxesAtivo.forEach(function (chk) {
            chk.addEventListener("change", function () {
                const row = chk.closest("tr");
                if (!row) return;

                const idx = parseInt(row.getAttribute("data-item-index"), 10);
                if (isNaN(idx)) return;

                handleSalaConfigAtivoChange(idx, chk.checked);
            });
        });

        // Dropdown Tipo
        const selectsTipo = tbody.querySelectorAll("select.form-edit-select-tipo");
        selectsTipo.forEach(function (select) {
            select.addEventListener("change", function () {
                const idx = parseInt(select.getAttribute("data-item-index"), 10);
                if (isNaN(idx)) return;
                handleSalaConfigTipoChange(idx, select.value);
            });
        });
    }

    function setupSalaConfigBlankRow() {
        const input = document.getElementById("sala-config-new-item-input");
        if (!input) return;

        input.addEventListener("keydown", function (ev) {
            if (ev.key === "Enter") {
                ev.preventDefault();
                input.blur();
            } else if (ev.key === "Escape") {
                ev.preventDefault();
                input.value = "";
            }
        });

        input.addEventListener("blur", function () {
            const value = input.value.trim();
            if (!value) return;
            createNewSalaConfigItemFromName(value);
        });
    }

    function startEditSalaConfigName(cell) {
        const row = cell.closest("tr");
        if (!row) return;
        const idx = parseInt(row.getAttribute("data-item-index"), 10);
        if (isNaN(idx)) return;

        const ent = state.entities.sala_config;
        const item = (ent.items || [])[idx];
        if (!item || !item.ativo) return;

        if (cell.querySelector("input")) return;

        const current = item.nome || "";
        const input = document.createElement("input");
        input.type = "text";
        input.value = current;
        input.className = "form-edit-input-name";

        cell.innerHTML = "";
        cell.appendChild(input);
        input.focus();
        input.select();

        function commit() {
            const newVal = input.value.trim();
            if (newVal && newVal !== item.nome) {
                item.nome = newVal;
                item._highlight = true;
                markDirty("sala_config");
            }
            renderSalaConfigTable();
        }

        input.addEventListener("blur", commit);
        input.addEventListener("keydown", function (ev) {
            if (ev.key === "Enter") {
                ev.preventDefault();
                input.blur();
            } else if (ev.key === "Escape") {
                ev.preventDefault();
                renderSalaConfigTable();
            }
        });
    }

    function createNewSalaConfigItemFromName(nome) {
        const ent = state.entities.sala_config;

        // Captura tipo_widget do dropdown da linha em branco
        const tipoSelect = document.getElementById("sala-config-new-tipo-input");
        const tipoWidget = tipoSelect ? tipoSelect.value : "radio";

        const items = ent.items || [];
        const activeCount = countActive(items);

        let insertIndex = ent.insertIndex;
        if (typeof insertIndex !== "number" || insertIndex < 0 || insertIndex > activeCount) {
            insertIndex = activeCount;
        }

        const novo = {
            id: null,
            item_tipo_id: null,
            nome: nome,
            tipo_widget: tipoWidget,
            ativo: true,
            _highlight: true
        };

        items.splice(insertIndex, 0, novo);
        ent.items = items;
        ent.insertIndex = null;

        markDirty("sala_config");
        renderSalaConfigTable();
    }

    function handleSalaConfigAtivoChange(index, checked) {
        const ent = state.entities.sala_config;
        if (!ent || !Array.isArray(ent.items)) return;

        const items = ent.items.slice();
        const item = items[index];
        if (!item) return;

        const novoAtivo = !!checked;
        if (item.ativo === novoAtivo) return;

        item.ativo = novoAtivo;
        item._highlight = true;

        ent.items = items;
        ent.insertIndex = null;

        markDirty("sala_config");
        renderSalaConfigTable();
    }

    function handleSalaConfigTipoChange(index, novoTipo) {
        const ent = state.entities.sala_config;
        if (!ent || !Array.isArray(ent.items)) return;

        const item = ent.items[index];
        if (!item || !item.ativo || item.tipo_widget === novoTipo) return;

        item.tipo_widget = novoTipo;
        item._highlight = true;

        markDirty("sala_config");
        updateActionsState();
    }

    async function handleSalaConfigSalvar() {
        const ent = state.entities.sala_config;
        if (!ent.dirty || !ent.selectedSalaId) return;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const salaId = ent.selectedSalaId;
        const endpoint = `${base}/sala-config/${salaId}/save`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const payload = {
            sala_id: salaId,
            items: (ent.items || []).filter(function (it) {
                return it.ativo;
            }).map(function (it, idx) {
                return {
                    nome: it.nome,
                    tipo_widget: it.tipo_widget || "radio",
                    ordem: idx + 1,
                    ativo: true
                };
            })
        };

        const json = await fetchJson(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });

        if (!json || !json.success) {
            alert("Erro ao salvar configuração: " + (json && json.message ? json.message : "Erro desconhecido"));
            return;
        }

        await loadSalaConfigItems(salaId);
        markDirty("sala_config", false);
        alert("Configuração salva com sucesso!");
    }

    async function handleSalaConfigAplicarTodas() {
        const ent = state.entities.sala_config;
        if (!ent.selectedSalaId) return;

        const confirmMsg = "Deseja aplicar a configuração atual a TODOS os locais?\n\n" +
                          "Isso irá sobrescrever a configuração individual de cada local.";

        if (!confirm(confirmMsg)) return;

        const base = getFormEditBaseEndpoint();
        if (!base) return;

        const endpoint = `${base}/sala-config/aplicar-todas`;
        const url = AppConfig.apiUrl ? AppConfig.apiUrl(endpoint) : endpoint;

        const payload = {
            source_sala_id: ent.selectedSalaId,
            items: (ent.items || []).filter(function (it) {
                return it.ativo;
            }).map(function (it, idx) {
                return {
                    nome: it.nome,
                    tipo_widget: it.tipo_widget || "radio",
                    ordem: idx + 1,
                    ativo: true
                };
            })
        };

        const json = await fetchJson(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });

        if (!json || !json.success) {
            alert("Erro ao aplicar configuração: " + (json && json.message ? json.message : "Erro desconhecido"));
            return;
        }

        const salasAtualizadas = json.salas_atualizadas || 0;
        alert("Configuração aplicada com sucesso a " + salasAtualizadas + " local(is)!");
        markDirty("sala_config", false);
    }

    // ============================
    // Inicialização
    // ============================

    function init() {
        const cards = document.querySelectorAll(".form-edit-card");
        cards.forEach(function (card) {
            card.addEventListener("click", function (ev) {
                ev.preventDefault();
                const entityKey = card.getAttribute("data-entity");
                if (!entityKey || !ENTITY_CONFIG[entityKey]) return;

                // Toggle: se já está ativa, fecha; senão ativa
                if (state.activeEntityKey === entityKey) {
                    state.activeEntityKey = null;
                    showSectionForEntity(null);
                } else {
                    state.activeEntityKey = entityKey;
                    showSectionForEntity(entityKey);
                    const ent = state.entities[entityKey];

                    // Sala config tem lógica especial
                    if (entityKey === "sala_config") {
                        if (!ent.salasLoaded) {
                            loadSalasForConfig();
                        }
                    } else {
                        if (!ent.loaded) {
                            loadEntity(entityKey);
                        } else {
                            renderEntityTable(entityKey);
                        }
                    }
                }
            });
        });

        const salvarBtn = document.getElementById("btn-form-edit-salvar");
        const cancelarBtn = document.getElementById("btn-form-edit-cancelar");
        const aplicarTodasBtn = document.getElementById("btn-sala-config-aplicar-todas");

        if (salvarBtn) {
            salvarBtn.addEventListener("click", function (ev) {
                ev.preventDefault();
                handleSalvarClick();
            });
        }
        if (cancelarBtn) {
            cancelarBtn.addEventListener("click", function (ev) {
                ev.preventDefault();
                handleCancelarClick();
            });
        }
        if (aplicarTodasBtn) {
            aplicarTodasBtn.addEventListener("click", function (ev) {
                ev.preventDefault();
                handleSalaConfigAplicarTodas();
            });
        }

        // Dropdown de seleção de sala
        const salaSelect = document.getElementById("sala-config-select");
        if (salaSelect) {
            salaSelect.addEventListener("change", function (ev) {
                const salaId = ev.target.value;
                if (!salaId) {
                    const ent = state.entities.sala_config;
                    ent.selectedSalaId = null;
                    ent.loaded = false;
                    ent.items = [];
                    const tbl = document.getElementById("tb-sala-config-itens");
                    if (tbl) tbl.classList.add("hidden");
                    const infoEl = document.getElementById("sala-config-info");
                    if (infoEl) infoEl.classList.add("hidden");
                    return;
                }

                const ent = state.entities.sala_config;
                ent.selectedSalaId = parseInt(salaId, 10);
                loadSalaConfigItems(ent.selectedSalaId);
            });
        }

        // Começa sem nenhuma entidade selecionada
        showSectionForEntity(null);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }

})();
