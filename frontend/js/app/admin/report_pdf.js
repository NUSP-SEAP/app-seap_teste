(function () {
    "use strict";

    async function safeJson(resp) {
        try { return await resp.json(); } catch (_) { return null; }
    }

    async function authFetch(url, options) {
        if (window.Auth && typeof window.Auth.authFetch === "function") {
            return window.Auth.authFetch(url, options);
        }
        return fetch(url, options);
    }

    function buildParamsFromState(state, options) {
        const opts = options || {};
        const includePeriodo = opts.includePeriodo !== false; // default true
        const page = typeof opts.page === "number" ? opts.page : 1;
        const limit = typeof opts.limit === "number"
            ? opts.limit
            : ((state && state.limit) ? state.limit : 100);

        const params = new URLSearchParams();
        params.set("page", String(page));
        params.set("limit", String(limit));

        if (state && state.search) params.set("search", state.search);
        if (state && state.sort) params.set("sort", state.sort);
        if (state && state.dir) params.set("dir", state.dir);

        if (includePeriodo && state && state.periodo) {
            try { params.set("periodo", JSON.stringify(state.periodo)); } catch (_) { }
        }

        // filtros por coluna (TableFilter)
        if (window.TableFilter && typeof window.TableFilter.applyToParams === "function") {
            window.TableFilter.applyToParams(params, state);
        }

        return params;
    }

    function normalizeFormat(fmt) {
        let f = String(fmt || "").trim().toLowerCase();
        if (f.startsWith(".")) f = f.slice(1);
        if (f === "pdf" || f === "docx") return f;
        return "pdf";
    }

    function mimeForFormat(fmt) {
        const f = normalizeFormat(fmt);
        return (f === "docx")
            ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            : "application/pdf";
    }

    function extractFilenameFromContentDisposition(cd) {
        if (!cd) return "";
        const m = String(cd).match(/filename\*?=(?:UTF-8''|")?([^";\n]+)"?/i);
        if (!m) return "";
        try { return decodeURIComponent(m[1]); } catch (_) { return m[1]; }
    }

    function ensureExt(filename, fmt) {
        const f = normalizeFormat(fmt);
        if (!filename) return "";
        const lower = filename.toLowerCase();
        if (lower.endsWith("." + f)) return filename;
        return ""; // ignora nome vindo errado (ex.: servidor ainda manda .pdf quando pedimos docx)
    }

    async function openFromUrl(url, options) {
        const opts = options || {};
        const tabTitle = opts.title || "Relatório";
        const fmt = normalizeFormat(opts.format);
        const filenameBase = (opts.filenameBase || "relatorio").trim();

        // Abre a aba imediatamente (evita bloqueio por async)
        const tab = window.open("about:blank", "_blank");
        if (!tab) {
            alert("Não foi possível abrir uma nova guia. Verifique o bloqueador de pop-ups.");
            return;
        }

        // Segurança equivalente ao noopener (sem perder referência da janela)
        try { tab.opener = null; } catch (_) { }

        try {
            tab.document.title = tabTitle;
            tab.document.body.innerHTML = `
                <div style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; padding: 24px;">
                  <h2 style="margin: 0 0 8px 0;">Gerando relatório...</h2>
                  <p style="margin: 0; color: #64748b;">Aguarde alguns segundos.</p>
                </div>
            `;

            const resp = await authFetch(url, { method: "GET", headers: { "Accept": mimeForFormat(fmt) } });

            if (!resp || !resp.ok) {
                const payload = resp ? await safeJson(resp) : null;
                const msg = (payload && (payload.error || payload.detail || payload.message))
                    ? (payload.error || payload.detail || payload.message)
                    : `Falha ao gerar o relatório${resp ? ` (HTTP ${resp.status})` : ""}.`;

                try { tab.close(); } catch (_) { }
                alert(msg);
                return;
            }

            const blob = await resp.blob();
            const blobUrl = URL.createObjectURL(blob);

            if (fmt === "pdf") {
                tab.location.href = blobUrl;
                setTimeout(() => URL.revokeObjectURL(blobUrl), 60 * 1000);
                return;
            }

            // DOCX: download (não renderiza no browser)
            const cd = resp.headers ? (resp.headers.get("content-disposition") || resp.headers.get("Content-Disposition") || "") : "";
            const serverName = ensureExt(extractFilenameFromContentDisposition(cd), "docx");
            const downloadName = serverName || `${filenameBase}.docx`;

            tab.document.title = tabTitle;
            tab.document.body.innerHTML = `
                <div style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; padding: 24px;">
                  <h2 style="margin: 0 0 8px 0;">Relatório DOCX pronto</h2>
                  <p style="margin: 0 0 12px 0; color: #64748b;">
                    Se o download não iniciar automaticamente, clique no link abaixo:
                  </p>
                  <a id="download-link"
                     style="display:inline-block; padding:10px 14px; border:1px solid #cbd5e1; border-radius:8px; text-decoration:none;">
                    Baixar
                  </a>
                </div>
            `;

            const a = tab.document.getElementById("download-link");
            if (a) {
                a.href = blobUrl;
                a.download = downloadName;
                a.textContent = `Baixar ${downloadName}`;
                try { a.click(); } catch (_) { }
            }

            setTimeout(() => URL.revokeObjectURL(blobUrl), 2 * 60 * 1000);

        } catch (err) {
            console.error(err);
            try { tab.close(); } catch (_) { }
            alert("Erro inesperado ao gerar o relatório.");
        }
    }

    async function openFromEndpoint(endpoint, params, options) {
        // Suporta AppConfig como variável global (const AppConfig = ...) OU window.AppConfig
        const cfg = (typeof AppConfig !== "undefined" && AppConfig) ? AppConfig : (window.AppConfig || null);

        if (!cfg || typeof cfg.apiUrl !== "function") {
            throw new Error("AppConfig.apiUrl não está disponível.");
        }

        const qs = params ? params.toString() : "";
        const url = qs ? `${cfg.apiUrl(endpoint)}?${qs}` : cfg.apiUrl(endpoint);
        return openFromUrl(url, options);
    }

    window.ReportPDF = { buildParamsFromState, openFromUrl, openFromEndpoint };
})();