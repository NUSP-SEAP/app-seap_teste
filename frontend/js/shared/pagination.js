/**
 * js/shared/pagination.js
 * Utilitários de paginação, ordenação e fetch autenticado.
 * Exposto via window.Pagination para uso por scripts IIFE.
 * Depende de window.Utils (utils.js) e window.Auth (auth_jwt.js).
 */
(function () {
    "use strict";

    /** Normaliza formato de relatório: aceita "pdf", ".pdf", "docx", ".docx". */
    function normalizeReportFormat(fmt) {
        const v = String(fmt ?? "").trim().toLowerCase();
        if (v === "pdf" || v === ".pdf") return "pdf";
        if (v === "docx" || v === ".docx") return "docx";
        return "";
    }

    /**
     * Renderiza controles de paginação e (opcionalmente) botão de relatório
     * dentro do elemento com id = `containerId`.
     *
     * @param {string}   containerId   - Id do elemento container.
     * @param {object}   meta          - { page, pages, total } vindos da API.
     * @param {function} onPageChange  - Callback chamado com o número da nova página.
     * @param {object}  [options]      - Opções opcionais:
     *   options.report = { label, onClick, state, formatKey }
     */
    function renderPaginationControls(containerId, meta, onPageChange, options) {
        const container = document.getElementById(containerId);
        if (!container) return;

        const escapeHtml = (window.Utils && Utils.escapeHtml) ? Utils.escapeHtml : (s) => String(s ?? "");

        const opts = options || {};
        const report = opts.report || null;
        const hasReport = !!(report && typeof report.onClick === "function");

        const canPaginate = !!(meta && meta.total && typeof onPageChange === "function");
        if (!canPaginate && !hasReport) {
            container.innerHTML = "";
            return;
        }

        const current = (meta && meta.page) ? meta.page : 1;
        const totalPages = (meta && meta.pages) ? meta.pages : 1;
        const totalRecords = (meta && meta.total) ? meta.total : 0;

        const isFirstPage = current <= 1;
        const isLastPage = current >= totalPages;

        // --- Área da esquerda: dropdown + botão de relatório (quando aplicável) ---
        let leftHtml = "";
        if (hasReport) {
            const reportState = report.state || null;
            const formatKey = report.formatKey || null;

            if (!reportState || !formatKey) {
                // Modo simples: apenas botão (sem dropdown de formato)
                leftHtml = `<button type="button" class="btn-page btn-report">${escapeHtml(report.label || "Gerar Relatório")}</button>`;
            } else {
                const selectedFmt = normalizeReportFormat(reportState[formatKey]);
                const disabled = !selectedFmt;

                leftHtml = `
                <div class="report-controls">
                    <select
                        id="report-format-${containerId}"
                        class="report-format-select"
                        style="min-width: 170px;"
                    >
                        <option value="" ${selectedFmt ? "" : "selected"}>Selecione a extensão...</option>
                        <option value="pdf" ${selectedFmt === "pdf" ? "selected" : ""}>.pdf</option>
                        <option value="docx" ${selectedFmt === "docx" ? "selected" : ""}>.docx</option>
                    </select>

                    <button
                        type="button"
                        class="btn-page btn-report"
                        ${disabled ? "disabled" : ""}
                    >${escapeHtml(report.label || "Gerar Relatório")}</button>
                </div>
            `;
            }
        }

        // --- Área da direita: paginação ---
        const rightHtml = canPaginate
            ? `
        <span class="pagination-info">
            Página <strong>${current}</strong> de <strong>${totalPages}</strong> (Total: ${totalRecords})
        </span>
        <div class="pagination-nav">
            <button class="btn-page" id="first-${containerId}" ${isFirstPage ? "disabled" : ""}>&lt;&lt;</button>
            <button class="btn-page" id="prev-${containerId}" ${isFirstPage ? "disabled" : ""}>&lt;</button>

            <input
                type="number"
                id="page-input-${containerId}"
                class="page-input"
                min="1"
                max="${totalPages}"
                value="${current}"
            />

            <button class="btn-page" id="go-${containerId}">Ir</button>

            <button class="btn-page" id="next-${containerId}" ${isLastPage ? "disabled" : ""}>&gt;</button>
            <button class="btn-page" id="last-${containerId}" ${isLastPage ? "disabled" : ""}>&gt;&gt;</button>
        </div>
    `
            : "";

        container.innerHTML = `
    <div class="pagination-left">${leftHtml}</div>
    <div class="pagination-right">${rightHtml}</div>
`;

        // --- Bind do botão de relatório ---
        if (hasReport) {
            const btnReport = container.querySelector(".btn-report");
            if (btnReport && !btnReport.dataset.bound) {
                btnReport.dataset.bound = "1";
                btnReport.addEventListener("click", (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    try {
                        const r = report.onClick();
                        if (r && typeof r.then === "function") {
                            r.catch((err) => {
                                console.error("Erro ao gerar relatório (async):", err);
                                alert("Erro ao gerar relatório. Veja o console.");
                            });
                        }
                    } catch (err) {
                        console.error("Erro ao gerar relatório:", err);
                        alert("Erro ao gerar relatório. Veja o console.");
                    }
                });
            }

            // Bind do dropdown (se existir)
            const reportState = report.state || null;
            const formatKey = report.formatKey || null;
            const sel = document.getElementById(`report-format-${containerId}`);
            if (sel && reportState && formatKey && btnReport) {
                sel.addEventListener("change", (e) => {
                    const fmt = normalizeReportFormat(e.target.value);
                    reportState[formatKey] = fmt;
                    btnReport.disabled = !fmt;
                });
            }
        }

        // --- Bind da paginação ---
        if (!canPaginate) return;

        const input = document.getElementById(`page-input-${containerId}`);
        const btnFirst = document.getElementById(`first-${containerId}`);
        const btnPrev = document.getElementById(`prev-${containerId}`);
        const btnGo = document.getElementById(`go-${containerId}`);
        const btnNext = document.getElementById(`next-${containerId}`);
        const btnLast = document.getElementById(`last-${containerId}`);

        const goToPage = (page) => {
            let target = parseInt(page, 10);
            if (isNaN(target)) return;
            if (target < 1) target = 1;
            if (target > totalPages) target = totalPages;
            if (target === current) return;
            onPageChange(target);
        };

        if (btnFirst) btnFirst.onclick = (e) => { e.stopPropagation(); goToPage(1); };
        if (btnPrev) btnPrev.onclick = (e) => { e.stopPropagation(); goToPage(current - 1); };
        if (btnNext) btnNext.onclick = (e) => { e.stopPropagation(); goToPage(current + 1); };
        if (btnLast) btnLast.onclick = (e) => { e.stopPropagation(); goToPage(totalPages); };

        if (btnGo && input) {
            btnGo.onclick = (e) => { e.stopPropagation(); goToPage(input.value); };
            input.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault();
                    e.stopPropagation();
                    goToPage(input.value);
                }
            });
        }
    }

    /**
     * Faz GET autenticado via Auth.authFetch e retorna o JSON parseado.
     * Em caso de erro, retorna objeto com { ok: false, error, data: [], meta }.
     */
    async function fetchJson(url) {
        const fallbackMeta = { page: 1, pages: 1, total: 0 };

        if (!window.Auth || typeof Auth.authFetch !== "function") {
            const msg = "Auth não carregado (Auth.authFetch indisponível).";
            console.error(msg);
            return { ok: false, status: 0, error: msg, data: [], meta: fallbackMeta };
        }

        try {
            const resp = await Auth.authFetch(url);

            const text = await resp.text();
            let json = null;
            try {
                json = text ? JSON.parse(text) : null;
            } catch (_) {
                json = null;
            }

            if (!resp.ok) {
                const msg =
                    (json && (json.message || json.error)) ||
                    (text && text.trim()) ||
                    `HTTP ${resp.status}`;
                console.error("Fetch error:", resp.status, msg);
                return { ok: false, status: resp.status, error: msg, data: [], meta: fallbackMeta };
            }

            if (json && typeof json === "object") return json;

            const msg = "Resposta ok, mas não veio JSON.";
            console.error(msg, (text || "").slice(0, 200));
            return { ok: false, status: resp.status, error: msg, data: [], meta: fallbackMeta };
        } catch (e) {
            const msg = (e && e.message) ? e.message : String(e);
            console.error("Fetch error:", msg);
            return { ok: false, status: 0, error: msg, data: [], meta: fallbackMeta };
        }
    }

    /**
     * Atualiza os ícones de ordenação nos `<th class="sortable">` da tabela.
     * @param {string} tableId - Id da tabela.
     * @param {object} state   - { sort, dir }
     */
    function updateHeaderIcons(tableId, state) {
        const headers = document.querySelectorAll(`#${tableId} th.sortable`);
        headers.forEach(th => {
            th.classList.remove("asc", "desc");
            if (th.dataset.sort === state.sort) {
                th.classList.add(state.dir);
            }
        });
    }

    /**
     * Vincula clique nos `<th class="sortable">` para atualizar stateObj e chamar loadFunc.
     * @param {string}   tableId  - Id da tabela.
     * @param {object}   stateObj - Objeto de estado com { sort, dir, page }.
     * @param {function} loadFunc - Função de recarga dos dados.
     */
    function bindSortHeaders(tableId, stateObj, loadFunc) {
        const headers = document.querySelectorAll(`#${tableId} th.sortable`);
        headers.forEach(th => {
            th.addEventListener("click", () => {
                const col = th.dataset.sort;
                if (stateObj.sort === col) {
                    stateObj.dir = stateObj.dir === "asc" ? "desc" : "asc";
                } else {
                    stateObj.sort = col;
                    stateObj.dir = "asc";
                }
                stateObj.page = 1;
                loadFunc();
            });
        });
    }

    window.Pagination = { renderPaginationControls, fetchJson, updateHeaderIcons, bindSortHeaders };
})();
