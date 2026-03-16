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

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: "Relatório - Operações de Áudio",
            format: "pdf",
            filenameBase: "relatorio_operacoes_audio",
        });
    }

    // --- Carga dos dados ---
    async function loadMinhasOperacoes() {
        Pagination.updateHeaderIcons("tb-minhas-operacoes", stateOp);

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
        const resp = await Pagination.fetchJson(url);

        const tbody = document.querySelector("#tb-minhas-operacoes tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar operações.";
            tbody.innerHTML = `<tr><td colspan="6" class="empty-state">Erro ao carregar operações (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-minhas-operacoes", null, null, {
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
            Pagination.renderPaginationControls("pag-minhas-operacoes", null, null, {
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
                <td><strong>${Utils.escapeHtml(op.sala)}</strong></td>
                <td>${Utils.fmtDate(op.data)}</td>
                <td style="text-align:center">${Utils.fmtTime(op.inicio_operacao)}</td>
                <td style="text-align:center">${Utils.fmtTime(op.fim_operacao)}</td>
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
                    window.open(`/forms/operacao/raoa_edit.html?id=${anomId}`, '_blank');
                });
            }

            // Botão Formulário -> abre detalhe da operação
            const btnForm = tr.querySelector(".btn-form");
            btnForm.addEventListener("click", (e) => {
                e.stopPropagation();
                if (op.id) {
                    window.open(`/forms/operacao/roa_edit.html?entrada_id=${op.id}`, '_blank');
                }
            });

            tbody.appendChild(tr);
        });

        Pagination.renderPaginationControls("pag-minhas-operacoes", meta, (newPage) => {
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
        Pagination.bindSortHeaders("tb-minhas-operacoes", stateOp, loadMinhasOperacoes);

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
