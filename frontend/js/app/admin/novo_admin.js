(function () {
    "use strict";

    const FORM_ID = "form-novo-admin";
    const STATUS_ID = "status-message";

    const WEBHOOK_URL = AppConfig.apiUrl(
        (AppConfig.endpoints.admin && AppConfig.endpoints.admin.novoAdmin) ||
        "/webhook/admin/admins/novo"
    );

    function getToken() {
        return (localStorage.getItem("auth_token") || "").trim();
    }

    async function ensureDouglasOnly() {
        const token = getToken();
        if (!token) {
            window.location.replace("/index.html");
            return false;
        }

        let resp;
        try {
            const whoamiUrl = AppConfig.apiUrl(AppConfig.endpoints.auth.whoami);
            resp = await fetch(whoamiUrl, {
                method: "GET",
                headers: {
                    "Authorization": "Bearer " + token,
                    "Accept": "application/json"
                }
            });
        } catch (e) {
            window.location.replace("/index.html");
            return false;
        }

        if (resp.status === 401 || !resp.ok) {
            window.location.replace("/index.html");
            return false;
        }

        let data;
        try {
            data = await resp.json();
        } catch (e) {
            window.location.replace("/index.html");
            return false;
        }

        const user = (data && data.user) || {};
        const username = (user.username || "").toLowerCase();

        if (username !== "douglas.antunes") {
            window.location.replace("/home.html");
            return false;
        }

        return true;
    }

    function initForm() {
        const form = document.getElementById(FORM_ID);
        if (!form) return;

        const statusEl = document.getElementById(STATUS_ID);
        const btnVoltar = document.getElementById("btn-voltar");

        if (btnVoltar) {
            btnVoltar.addEventListener("click", function (ev) {
                ev.preventDefault();
                window.location.href = "/admin/index.html";
            });
        }

        let sending = false;

        form.addEventListener("submit", async function (ev) {
            ev.preventDefault();
            if (sending) return;

            if (statusEl) {
                statusEl.textContent = "";
                statusEl.classList.remove("error", "success");
            }

            if (!form.checkValidity()) {
                form.reportValidity();
                return;
            }

            const senha = form.senha.value;
            const confirmacao = form.confirmar_senha.value;

            if (senha !== confirmacao) {
                if (statusEl) {
                    statusEl.textContent = "As senhas não conferem. Por favor, verifique.";
                    statusEl.classList.add("error");
                } else {
                    alert("As senhas não conferem.");
                }
                return;
            }

            const token = getToken();
            if (!token) {
                window.location.replace("/index.html");
                return;
            }

            const submitBtn = form.querySelector('button[type="submit"]');
            const originalLabel = submitBtn ? submitBtn.textContent : "";
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.textContent = "Salvando...";
            }

            sending = true;

            try {
                const payload = {
                    nome_completo: form.nome_completo.value.trim(),
                    email: form.email.value.trim(),
                    username: form.username.value.trim(),
                    senha: senha
                };

                const resp = await fetch(WEBHOOK_URL, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer " + token
                    },
                    body: JSON.stringify(payload)
                });

                const text = await resp.text();
                let data = null;
                try { data = text ? JSON.parse(text) : null; } catch (_) { }

                if (!resp.ok || !data || data.ok !== true) {
                    const msg =
                        (data && (data.message || data.error || data.detail)) ||
                        "Erro ao criar administrador.";
                    if (statusEl) {
                        statusEl.textContent = msg;
                        statusEl.classList.add("error");
                    } else {
                        alert(msg);
                    }
                    return;
                }

                if (statusEl) {
                    statusEl.textContent = "Administrador criado com sucesso.";
                    statusEl.classList.add("success");
                } else {
                    alert("Administrador criado com sucesso.");
                }

                form.reset();
            } catch (e) {
                if (statusEl) {
                    statusEl.textContent = "Erro inesperado ao salvar administrador.";
                    statusEl.classList.add("error");
                } else {
                    alert("Erro inesperado ao salvar administrador.");
                }
            } finally {
                sending = false;
                if (submitBtn) {
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalLabel || "Salvar";
                }
            }
        });
    }

    async function bootstrap() {
        const ok = await ensureDouglasOnly();
        if (!ok) return;
        initForm();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", bootstrap);
    } else {
        bootstrap();
    }
})();