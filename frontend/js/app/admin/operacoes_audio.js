(function () {
    "use strict";

    // --- Estado da Tabela de Operações (Sessões) ---
    const stateOps = {
        page: 1,
        limit: 10,
        search: "",
        sort: "data",
        dir: "desc",
        periodo: null,     // filtro de período para sessões de operação
        groupBySala: true, // controla se a tabela está agrupada por sala (default = true)
        filters: {},       // NOVO: filtros por coluna (TableFilter)
        reportFormat: "", // extensão selecionada: "pdf" | "docx" | ""
    };

    // --- Novo Estado da Tabela de Anormalidades (Master-Detail) ---
    const anomState = {
        page: 1,          // Paginação agora é global
        limit: 10,
        search: "",       // Filtro global
        sort: "data",     // Ordenação padrão
        dir: "desc",      // Direção padrão
        periodo: null,    // filtro de período para anormalidades
        filters: {},      // NOVO: filtros por coluna (TableFilter)
        reportFormat: "", // extensão selecionada: "pdf" | "docx" | ""
    };

    // =========================================================
    // --- Relatórios (PDF/DOCX) ---
    // =========================================================

    const REPORT_MIME = {
        pdf: "application/pdf",
        docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    };

    function extractFilenameFromContentDisposition(cd) {
        if (!cd) return "";
        const m = String(cd).match(/filename\*?=(?:UTF-8''|")?([^";\n]+)"?/i);
        if (!m) return "";
        try { return decodeURIComponent(m[1]); } catch (_) { return m[1]; }
    }
    // =========================================================
    // --- RDS (XLSX) - UI (Ano/Mês + Botão) + Download com Auth ---
    // =========================================================

    const RDS_MONTHS_PT = [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
    ];

    function pad2(n) {
        return String(n).padStart(2, "0");
    }

    async function downloadXlsxWithAuth(url, fallbackFilename) {
        if (!window.Auth || typeof Auth.authFetch !== "function") {
            alert("Auth não carregado (Auth.authFetch indisponível).");
            return;
        }

        const resp = await Auth.authFetch(url, {
            method: "GET",
            headers: { "Accept": (REPORT_MIME && REPORT_MIME.xlsx) ? REPORT_MIME.xlsx : "*/*" },
        });

        if (!resp.ok) {
            const text = await resp.text().catch(() => "");
            const msg = (text || "").trim();
            alert(`Falha ao gerar RDS (HTTP ${resp.status}).${msg ? "\n\n" + msg : ""}`);
            return;
        }

        const blob = await resp.blob();
        const cd = resp.headers ? resp.headers.get("content-disposition") : "";
        const fromHeader = extractFilenameFromContentDisposition(cd);
        const filename = fromHeader || fallbackFilename || "RDS.xlsx";

        const blobUrl = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = blobUrl;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();

        setTimeout(() => URL.revokeObjectURL(blobUrl), 2 * 60 * 1000);
    }

    async function initRdsUi(mountEl) {
        if (!mountEl) return;

        // Evita duplicar caso a tela reinicialize algum trecho
        if (document.getElementById("rds-ano") || document.getElementById("btn-gerar-rds")) {
            return;
        }

        // Spacer para empurrar os controles do RDS para a direita na flex-line
        const spacer = document.createElement("div");
        spacer.className = "periodo-spacer";

        const box = document.createElement("div");
        box.className = "rds-controls";
        box.style.display = "flex";
        box.style.alignItems = "center";
        box.style.gap = "8px";
        box.style.flexWrap = "wrap";

        box.innerHTML = `
            <select id="rds-ano" class="page-input" style="min-width: 120px;">
                <option value="">Ano</option>
            </select>

            <select id="rds-mes" class="page-input" style="min-width: 150px;" disabled>
                <option value="">Mês</option>
            </select>

            <button type="button" id="btn-gerar-rds" class="btn-page" disabled>
                Gerar RDS
            </button>
        `;

        mountEl.appendChild(spacer);
        mountEl.appendChild(box);

        const selAno = document.getElementById("rds-ano");
        const selMes = document.getElementById("rds-mes");
        const btn = document.getElementById("btn-gerar-rds");

        const endpointAnos =
            (AppConfig.endpoints.adminDashboard &&
                AppConfig.endpoints.adminDashboard.rds &&
                AppConfig.endpoints.adminDashboard.rds.anos) ||
            "/api/admin/operacoes/rds/anos";

        const endpointMeses =
            (AppConfig.endpoints.adminDashboard &&
                AppConfig.endpoints.adminDashboard.rds &&
                AppConfig.endpoints.adminDashboard.rds.meses) ||
            "/api/admin/operacoes/rds/meses";

        const endpointGerar =
            (AppConfig.endpoints.adminDashboard &&
                AppConfig.endpoints.adminDashboard.rds &&
                AppConfig.endpoints.adminDashboard.rds.gerar) ||
            "/api/admin/operacoes/rds/gerar";

        const resetMes = () => {
            selMes.innerHTML = `<option value="">Mês</option>`;
            selMes.value = "";
            selMes.disabled = true;
            btn.disabled = true;
        };

        const fillAnos = (anos) => {
            selAno.innerHTML = `<option value="">Ano</option>`;
            (anos || []).forEach((y) => {
                const yy = parseInt(y, 10);
                if (!Number.isFinite(yy)) return;
                const opt = document.createElement("option");
                opt.value = String(yy);
                opt.textContent = String(yy);
                selAno.appendChild(opt);
            });
        };

        const fillMeses = (meses) => {
            selMes.innerHTML = `<option value="">Mês</option>`;
            (meses || []).forEach((m) => {
                const mm = parseInt(m, 10);
                if (!Number.isFinite(mm) || mm < 1 || mm > 12) return;

                const opt = document.createElement("option");
                opt.value = String(mm);
                opt.textContent = RDS_MONTHS_PT[mm - 1] || `Mês ${mm}`;
                selMes.appendChild(opt);
            });
            selMes.disabled = false; // habilita após carregar
        };

        // 1) Carrega anos (dropdown Ano)
        try {
            const url = AppConfig.apiUrl(endpointAnos);
            const resp = await Pagination.fetchJson(url);

            if (resp && resp.ok !== false && Array.isArray(resp.anos)) {
                fillAnos(resp.anos);
            } else {
                console.error("Falha ao carregar anos do RDS:", resp);
            }
        } catch (err) {
            console.error("Erro ao carregar anos do RDS:", err);
        }

        // 2) Ao selecionar ano, habilita mês e carrega meses disponíveis
        selAno.addEventListener("change", async () => {
            resetMes();

            const ano = parseInt(selAno.value, 10);
            if (!Number.isFinite(ano)) return;

            try {
                const params = new URLSearchParams({ ano: String(ano) });
                const url = `${AppConfig.apiUrl(endpointMeses)}?${params.toString()}`;

                const resp = await Pagination.fetchJson(url);
                if (resp && resp.ok !== false && Array.isArray(resp.meses)) {
                    fillMeses(resp.meses);
                } else {
                    console.error("Falha ao carregar meses do RDS:", resp);
                }
            } catch (err) {
                console.error("Erro ao carregar meses do RDS:", err);
            }
        });

        // 3) Ao selecionar mês, habilita botão
        selMes.addEventListener("change", () => {
            btn.disabled = !(selAno.value && selMes.value);
        });

        // 4) Gerar RDS (download do XLSX)
        btn.addEventListener("click", async () => {
            const ano = parseInt(selAno.value, 10);
            const mes = parseInt(selMes.value, 10);

            if (!Number.isFinite(ano) || !Number.isFinite(mes)) {
                alert("Selecione um Ano e um Mês para gerar o RDS.");
                return;
            }

            const params = new URLSearchParams({ ano: String(ano), mes: String(mes) });
            const url = `${AppConfig.apiUrl(endpointGerar)}?${params.toString()}`;

            const oldText = btn.textContent;
            btn.textContent = "Gerando...";
            btn.disabled = true;

            try {
                const fallback = `RDS ${ano}-${pad2(mes)}.xlsx`;
                await downloadXlsxWithAuth(url, fallback);
            } finally {
                btn.textContent = oldText;
                btn.disabled = !(selAno.value && selMes.value);
            }
        });
    }

    function gerarRelatorioAnormalidades() {
        const endpoint =
            (AppConfig.endpoints.adminDashboard
                && AppConfig.endpoints.adminDashboard.anormalidades
                && AppConfig.endpoints.adminDashboard.anormalidades.relatorio)
            || "/api/admin/dashboard/anormalidades/lista/relatorio";

        const fmt = (anomState.reportFormat || "").trim();
        if (!fmt) {
            alert("Selecione a extensão do relatório (.pdf ou .docx).");
            return;
        }

        const params = ReportPDF.buildParamsFromState(anomState, { page: 1 });
        params.set("format", fmt);

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: "Relatório - Anormalidades",
            format: fmt,
            filenameBase: "relatorio_anormalidades",
        });
    }

    function gerarRelatorioOperacoes() {
        const endpoint = stateOps.groupBySala
            ? ((AppConfig.endpoints.adminDashboard && AppConfig.endpoints.adminDashboard.operacoesRelatorio)
                || "/api/admin/dashboard/operacoes/relatorio")
            : ((AppConfig.endpoints.adminDashboard && AppConfig.endpoints.adminDashboard.operacoesEntradasRelatorio)
                || "/api/admin/dashboard/operacoes/entradas/relatorio");

        const fmt = (stateOps.reportFormat || "").trim();
        if (!fmt) {
            alert("Selecione a extensão do relatório (.pdf ou .docx).");
            return;
        }

        const params = ReportPDF.buildParamsFromState(stateOps, { page: 1 });
        params.set("format", fmt);

        const titulo = stateOps.groupBySala
            ? "Relatório - Registros de Operação (Agrupado)"
            : "Relatório - Registros de Operação (Lista)";

        const filenameBase = stateOps.groupBySala
            ? "relatorio_operacoes_sessoes"
            : "relatorio_operacoes_entradas";

        ReportPDF.openFromEndpoint(endpoint, params, {
            title: titulo,
            format: fmt,
            filenameBase: filenameBase,
        });
    }

    // =================================================================
    // --- LÓGICA DA TABELA DE OPERAÇÕES (SESSÕES) ---
    // =================================================================

    async function loadOperacoes() {
        const table = document.getElementById("tb-operacoes");
        if (!table) return;

        const thead = table.querySelector("thead");
        const tbody = table.querySelector("tbody");
        if (!thead || !tbody) return;

        // 1) Cabeçalho + comportamento visual conforme o modo
        // IMPORTANTe: só recria o <thead> quando muda o modo (evita o painel de filtro fechar a cada interação)
        const mode = stateOps.groupBySala ? "grouped" : "flat";
        if (table.dataset.opsMode !== mode) {
            table.dataset.opsMode = mode;

            if (stateOps.groupBySala) {
                // Modo AGRUPADO (como já era)
                table.classList.remove("table-hover");

                thead.innerHTML = `
                <tr>
                    <th style="width: 20px;"></th>
                    <th class="sortable" data-sort="sala" data-column="sala">Sala</th>
                    <th class="sortable" data-sort="data" data-column="data">Data</th>
                    <th class="sortable" data-sort="autor" data-column="autor">1º Registro por</th>
                    <th data-column="verificacao">Checklist?</th>
                    <th class="sortable" data-sort="em_aberto" data-column="em_aberto">Em Aberto?</th>
                </tr>
            `;
            } else {
                // Modo LISTA PLANA (sem sublinhas, uma linha por entrada)
                table.classList.add("table-hover");

                thead.innerHTML = `
                <tr>
                    <th class="sortable" data-sort="sala" data-column="sala">Sala</th>
                    <th class="sortable" data-sort="data" data-column="data">Data</th>
                    <th data-column="operador">Operador</th>
                    <th data-column="tipo">Tipo</th>
                    <th data-column="evento">Evento</th>
                    <th data-column="pauta">Pauta</th>
                    <th data-column="inicio">Início</th>
                    <th data-column="fim">Fim</th>
                    <th data-column="anormalidade">Anormalidade?</th>
                </tr>
            `;
            }
        }

        // (re)bind seguro (idempotente)
        Pagination.bindSortHeaders("tb-operacoes", stateOps, loadOperacoes);
        Pagination.updateHeaderIcons("tb-operacoes", stateOps);

        // 2) Endpoint conforme modo
        const endpoint = stateOps.groupBySala
            ? AppConfig.endpoints.adminDashboard.operacoes
            : AppConfig.endpoints.adminDashboard.operacoesEntradas;

        // 3) Params
        const params = new URLSearchParams({
            page: stateOps.page,
            limit: stateOps.limit,
            search: stateOps.search,
            sort: stateOps.sort,
            dir: stateOps.dir,
        });

        if (stateOps.periodo) {
            params.set("periodo", JSON.stringify(stateOps.periodo));
        }

        // Filtros por coluna (estilo Excel)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, stateOps);
        }

        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await Pagination.fetchJson(url);

        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar operações.";
            const colspan = stateOps.groupBySala ? 6 : 9;
            tbody.innerHTML = `<tr><td colspan="${colspan}" class="empty-state">Erro ao carregar operações (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-operacoes", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioOperacoes, state: stateOps, formatKey: "reportFormat" }
            });
            return;
        }

        const data = Array.isArray(resp.data) ? resp.data : [];
        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Distinct (values para checkboxes)
        if (window.TableFilter) {
            const distinctMap = meta && meta.distinct;

            // meta.distinct às vezes vem presente porém vazio ({} ou chaves com arrays vazios).
            // Nesse caso, caímos no fallback updateDistinctValues() para não abrir a lista “em branco”.
            const distinctHasValues =
                distinctMap &&
                typeof distinctMap === "object" &&
                Object.keys(distinctMap).some((k) => {
                    const v = distinctMap[k];

                    // Formato 1: { col: [ ... ] }
                    if (Array.isArray(v)) return v.length > 0;

                    // Formato 2: { col: { values: [ ... ] } } (compat)
                    if (v && typeof v === "object") {
                        if (Array.isArray(v.values)) return v.values.length > 0;
                        if (Array.isArray(v.options)) return v.options.length > 0;
                    }
                    return false;
                });

            if (distinctHasValues && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-operacoes", distinctMap);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                window.TableFilter.updateDistinctValues("tb-operacoes", data);
            }
        }

        if (data.length === 0) {
            const colspan = stateOps.groupBySala ? 6 : 9;
            tbody.innerHTML = `<tr><td colspan="${colspan}" class="empty-state">Nenhuma operação encontrada.</td></tr>`;
            Pagination.renderPaginationControls("pag-operacoes", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioOperacoes, state: stateOps, formatKey: "reportFormat" }
            });
            return;
        }

        // 4) Render
        if (stateOps.groupBySala) {
            // -----------------------------------------------------
            // MODO AGRUPADO: sessão + sublinhas (accordion)
            // -----------------------------------------------------
            data.forEach((sessao) => {
                // Normalizações (evita depender de casing/espacos)
                const verificRaw = String(sessao.verificacao || "--").trim();
                const verificNorm = verificRaw.toLowerCase();
                const checklistClass = (verificNorm === "realizado") ? "text-green" : "text-gray";

                const emAbertoRaw = String(sessao.em_aberto || "--").trim();
                const emAbertoNorm = emAbertoRaw.toLowerCase();
                const emAbertoIsSim = (emAbertoNorm === "sim");
                const emAbertoClass = emAbertoIsSim ? "text-blue" : "";

                // 1) Linha Pai (Sessão)
                const trParent = document.createElement("tr");
                trParent.className = "accordion-parent";
                trParent.setAttribute("title", "Clique para expandir/recolher");

                trParent.innerHTML = `
                    <td><span class="toggle-icon">▶</span></td>
                    <td><strong>${Utils.escapeHtml(sessao.sala || "--")}</strong></td>
                    <td><strong>${Utils.fmtDate(sessao.data)}</strong></td>
                    <td><strong>${Utils.escapeHtml(sessao.autor || "--")}</strong></td>
                    <td class="${checklistClass}">${Utils.escapeHtml(verificRaw || "--")}</td>
                    <td><strong class="${emAbertoClass}">${Utils.escapeHtml(emAbertoRaw || "--")}</strong></td>
                `;

                // 2) Linha Filha (Entradas)
                const trChild = document.createElement("tr");
                trChild.className = "accordion-child";

                let entradasHtml = "";
                if (Array.isArray(sessao.entradas) && sessao.entradas.length > 0) {
                    entradasHtml = `
                        <div style="margin-bottom:8px; font-size:0.85em; color:#64748b;">
                            ℹ️ <em>Dê um duplo-clique na linha para ver o formulário detalhado.</em>
                        </div>

                        <table class="sub-table table-hover">
                            <thead>
                                <tr>
                                    <th style="width:40px;">Nº</th>
                                    <th>Operador</th>
                                    <th>Tipo</th>
                                    <th>Evento</th>
                                    <th>Pauta</th>
                                    <th>Início</th>
                                    <th>Fim</th>
                                    <th>Anormalidade?</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${sessao.entradas.map((ent) => {
                        const anom = !!ent.anormalidade;
                        const anomText = anom ? "SIM" : "Não";
                        const anomClass = anom ? "text-red bold" : "text-green";

                        return `
                                        <tr class="entry-row" data-id="${ent.id}" title="Duplo-clique para abrir formulário">
                                            <td>${Utils.escapeHtml(ent.ordem)}º</td>
                                            <td>${Utils.escapeHtml(ent.operador || "--")}</td>
                                            <td>${Utils.escapeHtml(ent.tipo || "--")}</td>
                                            <td>${Utils.escapeHtml(ent.evento || "--")}</td>
                                            <td>${Utils.fmtTime(ent.pauta)}</td>
                                            <td>${Utils.fmtTime(ent.inicio)}</td>
                                            <td>${Utils.fmtTime(ent.fim)}</td>
                                            <td class="${anomClass}">${anomText}</td>
                                        </tr>
                                    `;
                    }).join("")}
                            </tbody>
                        </table>
                    `;
                } else {
                    entradasHtml = `<div style="padding:10px;">Nenhuma entrada registrada nesta sessão.</div>`;
                }

                trChild.innerHTML = `
                    <td colspan="6">
                        <div class="sub-table-wrap">
                            ${entradasHtml}
                        </div>
                    </td>
                `;

                // Abrir/fechar accordion (usando CSS do dashboard.css)
                trParent.addEventListener("click", () => {
                    trParent.classList.toggle("open");
                    trChild.classList.toggle("visible", trParent.classList.contains("open"));
                });

                // Duplo clique nas sublinhas: abre o form correto (sem 404)
                const entryRows = trChild.querySelectorAll(".entry-row");
                entryRows.forEach((row) => {
                    row.addEventListener("dblclick", (e) => {
                        e.stopPropagation();
                        const entradaId = row.getAttribute("data-id");
                        if (!entradaId) return;

                        window.open(
                            `/admin/form_operacao.html?entrada_id=${encodeURIComponent(entradaId)}`,
                            "_blank"
                        );
                    });
                });

                tbody.appendChild(trParent);
                tbody.appendChild(trChild);
            });

        } else {
            // -----------------------------------------------------
            // MODO LISTA PLANA: uma linha por entrada (sem sublinhas)
            // -----------------------------------------------------
            data.forEach((item) => {
                const tr = document.createElement("tr");
                tr.className = "entry-row";
                tr.setAttribute("title", "Duplo-clique para ver o formulário detalhado");

                const anom = !!item.anormalidade;
                const anomText = anom ? "SIM" : "Não";
                const anomClass = anom ? "text-red bold" : "text-green";

                tr.innerHTML = `
                    <td><strong>${Utils.escapeHtml(item.sala || "--")}</strong></td>
                    <td><strong>${Utils.fmtDate(item.data)}</strong></td>
                    <td>${Utils.escapeHtml(item.operador || "--")}</td>
                    <td>${Utils.escapeHtml(item.tipo || "--")}</td>
                    <td>${Utils.escapeHtml(item.evento || "--")}</td>
                    <td>${Utils.fmtTime(item.pauta)}</td>
                    <td>${Utils.fmtTime(item.inicio)}</td>
                    <td>${Utils.fmtTime(item.fim)}</td>
                    <td class="${anomClass}">${anomText}</td>
                `;

                tr.addEventListener("dblclick", () => {
                    const entradaId = item.id;
                    if (!entradaId) return;

                    window.open(
                        `/admin/form_operacao.html?entrada_id=${encodeURIComponent(entradaId)}`,
                        "_blank"
                    );
                });

                tbody.appendChild(tr);
            });
        }

        // 5) Paginação
        Pagination.renderPaginationControls("pag-operacoes", meta, (p) => {
            stateOps.page = p;
            loadOperacoes();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioOperacoes, state: stateOps, formatKey: "reportFormat" }
        });
    }

    // =================================================================
    // --- LÓGICA DA TABELA DE ANORMALIDADES (LISTA PLANA) ---
    // =================================================================

    async function loadAnormalidades() {
        Pagination.updateHeaderIcons("tb-anormalidades", anomState);

        const endpoint = AppConfig.endpoints.adminDashboard.anormalidades.lista;
        const params = new URLSearchParams({
            page: anomState.page,
            limit: anomState.limit,
            search: anomState.search,
            sort: anomState.sort,
            dir: anomState.dir,
        });

        if (anomState.periodo) {
            params.set("periodo", JSON.stringify(anomState.periodo));
        }

        // Filtros por coluna (estilo Excel)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, anomState);
        }

        const url = `${AppConfig.apiUrl(endpoint)}?${params.toString()}`;
        const resp = await Pagination.fetchJson(url);

        const tbody = document.querySelector("#tb-anormalidades tbody");
        if (!tbody) return;
        tbody.innerHTML = "";

        if (!resp || resp.ok === false) {
            const status = (resp && typeof resp.status === "number" && resp.status) ? resp.status : "??";
            const msg = (resp && resp.error) ? resp.error : "Falha ao carregar anormalidades.";
            tbody.innerHTML = `<tr><td colspan="8" class="empty-state">Erro ao carregar anormalidades (HTTP ${status}). ${Utils.escapeHtml(msg)}</td></tr>`;
            Pagination.renderPaginationControls("pag-anormalidades", null, null, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioAnormalidades, state: anomState, formatKey: "reportFormat" }
            });
            return;
        }

        const data = Array.isArray(resp.data) ? resp.data : [];
        const meta = resp.meta || { page: 1, pages: 1, total: 0 };

        // Valores únicos (checkboxes) do filtro por coluna (sem depender da página atual)
        if (window.TableFilter) {
            if (meta.distinct && typeof window.TableFilter.applyDistinctMap === "function") {
                window.TableFilter.applyDistinctMap("tb-anormalidades", meta.distinct);
            } else if (typeof window.TableFilter.updateDistinctValues === "function") {
                window.TableFilter.updateDistinctValues("tb-anormalidades", data);
            }
        }

        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="8" class="empty-state">Nenhuma anormalidade encontrada.</td></tr>`;
            // Se tiver div externa de paginação, reseta ela aqui
            Pagination.renderPaginationControls("pag-anormalidades", meta, (p) => {
                anomState.page = p;
                loadAnormalidades();
            }, {
                report: { label: "Gerar Relatório", onClick: gerarRelatorioAnormalidades, state: anomState, formatKey: "reportFormat" }
            });
            return;
        }

        data.forEach(row => {
            const tr = document.createElement("tr");

            const dateStr = Utils.fmtDate(row.data);
            const solucaoBadge = row.solucionada
                ? `<span class="text-green bold">Sim</span>`
                : `<span class="text-red">Não</span>`;

            const prejClass = row.houve_prejuizo ? "text-red bold" : "text-gray";
            const prejText = row.houve_prejuizo ? "Sim" : "Não";

            const reclClass = row.houve_reclamacao ? "text-red bold" : "text-gray";
            const reclText = row.houve_reclamacao ? "Sim" : "Não";

            // Corta descrição longa
            const descRaw = row.descricao || "";
            const desc = descRaw.length > 50
                ? descRaw.substring(0, 50) + "..."
                : descRaw;

            tr.innerHTML = `
                <td>${dateStr}</td>
                <td>${Utils.escapeHtml(row.sala || '--')}</td>
                <td>${Utils.escapeHtml(row.registrado_por)}</td>
                <td title="${Utils.escapeHtml(descRaw)}">${Utils.escapeHtml(desc)}</td>
                <td>${solucaoBadge}</td>
                <td class="${prejClass}">${prejText}</td>
                <td class="${reclClass}">${reclText}</td>
                <td>
                    <button class="btn-xs btn-ver-anom" data-id="${row.id}">Detalhes</button>
                </td>
            `;

            // Bind botão
            const btn = tr.querySelector(".btn-ver-anom");
            btn.addEventListener("click", () => {
                window.open(`/admin/form_anormalidade.html?id=${row.id}`, '_blank');
            });

            tbody.appendChild(tr);
        });

        // Cria a div de paginação dinamicamente se não existir no HTML
        let pagContainer = document.getElementById("pag-anormalidades");
        if (!pagContainer) {
            pagContainer = document.createElement("div");
            pagContainer.id = "pag-anormalidades";
            pagContainer.className = "pagination-controls";
            document.querySelector("#tb-anormalidades").parentNode.after(pagContainer);
        }

        Pagination.renderPaginationControls("pag-anormalidades", meta, (p) => {
            anomState.page = p;
            loadAnormalidades();
        }, {
            report: { label: "Gerar Relatório", onClick: gerarRelatorioAnormalidades, state: anomState, formatKey: "reportFormat" }
        });
    }


    // =========================================================
    // --- Inicialização ---
    // =========================================================
    document.addEventListener("DOMContentLoaded", () => {
        // 1. Tabela de Operações (Busca e Ordenação)
        const searchOps = document.getElementById("search-operacoes");
        if (searchOps) {
            searchOps.addEventListener("input", Utils.debounce((e) => {
                stateOps.search = e.target.value.trim();
                stateOps.page = 1;
                loadOperacoes();
            }, 400));
        }
        // 1.2. Filtros por coluna (estilo Excel) — Operações (Sessões/Entradas)
        if (window.TableFilter && typeof window.TableFilter.init === "function") {
            if (typeof window.TableFilter.destroy === "function") {
                window.TableFilter.destroy("tb-operacoes");
            }

            window.TableFilter.init({
                tableId: "tb-operacoes",
                state: stateOps,
                getColumns: () => {
                    if (stateOps.groupBySala) {
                        return {
                            sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala", label: "Local" },
                            data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                            autor: { type: "text", sortable: true, sortKey: "autor", dataKey: "autor", label: "1º Registro por" },
                            verificacao: { type: "text", sortable: false, dataKey: "verificacao", label: "Checklist?" },
                            em_aberto: { type: "text", sortable: true, sortKey: "em_aberto", dataKey: "em_aberto", label: "Em Aberto?" },
                        };
                    }

                    // modo lista plana (uma linha por entrada)
                    return {
                        sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala", label: "Local" },
                        data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                        operador: { type: "text", sortable: false, dataKey: "operador", label: "Operador" },
                        tipo: { type: "text", sortable: false, dataKey: "tipo", label: "Tipo" },
                        evento: { type: "text", sortable: false, dataKey: "evento", label: "Evento" },
                        pauta: { filterable: false, label: "Pauta" },
                        inicio: { filterable: false, label: "Início" },
                        fim: { filterable: false, label: "Fim" },
                        anormalidade: { type: "bool", sortable: false, dataKey: "anormalidade", label: "Anormalidade?" },
                    };
                },
                onChange: loadOperacoes,
                debounceMs: 250,
            });
        }

        // 1.1. Filtro por Período (Operações) + checkbox "Agrupar por sala"
        const toolbarOps = searchOps ? searchOps.closest(".toolbar") : null;
        if (toolbarOps && window.PeriodoFilter && typeof window.PeriodoFilter.createPeriodoUI === "function") {
            window.PeriodoFilter.createPeriodoUI({
                toolbarEl: toolbarOps,
                getPeriodo: () => stateOps.periodo,
                setPeriodo: (p) => {
                    stateOps.periodo = p;
                    stateOps.page = 1;
                    loadOperacoes();
                }
            });


            // Depois de criar o filtro de período, pegamos a linha do "Filtrar por data"
            const sectionHeader = toolbarOps.closest(".section-header");
            let dateFilterLine = null;
            let inlineControls = null;

            if (sectionHeader) {
                const wrapper = sectionHeader.nextElementSibling;
                if (wrapper && wrapper.classList.contains("date-filter-wrapper")) {
                    dateFilterLine = wrapper.querySelector(".date-filter-line");
                    inlineControls = wrapper.querySelector(".date-filter-inline");
                }
            }

            // Cria o checkbox "Agrupar por sala"
            const lblGroup = document.createElement("label");
            lblGroup.className = "date-filter-toggle";
            lblGroup.innerHTML = `
                <input type="checkbox" id="chk-group-by-sala" checked>
                <span>Agrupar por local</span>
            `;

            // Insere bem perto do "Filtrar por data"
            if (dateFilterLine && inlineControls) {
                dateFilterLine.insertBefore(lblGroup, inlineControls);
            } else if (dateFilterLine) {
                dateFilterLine.appendChild(lblGroup);
            } else if (toolbarOps) {
                // Fallback: dentro da própria toolbar (caso algo mude no HTML)
                toolbarOps.appendChild(lblGroup);
            }
            // --- RDS (Ano/Mês + Botão) deve aparecer na mesma linha do filtro por data ---
            initRdsUi(dateFilterLine || toolbarOps);

            const chkGroup = lblGroup.querySelector("#chk-group-by-sala");
            if (chkGroup) {
                chkGroup.checked = stateOps.groupBySala;
                chkGroup.addEventListener("change", (e) => {
                    stateOps.groupBySala = e.target.checked;
                    stateOps.page = 1;
                    loadOperacoes();
                });
            }
        }

        // 2. Tabela de Anormalidades (Busca + ordenação)
        const searchAnom = document.getElementById("search-anormalidades");
        if (searchAnom) {
            searchAnom.addEventListener("input", Utils.debounce((e) => {
                anomState.search = e.target.value.trim();
                anomState.page = 1;
                loadAnormalidades();
            }, 400));
        }
        Pagination.bindSortHeaders("tb-anormalidades", anomState, loadAnormalidades);

        // 2.1. Filtros por coluna (estilo Excel)
        if (window.TableFilter && typeof window.TableFilter.init === "function") {
            window.TableFilter.init({
                tableId: "tb-anormalidades",
                state: anomState,
                columns: {
                    data: { type: "date", sortable: true, sortKey: "data", dataKey: "data", label: "Data" },
                    sala: { type: "text", sortable: true, sortKey: "sala", dataKey: "sala", label: "Local" },
                    registrado_por: { type: "text", sortable: true, sortKey: "registrado_por", dataKey: "registrado_por", label: "Registrado por" },
                    descricao: { type: "text", sortable: true, sortKey: "descricao", dataKey: "descricao", label: "Descrição" },
                    solucionada: { type: "bool", sortable: true, sortKey: "solucionada", dataKey: "solucionada", label: "Solucionada" },
                    houve_prejuizo: { type: "bool", sortable: false, dataKey: "houve_prejuizo", label: "Prejuízo" },
                    houve_reclamacao: { type: "bool", sortable: false, dataKey: "houve_reclamacao", label: "Reclamação" },
                    acao: { filterable: false, label: "Ação" },
                },
                onChange: loadAnormalidades,
                debounceMs: 250,
            });
        }

        // 2.2. Filtro por Período (Anormalidades)
        const toolbarAnom = searchAnom ? searchAnom.closest(".toolbar") : null;
        if (toolbarAnom && window.PeriodoFilter && typeof window.PeriodoFilter.createPeriodoUI === "function") {
            window.PeriodoFilter.createPeriodoUI({
                toolbarEl: toolbarAnom,
                getPeriodo: () => anomState.periodo,
                setPeriodo: (p) => {
                    anomState.periodo = p;
                    anomState.page = 1;
                    loadAnormalidades();
                }
            });
        }

        // 3. Carga Inicial
        loadOperacoes();
        loadAnormalidades();
    });


})();