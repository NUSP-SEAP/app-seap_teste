(function () {
    "use strict";

    // --- Estado das Tabelas ---
    const stateOp = {
        page: 1,
        limit: 10,
        search: "",
        sort: "nome", // Padrão definido no backend
        dir: "asc",
        filters: {},  // NOVO (TableFilter)
        reportFormat: "", // NOVO (Relatórios: "pdf" | "docx")
    };

    const stateChk = {
        page: 1,
        limit: 10,
        search: "",
        sort: "data", // Padrão definido no backend
        dir: "desc",
        periodo: null, // ← aqui vamos guardar o JSON { ranges: [...] }
        filters: {},   // NOVO (TableFilter)
        reportFormat: "", // NOVO (Relatórios: "pdf" | "docx")
    };

    // =========================================================
    // --- 1. Lógica de Operadores ---
    // =========================================================

    async function loadOperadores() {
        Pagination.updateHeaderIcons("tb-operadores", stateOp);

        const endpoint = AppConfig.endpoints.adminDashboard.operadores;
        // Monta QueryString com search, sort e dir
        const params = new URLSearchParams({
            page: stateOp.page,
            limit: stateOp.limit,
            search: stateOp.search,
            sort: stateOp.sort,
            dir: stateOp.dir
        });
        // Filtros por coluna (estilo Excel)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateOp);
        }

        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await Pagination.fetchJson(url);

        const tbody = document.querySelector("#tb-operadores tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar operadores.";
            tbody.innerHTML = `<tr><td colspan="5" class="empty-state">Erro ao carregar operadores (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-operadores", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioOperadores, state: stateOp, formatKey: "reportFormat" }
            });

            return;
        }
        const data = Array.isArray(resp.data) ? resp.data : [];

        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Valores únicos (checkboxes) do filtro por coluna:
        // Agora vêm do backend (meta.distinct) para não depender da paginação.
        if (window.TableFilter) {
            if (meta.distinct && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-operadores", meta.distinct);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                // fallback (caso o backend ainda não esteja retornando meta.distinct)
                window.TableFilter.updateDistinctValues("tb-operadores", data);
            }
        }

        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" class="empty-state">Nenhum operador encontrado.</td></tr>`;
            Pagination.renderPaginationControls("pag-operadores", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioOperadores, state: stateOp, formatKey: "reportFormat" }
            });

            return;
        }

        data.forEach(op => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td><strong>${op.nome_completo}</strong></td>
                <td>${op.email}</td>
                <td><span class="text-gray">${op.status_local}</span></td>
                <td>${op.hora_entrada}</td>
                <td>${op.hora_saida}</td>
            `;
            tr.style.cursor = "pointer";
            tr.title = "Dê um duplo-clique para ver detalhes (Em breve)";
            tr.addEventListener("dblclick", () => {
                // Futuro: window.location.href = `/admin/info_operador.html?id=${op.id}`;
                alert("Detalhes do operador: Funcionalidade futura.");
            });
            tbody.appendChild(tr);
        });

        Pagination.renderPaginationControls("pag-operadores", meta, (newPage) => {
            stateOp.page = newPage;
            loadOperadores();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioOperadores, state: stateOp, formatKey: "reportFormat" }
        });

    }
    function gerarRelatorioOperadores() {
        const fmt = (stateOp.reportFormat || "").trim(); // "pdf" | "docx"
        if (!fmt) {
            alert("Selecione a extensão do relatório (.pdf ou .docx).");
            return;
        }

        const endpoint =
            (AppConfig.endpoints.adminDashboard && AppConfig.endpoints.adminDashboard.operadoresRelatorio)
            || "/api/admin/dashboard/operadores/relatorio";

        const params = ReportPDF.buildParamsFromState(stateOp, { includePeriodo: false, page: 1, limit: 10 });
        params.set("format", fmt);

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: "Relatório - Operadores",
            format: fmt,
            filenameBase: "relatorio_operadores_audio",
        });
    }

    function gerarRelatorioChecklists() {
        const fmt = (stateChk.reportFormat || "").trim(); // "pdf" | "docx"
        if (!fmt) {
            alert("Selecione a extensão do relatório (.pdf ou .docx).");
            return;
        }

        const endpoint =
            (AppConfig.endpoints.adminDashboard && AppConfig.endpoints.adminDashboard.checklistsRelatorio)
            || "/api/admin/dashboard/checklists/relatorio";

        const params = ReportPDF.buildParamsFromState(stateChk, { includePeriodo: true, page: 1, limit: 10 });
        params.set("format", fmt);

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: "Relatório - Checklists",
            format: fmt,
            filenameBase: "relatorio_checklists",
        });
    }

    // =========================================================
    // --- 2. Lógica de Checklists ---
    // =========================================================

    async function loadChecklists() {
        Pagination.updateHeaderIcons("tb-checklists", stateChk);

        const endpoint = AppConfig.endpoints.adminDashboard.checklists;
        const params = new URLSearchParams({
            page: stateChk.page,
            limit: stateChk.limit,
            search: stateChk.search,
            sort: stateChk.sort,
            dir: stateChk.dir,
        });

        // Se houver filtro de período configurado, envia como JSON
        if (stateChk.periodo) {
            params.set("periodo", JSON.stringify(stateChk.periodo));
        }
        // Filtros por coluna (estilo Excel)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateChk);
        }
        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await Pagination.fetchJson(url);

        const tbody = document.querySelector("#tb-checklists tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar checklists.";
            tbody.innerHTML = `<tr><td colspan="6" class="empty-state">Erro ao carregar checklists (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-checklists", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioChecklists, state: stateChk, formatKey: "reportFormat" }
            });

            return;
        }

        const data = Array.isArray(resp.data) ? resp.data : [];

        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Valores únicos (checkboxes) do filtro por coluna (sem depender da página atual)
        if (window.TableFilter) {
            if (meta.distinct && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-checklists", meta.distinct);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                window.TableFilter.updateDistinctValues("tb-checklists", data);
            }
        }

        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="9" class="empty-state">Nenhum checklist encontrado.</td></tr>`;
            Pagination.renderPaginationControls("pag-checklists", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioChecklists, state: stateChk, formatKey: "reportFormat" }
            });

            return;
        }

        data.forEach(chk => {
            const trParent = document.createElement("tr");
            trParent.className = "accordion-parent";

            // Calcula o status geral do checklist: se tiver pelo menos 1 Falha → "Falha" em vermelho; senão "Ok" em verde
            const itens = chk.itens || [];
            const hasFailure = itens.some(it => it.status === "Falha");
            const statusColor = hasFailure ? "red" : "green";
            const statusWeight = hasFailure ? "bold" : "normal";
            const statusText = itens.length
                ? (hasFailure ? "Falha" : "Ok")
                : "--";

            trParent.innerHTML = `
                <td><span class="toggle-icon">▶</span></td>
                <td><strong>${chk.sala_nome}</strong></td>
                <td>${Utils.fmtDate(chk.data)}</td>
                <td>${chk.operador}</td>
                <td>${Utils.fmtTime(chk.inicio)}</td>
                <td>${Utils.fmtTime(chk.termino)}</td>
                <td>${chk.duracao || '--'}</td>
                <td style="color:${statusColor}; font-weight:${statusWeight}">${statusText}</td>
                <td>
                    <button class="btn-xs btn-form">Formulário 📄</button>
                </td>
            `;

            const trChild = document.createElement("tr");
            trChild.className = "accordion-child";

            let itemsHtml = "";
            if (chk.itens && chk.itens.length > 0) {
                itemsHtml = `
                    <table class="sub-table">
                        <thead>
                            <tr>
                                <th>Item verificado</th>
                                <th style="width:100px;">Status</th>
                                <th>Descrição</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${chk.itens.map(it => {
                    const isText = it.tipo_widget === 'text';
                    let statusHtml, descricao;
                    if (isText) {
                        statusHtml = `<span style="color:#333">Texto</span>`;
                        descricao = it.valor_texto || '-';
                    } else {
                        const color = it.status === 'Ok' ? 'green' : 'red';
                        const weight = it.status === 'Falha' ? 'bold' : 'normal';
                        statusHtml = `<span style="color:${color}; font-weight:${weight}">${it.status}</span>`;
                        descricao = it.falha || '-';
                    }
                    return `
                                    <tr>
                                        <td>${it.item}</td>
                                        <td>${statusHtml}</td>
                                        <td>${descricao}</td>
                                    </tr>
                                `;
                }).join('')}
                        </tbody>
                    </table>
                `;
            } else {
                itemsHtml = `<div style="padding:10px; color:#666;">Nenhum item registrado.</div>`;
            }

            trChild.innerHTML = `
                <td colspan="9">
                    <div class="sub-table-wrap">
                        <strong>Detalhes da Verificação:</strong>
                        <div style="margin-top:8px;">${itemsHtml}</div>
                    </div>
                </td>
            `;

            // Toggle Accordion
            trParent.addEventListener("click", (e) => {
                if (e.target.closest('.btn-form')) return;
                trParent.classList.toggle("open");
                if (trParent.classList.contains("open")) {
                    trChild.classList.add("visible");
                } else {
                    trChild.classList.remove("visible");
                }
            });

            // Botão Formulário
            const btnForm = trParent.querySelector(".btn-form");
            btnForm.addEventListener("click", (e) => {
                e.stopPropagation();
                if (chk.id) {
                    window.open(`/admin/form_checklist.html?checklist_id=${chk.id}`, '_blank');
                }
            });

            tbody.appendChild(trParent);
            tbody.appendChild(trChild);
        });

        Pagination.renderPaginationControls("pag-checklists", meta, (newPage) => {
            stateChk.page = newPage;
            loadChecklists();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioChecklists, state: stateChk, formatKey: "reportFormat" }
        });

    }

    // =========================================================
    // --- Inicialização ---
    // =========================================================
    document.addEventListener("DOMContentLoaded", () => {
        // 1. Bind Busca Operadores
        const searchOp = document.getElementById("search-operadores");
        if (searchOp) {
            searchOp.addEventListener("input", Utils.debounce((e) => {
                stateOp.search = e.target.value.trim();
                stateOp.page = 1; // Reseta para a primeira página ao buscar
                loadOperadores();
            }, 400)); // Aguarda 400ms após parar de digitar
        }

        // 2. Bind Busca Checklists
        const searchChk = document.getElementById("search-checklists");
        if (searchChk) {
            searchChk.addEventListener("input", Utils.debounce((e) => {
                stateChk.search = e.target.value.trim();
                stateChk.page = 1;
                loadChecklists();
            }, 400));
        }

        // 2.1. Filtro por Período (Checklists)
        const toolbarChk = searchChk ? searchChk.closest(".toolbar") : null;
        if (toolbarChk && window.PeriodoFilter && typeof window.PeriodoFilter.createPeriodoUI === "function") {
            window.PeriodoFilter.createPeriodoUI({
                toolbarEl: toolbarChk,
                getPeriodo: () => stateChk.periodo,
                setPeriodo: (p) => {
                    stateChk.periodo = p;
                    stateChk.page = 1;
                    loadChecklists();
                }
            });
        }

        // 3. Bind Header Clicks (Ordenação)
        Pagination.bindSortHeaders("tb-operadores", stateOp, loadOperadores);
        Pagination.bindSortHeaders("tb-checklists", stateChk, loadChecklists);

        // 3.1 Filtros por coluna (Excel-like) — Operadores
        if (window.TableFilter && typeof window.TableFilter.init === "function") {
            window.TableFilter.init({
                tableId: "tb-operadores",
                state: stateOp,
                columns: {
                    nome: { type: "text", sortable: true, sortKey: "nome", dataKey: "nome_completo", label: "Nome" },
                    email: { type: "text", sortable: true, sortKey: "email", dataKey: "email", label: "E-mail" },
                    status_local: { type: "text", sortable: true, sortKey: "status_local", dataKey: "status_local", label: "No Senado?" },
                    hora_entrada: { type: "text", sortable: true, sortKey: "hora_entrada", dataKey: "hora_entrada", label: "Entrada" },
                    hora_saida: { type: "text", sortable: true, sortKey: "hora_saida", dataKey: "hora_saida", label: "Saída" },
                },
                onChange: loadOperadores,
                debounceMs: 250,
            });

            window.TableFilter.init({
                tableId: "tb-checklists",
                state: stateChk,
                columns: {
                    sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala_nome", label: "Local" },
                    data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                    operador: { type: "text", sortable: true, sortKey: "operador", dataKey: "operador", label: "Verificado por" },

                    // Hora: guardamos/filtramos por HH:MM
                    inicio: {
                        type: "text",
                        sortable: true,
                        sortKey: "inicio",
                        dataKey: "inicio",
                        label: "Início",
                        toValue: (v) => (v ? String(v).substring(0, 5) : ""),
                        toLabel: (v) => (v ? String(v).substring(0, 5) : ""),
                    },
                    termino: {
                        type: "text",
                        sortable: true,
                        sortKey: "termino",
                        dataKey: "termino",
                        label: "Término",
                        toValue: (v) => (v ? String(v).substring(0, 5) : ""),
                        toLabel: (v) => (v ? String(v).substring(0, 5) : ""),
                    },

                    duracao: { type: "text", sortable: true, sortKey: "duracao", dataKey: "duracao", label: "Duração" },

                    // Status é derivado de itens (Falha / Ok / --)
                    status: {
                        type: "text",
                        sortable: true,
                        sortKey: "status",
                        label: "Status",
                        getValue: (row) => {
                            const itens = (row && Array.isArray(row.itens)) ? row.itens : [];
                            if (!itens.length) return "--";
                            const hasFailure = itens.some((it) => it && it.status === "Falha");
                            return hasFailure ? "Falha" : "Ok";
                        },
                    },

                    acoes: { filterable: false, label: "Ações" },
                },
                onChange: loadChecklists,
                debounceMs: 250,
            });
        }

        // 4. Carga Inicial
        loadOperadores();
        loadChecklists();
    });
})();