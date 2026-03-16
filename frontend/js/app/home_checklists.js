(function () {
    "use strict";

    // --- Estado da Tabela ---
    const stateChk = {
        page: 1,
        limit: 10,
        sort: "data",
        dir: "desc",
        filters: {},
    };

    // --- Relatório PDF ---
    function gerarRelatorioPdf() {
        const endpoint = AppConfig.endpoints.operadorDashboard.meusChecklistsRelatorio;

        const params = new URLSearchParams({
            page: "1",
            limit: "10",
            sort: stateChk.sort || "",
            dir: stateChk.dir || "",
            format: "pdf",
        });

        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateChk);
        }

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: "Relatório - Verificação de Salas",
            format: "pdf",
            filenameBase: "relatorio_verificacao_salas",
        });
    }

    // --- Carga dos dados ---
    async function loadMeusChecklists() {
        Pagination.updateHeaderIcons("tb-meus-checklists", stateChk);

        const endpoint = AppConfig.endpoints.operadorDashboard.meusChecklists;
        const params = new URLSearchParams({
            page: stateChk.page,
            limit: stateChk.limit,
            sort: stateChk.sort,
            dir: stateChk.dir,
        });

        // Filtros por coluna (Excel-like)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateChk);
        }

        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await Pagination.fetchJson(url);

        const tbody = document.querySelector("#tb-meus-checklists tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar verificações.";
            tbody.innerHTML = `<tr><td colspan="5" class="empty-state">Erro ao carregar verificações (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-meus-checklists", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
            });
            return;
        }

        const data = Array.isArray(resp.data) ? resp.data : [];
        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Distinct values para filtros por coluna
        if (window.TableFilter) {
            if (meta.distinct && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-meus-checklists", meta.distinct);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                window.TableFilter.updateDistinctValues("tb-meus-checklists", data);
            }
        }

        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" class="empty-state">Nenhuma verificação encontrada.</td></tr>`;
            Pagination.renderPaginationControls("pag-meus-checklists", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
            });
            return;
        }

        data.forEach(chk => {
            const tr = document.createElement("tr");

            const qtdeOk = parseInt(chk.qtde_ok || 0, 10);
            const qtdeFalha = parseInt(chk.qtde_falha || 0, 10);

            const okColor = qtdeOk > 0 ? "green" : "#334155";
            const falhaColor = qtdeFalha > 0 ? "red" : "#334155";
            const falhaWeight = qtdeFalha > 0 ? "bold" : "normal";

            tr.innerHTML = `
                <td><strong>${Utils.escapeHtml(chk.sala_nome)}</strong></td>
                <td>${Utils.fmtDate(chk.data)}</td>
                <td style="color:${okColor}; font-weight:bold; text-align:center">${qtdeOk}</td>
                <td style="color:${falhaColor}; font-weight:${falhaWeight}; text-align:center">${qtdeFalha}</td>
                <td>
                    <button class="btn-xs btn-form">Formulário</button>
                </td>
            `;

            // Botão Formulário
            const btnForm = tr.querySelector(".btn-form");
            btnForm.addEventListener("click", (e) => {
                e.stopPropagation();
                if (chk.id) {
                    window.open(`/forms/checklist/edit.html?checklist_id=${chk.id}`, '_blank');
                }
            });

            tbody.appendChild(tr);
        });

        Pagination.renderPaginationControls("pag-meus-checklists", meta, (newPage) => {
            stateChk.page = newPage;
            loadMeusChecklists();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioPdf }
        });
    }

    // --- Inicialização ---
    document.addEventListener("DOMContentLoaded", () => {
        // Verifica se o usuário é operador (não admin) para mostrar a tabela
        if (!window.Auth || typeof Auth.loadUser !== "function") return;

        const session = Auth.loadUser();
        if (!session || !session.ok) return;

        // Mostra a seção de tabelas para todos os usuários logados
        const section = document.getElementById("section-meus-checklists");
        if (section) section.style.display = "";

        // Bind de ordenação
        Pagination.bindSortHeaders("tb-meus-checklists", stateChk, loadMeusChecklists);

        // Filtros por coluna (Excel-like)
        if (window.TableFilter && typeof window.TableFilter.init === "function") {
            window.TableFilter.init({
                tableId: "tb-meus-checklists",
                state: stateChk,
                columns: {
                    sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala_nome", label: "Sala" },
                    data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                    qtde_ok: { type: "number", sortable: true, sortKey: "qtde_ok", dataKey: "qtde_ok", label: "Qtde. OK" },
                    qtde_falha: { type: "number", sortable: true, sortKey: "qtde_falha", dataKey: "qtde_falha", label: "Qtde. Falha" },
                    acao: { filterable: false, label: "Ação" },
                },
                onChange: loadMeusChecklists,
                debounceMs: 250,
            });
        }

        // Carga inicial
        loadMeusChecklists();
    });
})();
