// app/js/app/admin/table_filters.js
(function () {
    "use strict";

    // ======================================================================
    // Registry / estado interno
    // ======================================================================

    /** @type {Map<string, any>} */
    const _registry = new Map();

    /** Painel único global (apenas 1 aberto por vez) */
    let _panelEl = null;
    let _panelState = {
        open: false,
        tableId: null,
        columnKey: null,
        anchorEl: null,
    };

    // ======================================================================
    // Utils
    // ======================================================================

    function _isObject(v) {
        return v && typeof v === "object" && !Array.isArray(v);
    }

    function _debounce(fn, wait) {
        let t = null;
        return function (...args) {
            clearTimeout(t);
            t = setTimeout(() => fn.apply(this, args), wait);
        };
    }

    function _normalizeStr(v) {
        if (v === null || v === undefined) return "";
        return String(v);
    }

    function _toISODate(value) {
        // aceita "YYYY-MM-DD" ou Date
        if (!value) return "";
        if (value instanceof Date && !isNaN(value)) {
            const y = value.getFullYear();
            const m = String(value.getMonth() + 1).padStart(2, "0");
            const d = String(value.getDate()).padStart(2, "0");
            return `${y}-${m}-${d}`;
        }
        const s = String(value);
        // não força formato; assume que já vem correto
        return s;
    }

    function _fmtDateBR(isoDate) {
        // "YYYY-MM-DD" -> "DD/MM/YYYY"
        const s = _normalizeStr(isoDate);
        const parts = s.split("-");
        if (parts.length === 3) {
            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }
        return s || "--";
    }

    function _cmpText(a, b) {
        return String(a).localeCompare(String(b), "pt-BR", { sensitivity: "base" });
    }

    function _cmpNumber(a, b) {
        const na = Number(a);
        const nb = Number(b);
        if (!isFinite(na) && !isFinite(nb)) return 0;
        if (!isFinite(na)) return 1;
        if (!isFinite(nb)) return -1;
        return na - nb;
    }

    function _cmpDateISO(a, b) {
        // "YYYY-MM-DD" lexicográfico funciona bem
        return String(a).localeCompare(String(b));
    }

    function _inferColumnKey(th, index) {
        if (!th) return null;

        // prioridade:
        // 1) data-column (padrão que vamos adotar)
        // 2) data-sort (já existe nas colunas sortables)
        // 3) data-col (existe em subtable dinâmica do seu código)
        const key =
            (th.dataset && th.dataset.column) ||
            (th.dataset && th.dataset.sort) ||
            (th.dataset && th.dataset.col) ||
            null;

        if (key) return key;

        // fallback opcional (evita ícone em colunas sem chave)
        // return `col_${index}`;
        return null;
    }

    function _ensureFiltersObject(stateObj) {
        if (!stateObj) return;
        if (!_isObject(stateObj.filters)) stateObj.filters = {};
    }

    function _ensureColumnFilter(stateObj, columnKey, columnType) {
        _ensureFiltersObject(stateObj);

        if (!_isObject(stateObj.filters[columnKey])) {
            stateObj.filters[columnKey] = {};
        }

        const f = stateObj.filters[columnKey];

        if (typeof f.text !== "string") f.text = "";
        if (!Array.isArray(f.values) && f.values !== null && f.values !== undefined) {
            f.values = null;
        }
        // Convenção:
        // - f.values === null  -> "sem filtro por valores" (equivalente a selecionar todos)
        // - f.values === [...] -> filtro por inclusão (apenas esses valores)
        if (f.values === undefined) f.values = null;

        if (columnType === "date") {
            if (!_isObject(f.range)) f.range = {};
            if (typeof f.range.from !== "string") f.range.from = "";
            if (typeof f.range.to !== "string") f.range.to = "";
        } else {
            // não date: removemos range para evitar lixo
            if (f.range !== undefined) delete f.range;
        }

        return f;
    }

    function _isColumnFilterActive(colType, f) {
        if (!f) return false;

        if (typeof f.text === "string" && f.text.trim() !== "") return true;
        if (Array.isArray(f.values) && f.values.length > 0) return true;

        if (colType === "date" && f.range && (f.range.from || f.range.to)) return true;
        return false;
    }

    function _getCompactFilters(filtersObj) {
        // Remove chaves vazias para enviar no request
        const out = {};
        if (!_isObject(filtersObj)) return out;

        Object.keys(filtersObj).forEach((k) => {
            const f = filtersObj[k];
            if (!_isObject(f)) return;

            const nf = {};
            if (typeof f.text === "string" && f.text.trim() !== "") {
                nf.text = f.text.trim();
            }
            if (Array.isArray(f.values) && f.values.length > 0) {
                nf.values = f.values.slice();
            }
            if (_isObject(f.range) && (f.range.from || f.range.to)) {
                nf.range = {
                    from: f.range.from || "",
                    to: f.range.to || "",
                };
            }

            if (Object.keys(nf).length > 0) out[k] = nf;
        });

        return out;
    }

    function _ensurePanel() {
        if (_panelEl) return _panelEl;

        const panel = document.createElement("div");
        panel.className = "tf-panel";
        panel.style.position = "fixed";
        panel.style.zIndex = "9999";
        panel.style.minWidth = "280px";
        panel.style.maxWidth = "340px";
        panel.style.maxHeight = "420px";
        panel.style.overflow = "auto";
        panel.style.background = "#fff";
        panel.style.border = "1px solid rgba(0,0,0,0.15)";
        panel.style.borderRadius = "10px";
        panel.style.boxShadow = "0 10px 30px rgba(0,0,0,0.15)";
        panel.style.padding = "10px";
        panel.style.display = "none";

        // evita clique dentro fechar o painel (fechamento é no document)
        panel.addEventListener("mousedown", (e) => {
            e.stopPropagation();
        });

        document.body.appendChild(panel);
        _panelEl = panel;

        // Fecha ao clicar fora
        document.addEventListener("mousedown", () => {
            _closePanel();
        });

        // Fecha com ESC
        document.addEventListener("keydown", (e) => {
            if (e.key === "Escape") _closePanel();
        });

        // Reposiciona ao redimensionar
        window.addEventListener("resize", () => {
            if (_panelState.open) _positionPanel(_panelState.anchorEl);
        });

        return panel;
    }

    function _positionPanel(anchorEl) {
        if (!_panelEl || !_panelState.open || !anchorEl) return;

        // Mostra para medir corretamente
        _panelEl.style.display = "block";

        const rect = anchorEl.getBoundingClientRect();
        const panelRect = _panelEl.getBoundingClientRect();

        const margin = 8;

        // tenta abrir abaixo, alinhado à direita do ícone
        let top = rect.bottom + 6;
        let left = rect.right - panelRect.width;

        // Ajuste horizontal
        if (left < margin) left = margin;
        const maxLeft = window.innerWidth - panelRect.width - margin;
        if (left > maxLeft) left = Math.max(margin, maxLeft);

        // Ajuste vertical (se não couber abaixo, abre acima)
        const maxTop = window.innerHeight - panelRect.height - margin;
        if (top > maxTop) {
            top = rect.top - panelRect.height - 6;
        }
        if (top < margin) top = margin;

        _panelEl.style.top = `${top}px`;
        _panelEl.style.left = `${left}px`;
    }

    function _closePanel() {
        if (!_panelEl) return;
        _panelEl.style.display = "none";
        _panelEl.innerHTML = "";

        _panelState.open = false;
        _panelState.tableId = null;
        _panelState.columnKey = null;
        _panelState.anchorEl = null;
    }

    // ======================================================================
    // Montagem de ícones no header
    // ======================================================================

    function _getColumns(ctx) {
        if (!ctx) return {};
        if (typeof ctx.getColumns === "function") {
            const cols = ctx.getColumns();
            return _isObject(cols) ? cols : {};
        }
        return _isObject(ctx.columns) ? ctx.columns : {};
    }

    function _getColConfig(ctx, columnKey) {
        const cols = _getColumns(ctx);
        const c = cols[columnKey];
        return _isObject(c) ? c : {};
    }

    function _isFilterable(ctx, columnKey, thEl) {
        const cfg = _getColConfig(ctx, columnKey);
        if (cfg.filterable === false) return false;

        // se for coluna "Ação" por exemplo e quiser esconder depois, usa filterable:false
        // aqui, se não existe config e também não tem chave, não cria
        if (!columnKey) return false;

        // opção: se th tiver data-no-filter="1"
        if (thEl && thEl.dataset && thEl.dataset.noFilter === "1") return false;

        return true;
    }

    function _mountHeaderFilters(ctx) {
        if (!ctx || !ctx.tableEl) return;

        const table = ctx.tableEl;
        const thead = table.tHead || table.querySelector(":scope > thead");
        if (!thead) return;

        const ths = thead.querySelectorAll("th");
        if (!ths || ths.length === 0) return;

        ths.forEach((th, idx) => {
            const columnKey = _inferColumnKey(th, idx);
            if (!_isFilterable(ctx, columnKey, th)) return;

            // evita duplicar
            if (th.querySelector(":scope > .tf-filter-btn")) return;

            // garante posicionamento para o botão
            const currentPos = window.getComputedStyle(th).position;
            if (currentPos === "static" || !currentPos) {
                th.style.position = "relative";
            }

            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "tf-filter-btn";
            btn.title = "Filtrar / Classificar";

            // visual simples (CSS pode sobrescrever)
            btn.style.position = "absolute";
            btn.style.right = "6px";
            btn.style.bottom = "4px";
            btn.style.width = "18px";
            btn.style.height = "18px";
            btn.style.border = "0";
            btn.style.background = "transparent";
            btn.style.cursor = "pointer";
            btn.style.padding = "0";
            btn.style.lineHeight = "18px";
            btn.style.fontSize = "12px";
            btn.style.opacity = "0.85";

            btn.setAttribute("aria-label", `Filtro da coluna ${columnKey}`);
            btn.dataset.tfKey = columnKey;
            btn.innerHTML = "▾";

            btn.addEventListener("mousedown", (e) => {
                // impede que o click no TH dispare sort do bindSortHeaders
                e.preventDefault();
                e.stopPropagation();
            });

            btn.addEventListener("click", (e) => {
                e.preventDefault();
                e.stopPropagation();

                // toggle: se já está aberto na mesma coluna, fecha
                if (_panelState.open && _panelState.tableId === ctx.tableId && _panelState.columnKey === columnKey) {
                    _closePanel();
                    return;
                }

                _openPanelForColumn(ctx, columnKey, th, btn);
            });

            th.appendChild(btn);
        });

        _updateHeaderIndicators(ctx);
    }

    function _updateHeaderIndicators(ctx) {
        if (!ctx || !ctx.tableEl || !ctx.state) return;
        _ensureFiltersObject(ctx.state);

        const table = ctx.tableEl;
        const thead = table.tHead || table.querySelector(":scope > thead");
        if (!thead) return;

        const buttons = thead.querySelectorAll(".tf-filter-btn");
        buttons.forEach((btn) => {
            const colKey = btn.dataset.tfKey;
            const cfg = _getColConfig(ctx, colKey);
            const colType = cfg.type || "text";
            const f = ctx.state.filters[colKey];
            const active = _isColumnFilterActive(colType, f);

            if (active) {
                btn.classList.add("tf-active");
                btn.style.opacity = "1";
                btn.style.fontWeight = "700";
            } else {
                btn.classList.remove("tf-active");
                btn.style.opacity = "0.85";
                btn.style.fontWeight = "400";
            }
        });
    }

    // ======================================================================
    // Construção do painel
    // ======================================================================

    function _openPanelForColumn(ctx, columnKey, thEl, anchorBtn) {
        if (!ctx || !ctx.state) return;

        const panel = _ensurePanel();
        const cfg = _getColConfig(ctx, columnKey);

        const colType = cfg.type || "text";
        const sortKey =
            cfg.sortKey ||
            (thEl && thEl.dataset && (thEl.dataset.sort || thEl.dataset.column)) ||
            columnKey;

        const sortable =
            cfg.sortable === true ||
            (thEl && thEl.classList && thEl.classList.contains("sortable")) ||
            !!(thEl && thEl.dataset && thEl.dataset.sort);

        const headerLabel = (cfg.label || (thEl ? thEl.textContent : "") || columnKey || "").trim();

        const f = _ensureColumnFilter(ctx.state, columnKey, colType);

        // monta HTML do painel (com DOM nodes, sem innerHTML para labels de valores)
        panel.innerHTML = "";

        // --- título ---
        const title = document.createElement("div");
        title.className = "tf-title";
        title.style.display = "flex";
        title.style.alignItems = "center";
        title.style.justifyContent = "space-between";
        title.style.gap = "10px";
        title.style.marginBottom = "8px";

        const titleLeft = document.createElement("div");
        titleLeft.style.fontWeight = "700";
        titleLeft.style.fontSize = "13px";
        titleLeft.textContent = headerLabel || "Coluna";

        const closeBtn = document.createElement("button");
        closeBtn.type = "button";
        closeBtn.className = "tf-close";
        closeBtn.textContent = "✕";
        closeBtn.title = "Fechar";
        closeBtn.style.border = "0";
        closeBtn.style.background = "transparent";
        closeBtn.style.cursor = "pointer";
        closeBtn.style.fontSize = "14px";
        closeBtn.style.opacity = "0.7";
        closeBtn.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();
            _closePanel();
        });

        title.appendChild(titleLeft);
        title.appendChild(closeBtn);
        panel.appendChild(title);

        // --- classificar ---
        if (sortable && sortKey) {
            const sortWrap = document.createElement("div");
            sortWrap.className = "tf-section tf-sort";
            sortWrap.style.borderTop = "1px solid rgba(0,0,0,0.08)";
            sortWrap.style.paddingTop = "8px";

            const sortLabel = document.createElement("div");
            sortLabel.style.fontSize = "12px";
            sortLabel.style.opacity = "0.85";
            sortLabel.style.marginBottom = "6px";
            sortLabel.textContent = "Classificar por:";
            sortWrap.appendChild(sortLabel);

            const row = document.createElement("div");
            row.style.display = "flex";
            row.style.gap = "8px";

            const btnAsc = document.createElement("button");
            btnAsc.type = "button";
            btnAsc.className = "tf-btn tf-sort-asc";
            btnAsc.textContent = "Crescente";
            _styleMiniButton(btnAsc);

            const btnDesc = document.createElement("button");
            btnDesc.type = "button";
            btnDesc.className = "tf-btn tf-sort-desc";
            btnDesc.textContent = "Decrescente";
            _styleMiniButton(btnDesc);

            // destaca se já estiver ativo
            if (ctx.state.sort === sortKey && ctx.state.dir === "asc") _setActiveMiniButton(btnAsc, true);
            if (ctx.state.sort === sortKey && ctx.state.dir === "desc") _setActiveMiniButton(btnDesc, true);

            btnAsc.addEventListener("click", (e) => {
                e.preventDefault();
                e.stopPropagation();

                ctx.state.sort = sortKey;
                ctx.state.dir = "asc";
                if (typeof ctx.state.page === "number") ctx.state.page = 1;

                _updateHeaderIndicators(ctx);
                _notifyChange(ctx, { immediate: true });
                _closePanel();
            });

            btnDesc.addEventListener("click", (e) => {
                e.preventDefault();
                e.stopPropagation();

                ctx.state.sort = sortKey;
                ctx.state.dir = "desc";
                if (typeof ctx.state.page === "number") ctx.state.page = 1;

                _updateHeaderIndicators(ctx);
                _notifyChange(ctx, { immediate: true });
                _closePanel();
            });

            row.appendChild(btnAsc);
            row.appendChild(btnDesc);
            sortWrap.appendChild(row);
            panel.appendChild(sortWrap);
        }

        // --- filtro: texto ---
        const filterWrap = document.createElement("div");
        filterWrap.className = "tf-section tf-filter";
        filterWrap.style.borderTop = "1px solid rgba(0,0,0,0.08)";
        filterWrap.style.paddingTop = "8px";
        filterWrap.style.marginTop = "8px";

        const filterLabel = document.createElement("div");
        filterLabel.style.fontSize = "12px";
        filterLabel.style.opacity = "0.85";
        filterLabel.style.marginBottom = "6px";
        filterLabel.textContent = "Filtro:";
        filterWrap.appendChild(filterLabel);

        const input = document.createElement("input");
        input.type = "text";
        input.className = "tf-input";
        input.placeholder = "Pesquisar (nesta coluna)";
        input.value = (f.text || "");
        input.style.width = "100%";
        input.style.boxSizing = "border-box";
        input.style.padding = "8px 10px";
        input.style.borderRadius = "8px";
        input.style.border = "1px solid rgba(0,0,0,0.15)";
        input.style.outline = "none";
        input.style.fontSize = "13px";

        filterWrap.appendChild(input);

        // debounce do filtro textual (para evitar flood de requests)
        const debouncedTextApply = _debounce(() => {
            if (typeof ctx.state.page === "number") ctx.state.page = 1;
            _updateHeaderIndicators(ctx);
            _notifyChange(ctx, { immediate: true });
        }, ctx.debounceMs);

        input.addEventListener("input", (e) => {
            f.text = e.target.value || "";
            // Atualiza lista de valores enquanto digita (UX tipo Excel)
            _renderValuesList(ctx, columnKey, colType, panel, { keepScroll: true });
            debouncedTextApply();
        });

        panel.appendChild(filterWrap);

        // --- filtro: período (somente date) ---
        if (colType === "date") {
            const rangeWrap = document.createElement("div");
            rangeWrap.className = "tf-section tf-range";
            rangeWrap.style.borderTop = "1px solid rgba(0,0,0,0.08)";
            rangeWrap.style.paddingTop = "8px";
            rangeWrap.style.marginTop = "8px";

            const rangeLabel = document.createElement("div");
            rangeLabel.style.fontSize = "12px";
            rangeLabel.style.opacity = "0.85";
            rangeLabel.style.marginBottom = "6px";
            rangeLabel.textContent = "Período (Data):";
            rangeWrap.appendChild(rangeLabel);

            const row = document.createElement("div");
            row.style.display = "grid";
            row.style.gridTemplateColumns = "1fr 1fr";
            row.style.gap = "8px";

            const from = document.createElement("input");
            from.type = "date";
            from.className = "tf-date tf-from";
            from.value = _toISODate(f.range && f.range.from);
            _styleDateInput(from);

            const to = document.createElement("input");
            to.type = "date";
            to.className = "tf-date tf-to";
            to.value = _toISODate(f.range && f.range.to);
            _styleDateInput(to);

            from.addEventListener("change", () => {
                f.range.from = from.value || "";
                if (typeof ctx.state.page === "number") ctx.state.page = 1;
                _updateHeaderIndicators(ctx);
                _notifyChange(ctx, { immediate: true });
            });

            to.addEventListener("change", () => {
                f.range.to = to.value || "";
                if (typeof ctx.state.page === "number") ctx.state.page = 1;
                _updateHeaderIndicators(ctx);
                _notifyChange(ctx, { immediate: true });
            });

            row.appendChild(from);
            row.appendChild(to);
            rangeWrap.appendChild(row);

            panel.appendChild(rangeWrap);
        }

        // --- valores únicos (checkboxes) ---
        const valuesWrap = document.createElement("div");
        valuesWrap.className = "tf-section tf-values";
        valuesWrap.style.borderTop = "1px solid rgba(0,0,0,0.08)";
        valuesWrap.style.paddingTop = "8px";
        valuesWrap.style.marginTop = "8px";

        const valuesLabel = document.createElement("div");
        valuesLabel.style.fontSize = "12px";
        valuesLabel.style.opacity = "0.85";
        valuesLabel.style.marginBottom = "6px";
        valuesLabel.textContent = "Valores:";
        valuesWrap.appendChild(valuesLabel);

        const listHost = document.createElement("div");
        listHost.className = "tf-values-host";
        valuesWrap.appendChild(listHost);

        panel.appendChild(valuesWrap);

        // --- ações (limpar) ---
        const actions = document.createElement("div");
        actions.className = "tf-actions";
        actions.style.borderTop = "1px solid rgba(0,0,0,0.08)";
        actions.style.paddingTop = "10px";
        actions.style.marginTop = "10px";
        actions.style.display = "flex";
        actions.style.justifyContent = "flex-end";
        actions.style.gap = "8px";

        const btnClear = document.createElement("button");
        btnClear.type = "button";
        btnClear.className = "tf-btn tf-clear";
        btnClear.textContent = "Limpar filtro";
        _styleMiniButton(btnClear);

        btnClear.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();

            // reset somente desta coluna
            f.text = "";
            f.values = null;
            if (colType === "date") {
                if (!_isObject(f.range)) f.range = {};
                f.range.from = "";
                f.range.to = "";
            }

            if (typeof ctx.state.page === "number") ctx.state.page = 1;
            _updateHeaderIndicators(ctx);
            _notifyChange(ctx, { immediate: true });

            // atualiza UI sem fechar
            _openPanelForColumn(ctx, columnKey, thEl, anchorBtn);
        });

        actions.appendChild(btnClear);
        panel.appendChild(actions);

        // marca como aberto e renderiza valores
        _panelState.open = true;
        _panelState.tableId = ctx.tableId;
        _panelState.columnKey = columnKey;
        _panelState.anchorEl = anchorBtn;

        _renderValuesList(ctx, columnKey, colType, panel, { keepScroll: false });

        _positionPanel(anchorBtn);
        input.focus();
        input.select();
    }

    function _styleMiniButton(btn) {
        btn.style.padding = "7px 10px";
        btn.style.borderRadius = "8px";
        btn.style.border = "1px solid rgba(0,0,0,0.15)";
        btn.style.background = "#f7f7f7";
        btn.style.cursor = "pointer";
        btn.style.fontSize = "12px";
    }

    function _setActiveMiniButton(btn, active) {
        if (!btn) return;
        if (active) {
            btn.style.background = "#e9f2ff";
            btn.style.borderColor = "#9ac2ff";
            btn.style.fontWeight = "700";
        } else {
            btn.style.background = "#f7f7f7";
            btn.style.borderColor = "rgba(0,0,0,0.15)";
            btn.style.fontWeight = "400";
        }
    }

    function _styleDateInput(inp) {
        inp.style.width = "100%";
        inp.style.boxSizing = "border-box";
        inp.style.padding = "8px 10px";
        inp.style.borderRadius = "8px";
        inp.style.border = "1px solid rgba(0,0,0,0.15)";
        inp.style.outline = "none";
        inp.style.fontSize = "13px";
    }

    function _parseBoolFront(v) {
        const s = _normalizeStr(v).trim().toLowerCase();
        if (!s) return null;
        if (["true", "1", "sim", "s", "yes", "y"].includes(s)) return true;
        if (["false", "0", "nao", "não", "n", "no"].includes(s)) return false;
        return null;
    }

    function _distinctFromTableDOM(ctx, columnKey, colType) {
        // Fallback: se ainda não temos meta.distinct do backend,
        // extraímos valores únicos do DOM (página atual) para não mostrar lista vazia.
        try {
            if (!ctx || !ctx.tableEl) return [];

            const table = ctx.tableEl;
            const thead = table.tHead || table.querySelector(":scope > thead");
            if (!thead) return [];

            const ths = Array.from(thead.querySelectorAll("th"));
            if (!ths.length) return [];

            let colIndex = -1;
            for (let i = 0; i < ths.length; i++) {
                const k = _inferColumnKey(ths[i], i);
                if (k === columnKey) {
                    colIndex = i;
                    break;
                }
            }
            if (colIndex < 0) return [];

            const tbody = (table.tBodies && table.tBodies[0]) ? table.tBodies[0] : table.querySelector(":scope > tbody");
            if (!tbody) return [];

            const rows = Array.from(tbody.querySelectorAll(":scope > tr"));
            const map = new Map(); // value -> label

            rows.forEach((tr) => {
                // ignora linhas de detalhe/accordion
                if (tr.classList && tr.classList.contains("accordion-child")) return;
                // linhas de detalhe costumam ter 1 TD com colspan
                const tdColspan = tr.querySelector("td[colspan]");
                if (tdColspan && tr.children && tr.children.length === 1) return;

                if (!tr.children || tr.children.length <= colIndex) return;
                const cell = tr.children[colIndex];
                if (!cell) return;

                let label = _normalizeStr(cell.textContent || "").trim();
                if (!label) return;

                let value = label;

                if (colType === "date") {
                    // aceita DD/MM/YYYY ou YYYY-MM-DD
                    const m = label.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
                    if (m) {
                        value = `${m[3]}-${m[2]}-${m[1]}`;
                        label = value;
                    }
                }

                if (colType === "bool") {
                    const b = _parseBoolFront(label);
                    if (b === null) return;
                    value = b ? "true" : "false";
                    label = b ? "Sim" : "Não";
                }

                if (!map.has(value)) map.set(value, label);
            });

            const arr = Array.from(map.entries()).map(([value, label]) => ({ value, label }));
            if (colType === "date") arr.sort((a, b) => _cmpDateISO(a.value, b.value));
            else arr.sort((a, b) => _cmpText(a.label, b.label));
            return arr;
        } catch (e) {
            console.error("TableFilter distinctFromTableDOM error:", e);
            return [];
        }
    }

    function _getDistinctOptions(ctx, columnKey, colType) {
        // retorna [{ value: "X", label: "X" }, ...]
        if (!ctx) return [];
        if (!_isObject(ctx.distinct)) ctx.distinct = {};

        // Preferência:
        // 1) meta.distinct do backend (ctx.distinct)
        // 2) fallback pelo DOM (página atual) — evita painel “Nenhum valor” antes de carregar distinct
        let arr = Array.isArray(ctx.distinct[columnKey]) ? ctx.distinct[columnKey] : [];
        if (!arr || arr.length === 0) {
            arr = _distinctFromTableDOM(ctx, columnKey, colType);
        }

        // garante formato
        const out = arr
            .map((it) => {
                if (_isObject(it) && ("value" in it)) {
                    return {
                        value: _normalizeStr(it.value),
                        label: _normalizeStr(it.label ?? it.value),
                    };
                }
                // se vier string
                return { value: _normalizeStr(it), label: _normalizeStr(it) };
            })
            .filter((it) => it.value !== "");

        // Ordena conforme tipo
        if (colType === "date") out.sort((a, b) => _cmpDateISO(a.value, b.value));
        else out.sort((a, b) => _cmpText(a.label, b.label));

        return out;
    }

    function _renderValuesList(ctx, columnKey, colType, panelEl, { keepScroll }) {
        if (!ctx || !panelEl || !ctx.state) return;

        const host = panelEl.querySelector(".tf-values-host");
        if (!host) return;

        const cfg = _getColConfig(ctx, columnKey);
        const f = _ensureColumnFilter(ctx.state, columnKey, colType);

        const previousScroll = host.scrollTop;

        host.innerHTML = "";

        const options = _getDistinctOptions(ctx, columnKey, colType);

        // Filtro do texto também filtra a lista (UX)
        const needle = (f.text || "").trim().toLowerCase();
        const filteredOptions = needle
            ? options.filter((opt) => opt.label.toLowerCase().includes(needle))
            : options;

        // "Selecionar tudo"
        const selectAllRow = document.createElement("label");
        selectAllRow.style.display = "flex";
        selectAllRow.style.alignItems = "center";
        selectAllRow.style.gap = "8px";
        selectAllRow.style.padding = "6px 2px";
        selectAllRow.style.cursor = "pointer";
        selectAllRow.style.userSelect = "none";

        const cbAll = document.createElement("input");
        cbAll.type = "checkbox";
        cbAll.className = "tf-cb-all";
        cbAll.checked = (f.values === null);
        cbAll.addEventListener("change", (e) => {
            e.stopPropagation();

            // sempre volta para "all" quando marcar
            if (cbAll.checked) {
                f.values = null;
            } else {
                // Não adotamos "nenhum selecionado" (para não zerar tabela)
                // Se usuário desmarcar, mantemos como "all".
                cbAll.checked = true;
                f.values = null;
            }

            if (typeof ctx.state.page === "number") ctx.state.page = 1;
            _updateHeaderIndicators(ctx);
            _notifyChange(ctx, { immediate: true });

            // re-render
            _renderValuesList(ctx, columnKey, colType, panelEl, { keepScroll: true });
        });

        const allText = document.createElement("span");
        allText.textContent = "(Selecionar tudo)";
        allText.style.fontSize = "13px";

        selectAllRow.appendChild(cbAll);
        selectAllRow.appendChild(allText);
        host.appendChild(selectAllRow);

        // lista de valores
        const list = document.createElement("div");
        list.className = "tf-values-list";
        list.style.marginTop = "6px";
        list.style.paddingTop = "6px";
        list.style.borderTop = "1px dashed rgba(0,0,0,0.12)";

        if (filteredOptions.length === 0) {
            const empty = document.createElement("div");
            empty.textContent = "Nenhum valor para exibir.";
            empty.style.fontSize = "12px";
            empty.style.opacity = "0.7";
            empty.style.padding = "6px 2px";
            list.appendChild(empty);
        } else {
            const selected = Array.isArray(f.values) ? new Set(f.values.map(_normalizeStr)) : null;

            filteredOptions.forEach((opt) => {
                const row = document.createElement("label");
                row.style.display = "flex";
                row.style.alignItems = "center";
                row.style.gap = "8px";
                row.style.padding = "6px 2px";
                row.style.cursor = "pointer";
                row.style.userSelect = "none";

                const cb = document.createElement("input");
                cb.type = "checkbox";
                cb.className = "tf-cb-value";

                // Excel-like visual: se não há filtro por valores, mostramos tudo marcado
                if (f.values === null) {
                    cb.checked = true;
                } else {
                    cb.checked = selected ? selected.has(opt.value) : false;
                }

                const text = document.createElement("span");
                text.textContent = (colType === "date") ? _fmtDateBR(opt.label || opt.value) : (opt.label || opt.value);
                text.style.fontSize = "13px";

                cb.addEventListener("change", (e) => {
                    e.stopPropagation();

                    // Se está em "all" (f.values === null), um clique em um valor vira "apenas este valor".
                    // Isso atende seu requisito: "marcou um valor -> filtra por aquele valor" (sem precisar desmarcar tudo).
                    if (f.values === null) {
                        f.values = [opt.value];
                    } else {
                        const cur = new Set((Array.isArray(f.values) ? f.values : []).map(_normalizeStr));
                        if (cb.checked) cur.add(opt.value);
                        else cur.delete(opt.value);

                        const next = Array.from(cur);

                        // se zerar, voltamos para "all" (evita tabela vazia por engano)
                        f.values = next.length > 0 ? next : null;
                    }

                    if (typeof ctx.state.page === "number") ctx.state.page = 1;
                    _updateHeaderIndicators(ctx);
                    _notifyChange(ctx, { immediate: true });

                    // re-render para refletir o novo estado (all vs subset)
                    _renderValuesList(ctx, columnKey, colType, panelEl, { keepScroll: true });
                });

                row.appendChild(cb);
                row.appendChild(text);
                list.appendChild(row);
            });
        }

        host.appendChild(list);

        // restaura scroll se necessário
        if (keepScroll) host.scrollTop = previousScroll;
    }

    // ======================================================================
    // Notificação de mudança (recarregar tabela)
    // ======================================================================

    function _notifyChange(ctx, { immediate }) {
        if (!ctx || typeof ctx.onChange !== "function") return;

        // Atualiza indicador de filtro no header imediatamente
        _updateHeaderIndicators(ctx);

        if (immediate) {
            ctx.onChange();
            return;
        }

        if (typeof ctx._debouncedOnChange === "function") {
            ctx._debouncedOnChange();
        } else {
            ctx.onChange();
        }
    }

    // ======================================================================
    // MutationObserver (headers dinâmicos)
    // ======================================================================

    function _setupObserver(ctx) {
        if (!ctx || !ctx.tableEl) return;
        if (ctx._observer) return;

        const thead = ctx.tableEl.querySelector("thead");
        if (!thead) return;

        ctx._observer = new MutationObserver(() => {
            // Ao reconstruir thead (como tb-operacoes faz), os ícones somem.
            // Remontamos automaticamente.
            try {
                // IMPORTANTE:
                // Em tabelas que recriam o <thead> a cada reload (ex.: tb-operacoes),
                // fechar o painel aqui faz parecer que "qualquer clique" dentro do
                // filtro fecha o popover.
                //
                // Em vez disso, remontamos os ícones e, se o painel estava aberto
                // nessa tabela/coluna, tentamos "re-ancorar" no novo botão.

                const wasOpen = _panelState.open && _panelState.tableId === ctx.tableId;
                const openKey = wasOpen ? _panelState.columnKey : null;

                _mountHeaderFilters(ctx);

                if (wasOpen && openKey && _panelEl) {
                    const theadNow = ctx.tableEl.tHead || ctx.tableEl.querySelector(":scope > thead");
                    const newAnchor = theadNow
                        ? theadNow.querySelector(`.tf-filter-btn[data-tf-key="${openKey}"]`)
                        : null;

                    if (newAnchor) {
                        _panelState.anchorEl = newAnchor;
                        _positionPanel(newAnchor);
                    } else {
                        // A coluna sumiu (ex.: mudou o modo/colunas) → fecha.
                        _closePanel();
                    }
                }
            } catch (e) {
                console.error("TableFilter observer error:", e);
            }
        });

        ctx._observer.observe(thead, { childList: true, subtree: true });
    }

    // ======================================================================
    // API Pública
    // ======================================================================

    /**
     * Inicializa o TableFilter em uma tabela.
     *
     * @param {Object} options
     * @param {string} options.tableId - ID da tabela (ex: "tb-anormalidades")
     * @param {Object} options.state - objeto de estado da tabela (ex: anomState)
     * @param {Object} [options.columns] - mapa de colunas { colKey: { type, dataKey, ... } }
     * @param {Function} [options.getColumns] - alternativa a columns: retorna mapa conforme estado (ex: groupBySala)
     * @param {Function} options.onChange - callback para recarregar dados (loadX)
     * @param {number} [options.debounceMs=300] - debounce do filtro textual por coluna
     */
    function init(options) {
        if (!options || !options.tableId) {
            console.error("TableFilter.init: options.tableId é obrigatório");
            return;
        }
        if (!options.state || typeof options.state !== "object") {
            console.error("TableFilter.init: options.state é obrigatório");
            return;
        }
        if (typeof options.onChange !== "function") {
            console.error("TableFilter.init: options.onChange (função) é obrigatório");
            return;
        }

        const tableEl = document.getElementById(options.tableId);
        if (!tableEl) {
            console.warn(`TableFilter.init: tabela #${options.tableId} não encontrada`);
            return;
        }

        _ensureFiltersObject(options.state);

        const ctx = {
            tableId: options.tableId,
            tableEl,
            state: options.state,
            columns: _isObject(options.columns) ? options.columns : {},
            getColumns: typeof options.getColumns === "function" ? options.getColumns : null,
            onChange: options.onChange,
            debounceMs: Number.isFinite(options.debounceMs) ? options.debounceMs : 300,
            distinct: {}, // { colKey: [{value,label}] }
            _observer: null,
            _debouncedOnChange: null,
        };

        // debounce padrão para chamadas "não imediatas" (se você quiser usar em algum lugar)
        ctx._debouncedOnChange = _debounce(() => {
            ctx.onChange();
        }, ctx.debounceMs);

        _registry.set(ctx.tableId, ctx);

        // Monta os ícones no header atual
        _mountHeaderFilters(ctx);

        // Observa mudanças no thead (tabelas com header refeito em JS)
        _setupObserver(ctx);
    }

    /**
     * Re-monta ícones manualmente (normalmente você não precisa, pois temos MutationObserver).
     */
    function mount(tableId) {
        const ctx = _registry.get(tableId);
        if (!ctx) return;
        _mountHeaderFilters(ctx);
    }

    /**
     * Atualiza os valores únicos (checkboxes) com base nos rows retornados pelo backend.
     *
     * @param {string} tableId
     * @param {Array<Object>} rows
     */
    function updateDistinctValues(tableId, rows) {
        const ctx = _registry.get(tableId);
        if (!ctx) return;

        const cols = _getColumns(ctx);
        const nextDistinct = {};

        const data = Array.isArray(rows) ? rows : [];

        Object.keys(cols).forEach((colKey) => {
            const cfg = _isObject(cols[colKey]) ? cols[colKey] : {};
            if (cfg.filterable === false) return;

            const colType = cfg.type || "text";
            const dataKey = cfg.dataKey || colKey;

            const getValue = (typeof cfg.getValue === "function")
                ? cfg.getValue
                : (row) => row ? row[dataKey] : null;

            const toValue = (typeof cfg.toValue === "function")
                ? cfg.toValue
                : (v) => {
                    if (v === null || v === undefined) return "";
                    if (colType === "bool") return v ? "true" : "false";
                    if (colType === "date") return _toISODate(v);
                    return _normalizeStr(v).trim();
                };

            const toLabel = (typeof cfg.toLabel === "function")
                ? cfg.toLabel
                : (v) => {
                    if (v === null || v === undefined || v === "") return "";
                    if (colType === "bool") return v ? "Sim" : "Não";
                    if (colType === "date") return _toISODate(v);
                    return _normalizeStr(v).trim();
                };

            const map = new Map(); // value -> label

            data.forEach((row) => {
                const raw = getValue(row);
                const vv = toValue(raw, row);
                if (!vv) return;

                const ll = toLabel(raw, row) || vv;
                if (!map.has(vv)) map.set(vv, ll);
            });

            const arr = Array.from(map.entries()).map(([value, label]) => ({ value, label }));

            // ordena conforme tipo
            if (colType === "date") arr.sort((a, b) => _cmpDateISO(a.value, b.value));
            else if (colType === "number") arr.sort((a, b) => _cmpNumber(a.value, b.value));
            else arr.sort((a, b) => _cmpText(a.label, b.label));

            nextDistinct[colKey] = arr;
        });

        ctx.distinct = nextDistinct;

        // Se o painel estiver aberto nessa tabela/coluna, re-renderiza lista de valores
        if (_panelState.open && _panelState.tableId === tableId && _panelEl) {
            const colKey = _panelState.columnKey;
            const cfg = _getColConfig(ctx, colKey);
            const colType = cfg.type || "text";
            _renderValuesList(ctx, colKey, colType, _panelEl, { keepScroll: true });
        }
    }

    /**
     * Define valores únicos manualmente (útil se o backend retornar `meta.distinct` pronto).
     * values pode ser array de string OU array de {value,label}.
     */
    function setDistinctValues(tableId, columnKey, values) {
        const ctx = _registry.get(tableId);
        if (!ctx) return;
        if (!_isObject(ctx.distinct)) ctx.distinct = {};
        ctx.distinct[columnKey] = Array.isArray(values) ? values : [];

        if (_panelState.open && _panelState.tableId === tableId && _panelState.columnKey === columnKey && _panelEl) {
            const cfg = _getColConfig(ctx, columnKey);
            const colType = cfg.type || "text";
            _renderValuesList(ctx, columnKey, colType, _panelEl, { keepScroll: true });
        }
    }

    /**
     * Aplica o state.filters (compactado) em uma URLSearchParams como `filters=<json>`.
     * Para usar nos loaders:
     *   const params = new URLSearchParams(...)
     *   TableFilter.applyToParams(params, stateOps)
     */
    function applyToParams(params, stateObj) {
        if (!params || typeof params.set !== "function") return;
        if (!stateObj) return;

        _ensureFiltersObject(stateObj);

        const compact = _getCompactFilters(stateObj.filters);
        if (Object.keys(compact).length > 0) {
            params.set("filters", JSON.stringify(compact));
        } else {
            params.delete("filters");
        }
    }

    /**
     * Retorna o objeto de filtros compactado (ideal para export futuro).
     */
    function getCompactFilters(stateObj) {
        if (!stateObj) return {};
        _ensureFiltersObject(stateObj);
        return _getCompactFilters(stateObj.filters);
    }

    /**
     * Limpa TODOS os filtros de uma tabela (state.filters inteiro).
     */
    function clearAll(tableId) {
        const ctx = _registry.get(tableId);
        if (!ctx || !ctx.state) return;

        ctx.state.filters = {};
        if (typeof ctx.state.page === "number") ctx.state.page = 1;

        _updateHeaderIndicators(ctx);
        _notifyChange(ctx, { immediate: true });
    }

    /**
     * Destrói listeners/observer de uma tabela (se precisar).
     */
    function destroy(tableId) {
        const ctx = _registry.get(tableId);
        if (!ctx) return;

        try {
            if (ctx._observer) ctx._observer.disconnect();
        } catch (e) { /* noop */ }

        _registry.delete(tableId);

        if (_panelState.open && _panelState.tableId === tableId) {
            _closePanel();
        }
    }

    function applyDistinctMap(tableId, distinctMap) {
        if (!distinctMap || typeof distinctMap !== "object") return;

        Object.keys(distinctMap).forEach((colKey) => {
            setDistinctValues(tableId, colKey, distinctMap[colKey] || []);
        });
    }

    /**
     * Aplica um mapa de distinct vindo do backend:
     *   meta.distinct = { coluna: [{value,label}, ...], ... }
     */
    function applyDistinctMap(tableId, distinctMap) {
        if (!distinctMap || typeof distinctMap !== "object") return;

        Object.keys(distinctMap).forEach((colKey) => {
            setDistinctValues(tableId, colKey, distinctMap[colKey] || []);
        });
    }

    // Aliases (compatibilidade)
    function resetFilters(tableId) {
        clearAll(tableId);
    }

    function clearForTable(tableId) {
        destroy(tableId);
    }

    // expõe no window
    window.TableFilter = {
        init,
        mount,
        updateDistinctValues,
        setDistinctValues,
        applyDistinctMap,
        applyToParams,
        getCompactFilters,
        clearAll,
        resetFilters,
        destroy,
        clearForTable,
    };

})();