(function () {
    const form = document.getElementById("form-novo-operador");
    const btnVoltar = document.getElementById("btn-voltar");
    const inputFile = document.getElementById("foto");
    const btnFile = document.getElementById("btn-foto");
    const fileName = document.getElementById("foto-nome");
    const preview = document.getElementById("foto-preview");

    // Certifique-se que AppConfig está carregado antes deste script
    const WEBHOOK_URL = AppConfig.apiUrl(AppConfig.endpoints.admin.novoOperador);

    function getAuthToken() {
        try {
            if (window.Auth && typeof window.Auth.loadToken === "function") {
                return window.Auth.loadToken();
            }
        } catch (e) { }
        return (
            localStorage.getItem("auth_token") ||
            localStorage.getItem("token") ||
            localStorage.getItem("jwt") ||
            ""
        );
    }

    if (btnVoltar) {
        btnVoltar.addEventListener("click", function () {
            window.location.href = "/admin/index.html";
        });
    }

    if (btnFile) {
        btnFile.addEventListener("click", function () {
            inputFile.click();
        });
    }

    if (inputFile) {
        inputFile.addEventListener("change", function () {
            if (!inputFile.files || !inputFile.files[0]) {
                fileName.textContent = "Nenhum arquivo selecionado";
                preview.style.display = "none";
                preview.src = "";
                return;
            }
            const f = inputFile.files[0];
            fileName.textContent = f.name + " (" + Math.round(f.size / 1024) + " KB)";
            try {
                const url = URL.createObjectURL(f);
                preview.src = url;
                preview.style.display = "inline-block";
            } catch (_) { }
        });
    }

    if (form) {
        form.addEventListener("submit", async function (ev) {
            ev.preventDefault();

            // Validação HTML5
            if (!form.checkValidity()) {
                form.reportValidity();
                return;
            }

            // Agora seguro: os IDs existem no HTML
            const emailInput = document.getElementById("email");
            const usernameInput = document.getElementById("username");
            const senhaInput = document.getElementById("senha");
            const confirmacaoInput = document.getElementById("confirmar_senha");

            // Prevenção extra caso algum ID seja alterado no futuro
            if (!emailInput || !usernameInput || !senhaInput || !confirmacaoInput) {
                alert("Erro interno: Elementos do formulário não encontrados.");
                console.error("IDs obrigatórios faltando no DOM.");
                return;
            }

            const email = emailInput.value.trim();
            const username = usernameInput.value.trim();
            const senha = senhaInput.value;
            const confirmacao = confirmacaoInput.value;

            // Regras básicas extras
            if (senha.length < 6) {
                alert("A senha precisa ter pelo menos 6 caracteres.");
                return;
            }
            if (senha !== confirmacao) {
                alert("As senhas não conferem. Por favor, verifique.");
                return;
            }
            if (!/^[a-z0-9._-]{3,}$/i.test(username)) {
                alert("Nome de usuário inválido. Use letras, números, ponto, traço ou sublinhado (mín. 3).");
                return;
            }

            // Monta FormData
            const formData = new FormData(form);
            formData.delete("confirmar_senha"); // Remove campo desnecessário

            // Garante que estamos enviando os valores 'trimados'
            formData.set("email", email);
            formData.set("username", username);

            const submitBtn = form.querySelector('button[type="submit"]');
            const oldLabel = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.textContent = "Salvando...";

            try {
                const token = getAuthToken();

                const res = await fetch(WEBHOOK_URL, {
                    method: "POST",
                    headers: token ? { "Authorization": "Bearer " + token } : {},
                    body: formData
                });

                if (res.status === 401 || res.status === 403) {
                    alert("Sua sessão expirou ou você não tem permissão para esta operação.");
                    window.location.href = "/index.html";
                    return;
                }

                if (res.status === 400) {
                    const data = await safeJson(res);
                    alert("Dados inválidos: " + (data?.missing || "verifique os campos obrigatórios."));
                    return;
                }

                if (res.status === 409) {
                    const data = await safeJson(res);
                    alert(data?.message || "E-mail ou usuário já cadastrado.");
                    return;
                }

                if (!res.ok) {
                    const text = await res.text();
                    alert("Falha ao salvar (HTTP " + res.status + "): " + text);
                    return;
                }

                const data = await safeJson(res);
                const id = data?.operador?.id || "(sem ID)";
                alert("Operador cadastrado com sucesso! ID: " + id);

                window.location.href = "/admin/index.html";

            } catch (err) {
                console.error(err);
                alert("Erro de rede ou CORS ao comunicar com o servidor.");
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = oldLabel;
            }
        });
    }

    async function safeJson(res) {
        try { return await res.json(); } catch { return null; }
    }
})();