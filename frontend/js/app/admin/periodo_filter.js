// app/js/app/admin/periodo_filter.js
(function () {
    "use strict";

    const MIN_YEAR = 2010;
    const CURRENT_YEAR = new Date().getFullYear();
    const MONTH_NAMES = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
        "Jul", "Ago", "Set", "Out", "Nov", "Dez"];

    // ---------------- Utils ----------------

    function pad2(n) {
        return String(n).padStart(2, "0");
    }

    function lastDayOfMonth(year, month) {
        // month: 1–12
        return new Date(year, month, 0).getDate();
    }

    /**
     * Gera semanas de um determinado mês/ano no formato:
     * [{ from: 1, to: 2 }, { from: 3, to: 9 }, ...]
     * Primeira semana: dia 1 até o primeiro domingo.
     * Depois, blocos de 7 dias (seg–dom) e uma parcial final.
     */
    function buildWeeks(year, month) {
        const last = lastDayOfMonth(year, month);
        if (!year || !month || last <= 0) return [];

        // Encontra o primeiro domingo (0 = domingo) entre 1 e 7
        let firstSunday = 1;
        for (let d = 1; d <= Math.min(7, last); d++) {
            const dow = new Date(year, month - 1, d).getDay();
            if (dow === 0) {
                firstSunday = d;
                break;
            }
        }

        const weeks = [];
        // Primeira semana: 1 até firstSunday
        weeks.push({ from: 1, to: firstSunday });

        // Demais semanas: blocos de 7 dias
        let start = firstSunday + 1;
        while (start <= last) {
            const end = Math.min(start + 6, last);
            weeks.push({ from: start, to: end });
            start = end + 1;
        }
        return weeks;
    }

    // ---------------- Parse de entradas ----------------

    /**
     * Base comum para parseYears e parseMonths.
     * Interpreta uma expressão de inteiros separados por vírgula, com
     * suporte a intervalos (ex: "2020, 2022-2024" ou "1, 3-5").
     * Retorna [] se vazio, null se inválido ou fora do range [min, max].
     * @param {string} digitPattern - padrão de dígitos sem âncoras (ex: "\\d{4}" ou "\\d{1,2}")
     */
    function parseRange(expr, min, max, digitPattern) {
        const raw = (expr || "").trim();
        if (!raw) return [];

        const results = [];
        const parts = raw.split(",");
        const reSingle = new RegExp("^" + digitPattern + "$");
        const reRange = new RegExp("^(" + digitPattern + ")\\s*-\\s*(" + digitPattern + ")$");

        for (let part of parts) {
            part = part.trim();
            if (!part) continue;

            if (reSingle.test(part)) {
                const v = parseInt(part, 10);
                if (!Number.isFinite(v) || v < min || v > max) return null;
                results.push(v);
                continue;
            }

            const m = part.match(reRange);
            if (m) {
                let v1 = parseInt(m[1], 10);
                let v2 = parseInt(m[2], 10);
                if (!Number.isFinite(v1) || !Number.isFinite(v2)) return null;
                if (v1 > v2) { const tmp = v1; v1 = v2; v2 = tmp; }
                if (v1 < min || v2 > max) return null;
                for (let v = v1; v <= v2; v++) results.push(v);
                continue;
            }

            return null;
        }

        const unique = Array.from(new Set(results));
        unique.sort((a, b) => a - b);
        return unique;
    }

    /** Interpreta expressão de anos (ex: "2020, 2022-2024"). Retorna [] se vazio, null se inválido. */
    function parseYears(expr) {
        return parseRange(expr, MIN_YEAR, CURRENT_YEAR, "\\d{4}");
    }

    /** Interpreta expressão de meses (ex: "1, 3-5, 10-12"). Retorna [] se vazio, null se inválido. */
    function parseMonths(expr) {
        return parseRange(expr, 1, 12, "\\d{1,2}");
    }

    /**
     * Gera semanas (como ranges) para um conjunto de anos e meses.
     * Se 'months' estiver vazio ou falsy, usa todos os meses (1–12).
     */
    function buildWeeksForYearMonths(years, months) {
        const result = [];
        if (!Array.isArray(years) || !years.length) return result;

        years.forEach((year) => {
            const monthsToUse = Array.isArray(months) && months.length
                ? months
                : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

            monthsToUse.forEach((month) => {
                const segs = buildWeeks(year, month);
                segs.forEach((seg) => {
                    const start = year + "-" + pad2(month) + "-" + pad2(seg.from);
                    const end = year + "-" + pad2(month) + "-" + pad2(seg.to);
                    const label = year + " · " +
                        (MONTH_NAMES[month - 1] || ("Mês " + month)) +
                        " · " + seg.from + " a " + seg.to;
                    result.push({ start: start, end: end, label: label });
                });
            });
        });

        return result;
    }

    function formatDateLabel(iso) {
        if (!iso) return "--";
        const parts = iso.split("-");
        if (parts.length !== 3) return iso;
        return parts[2] + "/" + parts[1] + "/" + parts[0];
    }

    function formatRangeLabel(start, end) {
        if (!start || !end) return "--";
        if (start === end) {
            return formatDateLabel(start);
        }
        return formatDateLabel(start) + " a " + formatDateLabel(end);
    }

    // ---------------- UI principal ----------------

    /**
     * options:
     *  - toolbarEl: <div class="toolbar"> da seção
     *  - getPeriodo(): retorna state.periodo (ou null)
     *  - setPeriodo(obj|null): atualiza state.periodo e recarrega tabela
     */
    function createPeriodoUI(options) {
        const toolbarEl = options && options.toolbarEl;
        const getPeriodo = options && options.getPeriodo;
        const setPeriodo = options && options.setPeriodo;

        if (!toolbarEl || typeof getPeriodo !== "function" || typeof setPeriodo !== "function") {
            return;
        }

        const sectionHeader = toolbarEl.closest(".section-header") || toolbarEl.parentElement;

        // Wrapper abaixo do título + busca
        const wrapper = document.createElement("div");
        wrapper.className = "date-filter-wrapper";
        wrapper.innerHTML = `
            <div class="date-filter-line">
                <label class="date-filter-toggle">
                    <input type="checkbox" class="date-filter-checkbox">
                    <span>Filtrar por data</span>
                </label>

                <div class="date-filter-inline hidden">
                    <input type="text"
                           class="date-filter-input"
                           data-role="year-input"
                           placeholder="Anos (ex.: 2020, 2022-2024)">
                    <input type="text"
                           class="date-filter-input"
                           data-role="month-input"
                           placeholder="Meses (ex.: 1, 3-5, 10-12)">
                    <select class="date-filter-select" data-role="week-select" disabled>
                        <option value="">Semana (opcional)</option>
                    </select>
                    <button type="button" class="btn-page date-filter-button" data-action="apply-period">
                        Aplicar filtro
                    </button>
                    <button type="button" class="btn-page date-filter-button" data-action="clear-periods">
                        Limpar filtro
                    </button>
                </div>
            </div>

            <div class="date-filter-periods hidden">
                <div class="periodo-selected-title">Períodos selecionados</div>
                <div class="periodo-ranges-list" data-role="ranges-list">
                    <p class="periodo-hint">Nenhum período selecionado.</p>
                </div>
            </div>
        `;

        if (sectionHeader && sectionHeader.parentNode) {
            sectionHeader.parentNode.insertBefore(wrapper, sectionHeader.nextSibling);
        } else if (toolbarEl.parentNode) {
            toolbarEl.parentNode.insertBefore(wrapper, toolbarEl.nextSibling);
        } else {
            // fallback
            toolbarEl.appendChild(wrapper);
        }

        const checkbox = wrapper.querySelector(".date-filter-checkbox");
        const controls = wrapper.querySelector(".date-filter-inline");
        const yearInput = wrapper.querySelector('[data-role="year-input"]');
        const monthInput = wrapper.querySelector('[data-role="month-input"]');
        const weekSelect = wrapper.querySelector('[data-role="week-select"]');
        const periodsBox = wrapper.querySelector(".date-filter-periods");
        const rangesListEl = wrapper.querySelector('[data-role="ranges-list"]');

        let ranges = [];

        function syncFromState() {
            const periodo = getPeriodo();
            if (periodo && Array.isArray(periodo.ranges)) {
                ranges = periodo.ranges.slice();
            } else {
                ranges = [];
            }
            renderRanges();
        }

        function renderRanges() {
            if (!rangesListEl) return;

            if (!ranges.length) {
                rangesListEl.innerHTML = '<p class="periodo-hint">Nenhum período selecionado.</p>';
                return;
            }

            const html = ranges.map((r, idx) => {
                const label = formatRangeLabel(r.start, r.end);
                return (
                    '<div class="periodo-range-row" data-index="' + idx + '">' +
                    '<span>' + label + '</span>' +
                    '<button type="button" class="btn-xs btn-remove-range" data-index="' + idx + '">Remover</button>' +
                    '</div>'
                );
            }).join("");

            rangesListEl.innerHTML = html;

            rangesListEl.querySelectorAll(".btn-remove-range").forEach((btnRm) => {
                btnRm.addEventListener("click", () => {
                    const idxStr = btnRm.getAttribute("data-index");
                    const idx = parseInt(idxStr, 10);
                    if (Number.isInteger(idx) && idx >= 0 && idx < ranges.length) {
                        ranges.splice(idx, 1);
                        setPeriodo(ranges.length ? { ranges: ranges.slice() } : null);
                        renderRanges();
                    }
                });
            });
        }

        function updateWeeksOptions() {
            if (!weekSelect) return;

            const yearRaw = (yearInput && yearInput.value || "").trim();
            const monthRaw = (monthInput && monthInput.value || "").trim();

            // Reset
            weekSelect.innerHTML = '<option value="">Semana (opcional)</option>';
            weekSelect.disabled = true;

            // Precisa ter pelo menos um ano válido para listar semanas
            if (!yearRaw) {
                return;
            }

            const years = parseYears(yearRaw);
            if (!years || !years.length) {
                // expressão de anos inválida ou fora do range
                return;
            }

            const months = parseMonths(monthRaw);
            if (months === null) {
                // meses inválidos → não preenche
                return;
            }

            const weeks = buildWeeksForYearMonths(years, months);
            if (!weeks.length) {
                return;
            }

            weeks.forEach((w) => {
                const opt = document.createElement("option");
                opt.value = w.start + "|" + w.end;
                opt.textContent = w.label;
                weekSelect.appendChild(opt);
            });

            weekSelect.disabled = false;
        }

        // -------- Eventos --------

        // Toggle geral: mostra/esconde controles
        checkbox.addEventListener("change", () => {
            if (checkbox.checked) {
                controls.classList.remove("hidden");
                periodsBox.classList.remove("hidden");
                syncFromState();
                updateWeeksOptions();
            } else {
                controls.classList.add("hidden");
                periodsBox.classList.add("hidden");

                if (yearInput) yearInput.value = "";
                if (monthInput) monthInput.value = "";
                if (weekSelect) {
                    weekSelect.innerHTML = '<option value="">Semana (opcional)</option>';
                    weekSelect.disabled = true;
                }

                ranges = [];
                setPeriodo(null);
                renderRanges();
            }
        });

        if (yearInput) {
            yearInput.addEventListener("blur", updateWeeksOptions);
        }
        if (monthInput) {
            monthInput.addEventListener("blur", updateWeeksOptions);
        }

        controls.addEventListener("click", (ev) => {
            const target = ev.target;
            if (!(target instanceof HTMLElement)) return;

            const action = target.getAttribute("data-action");
            if (!action) return;

            if (action === "apply-period") {
                const weekValue = weekSelect && weekSelect.value ? weekSelect.value : "";
                const newRanges = [];

                if (weekValue) {
                    // Filtro por semana: usa apenas a semana escolhida.
                    const parts = weekValue.split("|");
                    if (parts.length === 2 && parts[0] && parts[1]) {
                        newRanges.push({ start: parts[0], end: parts[1] });
                    } else {
                        alert("Semana selecionada inválida.");
                        return;
                    }
                } else {
                    // Filtro por ano/mês (semana não selecionada)
                    const months = parseMonths(monthInput && monthInput.value);
                    if (months === null) {
                        alert("Expressão de meses inválida. Use, por exemplo: 1, 3-5, 10-12.");
                        return;
                    }

                    const years = parseYears(yearInput && yearInput.value);
                    if (years === null) {
                        alert("Expressão de anos inválida. Use, por exemplo: 2010, 2012, 2014-2017 (de "
                            + MIN_YEAR + " até " + CURRENT_YEAR + ").");
                        return;
                    }

                    if (years.length) {
                        // Anos informados:
                        if (months && months.length) {
                            // Ano + meses específicos
                            years.forEach((y) => {
                                months.forEach((m) => {
                                    const dEnd = lastDayOfMonth(y, m);
                                    const s = y + "-" + pad2(m) + "-01";
                                    const e = y + "-" + pad2(m) + "-" + pad2(dEnd);
                                    newRanges.push({ start: s, end: e });
                                });
                            });
                        } else {
                            // Apenas anos: ano(s) inteiro(s)
                            years.forEach((y) => {
                                newRanges.push({
                                    start: y + "-01-01",
                                    end: y + "-12-31"
                                });
                            });
                        }
                    } else {
                        // Nenhum ano informado: meses sozinhos
                        if (!months || !months.length) {
                            alert("Informe anos, meses ou selecione uma semana para aplicar o filtro.");
                            return;
                        }
                        for (let y = MIN_YEAR; y <= CURRENT_YEAR; y++) {
                            months.forEach((m) => {
                                const dEnd = lastDayOfMonth(y, m);
                                const s = y + "-" + pad2(m) + "-01";
                                const e = y + "-" + pad2(m) + "-" + pad2(dEnd);
                                newRanges.push({ start: s, end: e });
                            });
                        }
                    }
                }

                if (!newRanges.length) {
                    alert("Nenhum período pôde ser gerado a partir dos dados informados.");
                    return;
                }

                // Acumula ranges sem duplicar exatamente iguais
                newRanges.forEach((nr) => {
                    const exists = ranges.some((r) => r.start === nr.start && r.end === nr.end);
                    if (!exists) {
                        ranges.push(nr);
                    }
                });

                setPeriodo({ ranges: ranges.slice() });
                renderRanges();
                return;
            }

            if (action === "clear-periods") {
                // Limpa apenas os períodos já aplicados
                ranges = [];
                setPeriodo(null);
                renderRanges();

                if (weekSelect) weekSelect.value = "";
                // Anos/meses ficam preenchidos para facilitar nova tentativa
                return;
            }
        });

        // Não aplicamos filtro automaticamente ao carregar a página.
    }

    window.PeriodoFilter = {
        createPeriodoUI: createPeriodoUI
    };
})();
