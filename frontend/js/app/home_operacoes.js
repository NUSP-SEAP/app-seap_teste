(function () {
    "use strict";

    // --- Estado da Tabela ---
    const stateOp = {
        page: 1,
        limit: 10,
        sort: "data",
        dir: "desc",
        filters: {},
    };

    // --- Helpers ---
    const fmtDate = (d) => {
        if (!d) return "--";
        const parts = String(d).split('-');
        if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
        return d;
    };

    const fmtTime = (t) => {
        if (!t) return "--";
        return String(t).substring(0, 5);
    };

    function escapeHtml(s) {
        return String(s ?? "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // --- Paginacao (mesmo padrao do home_checklists) ---
    function renderPaginationControls(containerId, meta, onPageChange, options) {
        const container = document.getElementById(containerId);
        if (!container) return;

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

        let leftHtml = "";
        if (hasReport) {
            leftHtml = `<button type="button" class="btn-page btn-report">${escapeHtml(report.label || "Gerar Relatório")}</button>`;
        }

        const rightHtml = canPaginate
            ? `
        <span class="pagination-info">
            Página <strong>${current}</strong> de <strong>${totalPages}</strong> (Total: ${totalRecords})
        </span>
        <div class="pagination-nav">
            <button class="btn-page" id="first-${containerId}" ${isFirstPage ? "disabled" : ""}>&lt;&lt;</button>
            <button class="btn-page" id="prev-${containerId}" ${isFirstPage ? "disabled" : ""}>&lt;</button>
            <input type="number" id="page-input-${containerId}" class="page-input" min="1" max="${totalPages}" value="${current}" />
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

        // Bind do botão de relatório
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
        }

        // Bind de paginação
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

    // --- Fetch autenticado ---
    async function fetchJson(url) {
        const fallbackMeta = { page: 1, pages: 1, total: 0 };

        if (!window.Auth || typeof Auth.authFetch !== "function") {
            console.error("Auth não carregado (Auth.authFetch indisponível).");
            return { ok: false, status: 0, error: "Auth não carregado", data: [], meta: fallbackMeta };
        }

        try {
            const resp = await Auth.authFetch(url);
            const text = await resp.text();
            let json = null;
            try { json = text ? JSON.parse(text) : null; } catch (_) { json = null; }

            if (!resp.ok) {
                const msg = (json && (json.message || json.error)) || (text && text.trim()) || `HTTP ${resp.status}`;
                return { ok: false, status: resp.status, error: msg, data: [], meta: fallbackMeta };
            }

            if (json && typeof json === "object") return json;
            return { ok: false, status: resp.status, error: "Resposta ok, mas não veio JSON.", data: [], meta: fallbackMeta };
        } catch (e) {
            return { ok: false, status: 0, error: e.message || String(e), data: [], meta: fallbackMeta };
        }
    }

    // --- Gerenciamento de Ordenação ---
    function updateHeaderIcons(tableId, state) {
        const headers = document.querySelectorAll(`#${tableId} th.sortable`);
        headers.forEach(th => {
            th.classList.remove("asc", "desc");
            if (th.dataset.sort === state.sort) {
                th.classList.add(state.dir);
            }
        });
    }

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

    // --- Relatório PDF ---
    function gerarRelatorioPdf() {
        const endpoint = AppConfig.endpoints.operadorDashboard.minhasOperacoesRelatorio;

        const params = new URLSearchParams({
            page: "1",
            limit: "10",
            sort: stateOp.sort || "",
            dir: stateOp.dir || "",
            format: "pdf",
        });

        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateOp);
        }

        if (window.ReportPDF && typeof window.ReportPDF.openFromEndpoint === "function") {
            window.ReportPDF.openFromEndpoint(endpoint, params, {
                title: "Relatório - Operações de Áudio",
                format: "pdf",
                filenameBase: "relatorio_operacoes_audio",
            });
            return;
        }

        // Fallback
        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        window.open(url, "_blank");
    }

    // --- Carga dos dados ---
    async function loadMinhasOperacoes() {
        updateHeaderIcons("tb-minhas-operacoes", stateOp);

        const endpoint = AppConfig.endpoints.operadorDashboard.minhasOperacoes;
        const params = new URLSearchParams({
            page: stateOp.page,
            limit: stateOp.limit,
            sort: stateOp.sort,
            dir: stateOp.dir,
        });

        // Filtros por coluna (Excel-like)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateOp);
        }

        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await fetchJson(url);

        const tbody = document.querySelector("#tb-minhas-operacoes tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar operações.";
            tbody.innerHTML = `<tr><td colspan="6" class="empty-state">Erro ao carregar operações (HTTP ${status}). ${escapeHtml(msg)}</td></tr>`;
            renderPaginationControls("pag-minhas-operacoes", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
            });
            return;
        }

        const data = Array.isArray(resp.data) ? resp.data : [];
        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Distinct values para filtros por coluna
        if (window.TableFilter) {
            if (meta.distinct && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-minhas-operacoes", meta.distinct);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                window.TableFilter.updateDistinctValues("tb-minhas-operacoes", data);
            }
        }

        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="empty-state">Nenhuma operação encontrada.</td></tr>`;
            renderPaginationControls("pag-minhas-operacoes", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
            });
            return;
        }

        data.forEach(op => {
            const tr = document.createElement("tr");

            const anorm = !!op.anormalidade;
            const anomId = op.anormalidade_id;

            let anormCell;
            if (anorm && anomId) {
                anormCell = `<button class="btn-xs btn-anom-sim" title="Ver anormalidade">SIM</button>`;
            } else if (anorm) {
                anormCell = `<span style="color: #b91c1c; font-weight: bold;">SIM</span>`;
            } else {
                anormCell = `<span style="color: #15803d; font-weight: bold;">Não</span>`;
            }

            tr.innerHTML = `
                <td><strong>${escapeHtml(op.sala)}</strong></td>
                <td>${fmtDate(op.data)}</td>
                <td style="text-align:center">${fmtTime(op.inicio_operacao)}</td>
                <td style="text-align:center">${fmtTime(op.fim_operacao)}</td>
                <td style="text-align:center">${anormCell}</td>
                <td>
                    <button class="btn-xs btn-form">Formulário</button>
                </td>
            `;

            // Botão "SIM" -> abre detalhe da anormalidade
            const btnAnom = tr.querySelector(".btn-anom-sim");
            if (btnAnom && anomId) {
                btnAnom.addEventListener("click", (e) => {
                    e.stopPropagation();
                    window.open(`/forms/operacao/detalhe_anormalidade.html?id=${anomId}`, '_blank');
                });
            }

            // Botão Formulário -> abre detalhe da operação
            const btnForm = tr.querySelector(".btn-form");
            btnForm.addEventListener("click", (e) => {
                e.stopPropagation();
                if (op.id) {
                    window.open(`/forms/operacao/detalhe.html?entrada_id=${op.id}`, '_blank');
                }
            });

            tbody.appendChild(tr);
        });

        renderPaginationControls("pag-minhas-operacoes", meta, (newPage) => {
            stateOp.page = newPage;
            loadMinhasOperacoes();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
        });
    }

    // --- Inicialização ---
    document.addEventListener("DOMContentLoaded", () => {
        if (!window.Auth || typeof Auth.loadUser !== "function") return;

        const session = Auth.loadUser();
        if (!session || !session.ok) return;

        // Mostra a seção
        const section = document.getElementById("section-minhas-operacoes");
        if (section) section.style.display = "";

        // Bind de ordenação
        bindSortHeaders("tb-minhas-operacoes", stateOp, loadMinhasOperacoes);

        // Filtros por coluna (Excel-like)
        if (window.TableFilter && typeof window.TableFilter.init === "function") {
            window.TableFilter.init({
                tableId: "tb-minhas-operacoes",
                state: stateOp,
                columns: {
                    sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala", label: "Sala" },
                    data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                    inicio_operacao: { type: "text", sortable: true, sortKey: "inicio_operacao", dataKey: "inicio_operacao", label: "Início Operação" },
                    fim_operacao: { type: "text", sortable: true, sortKey: "fim_operacao", dataKey: "fim_operacao", label: "Fim Operação" },
                    anormalidade: { type: "bool", sortable: true, sortKey: "anormalidade", dataKey: "anormalidade", label: "Anormalidade?" },
                    acao: { filterable: false, label: "Ação" },
                },
                onChange: loadMinhasOperacoes,
                debounceMs: 250,
            });
        }

        // Carga inicial
        loadMinhasOperacoes();
    });
})();
