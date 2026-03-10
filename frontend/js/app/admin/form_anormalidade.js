(function () {
    "use strict";

    const params = new URLSearchParams(window.location.search);
    const id = params.get("id");

    // Estado atual em memória (registro + usuário logado)
    let currentData = null;
    let currentUser = null;

    if (!id) {
        alert("ID não fornecido.");
        window.close();
        return;
    }

    // Formata Data YYYY-MM-DD -> DD/MM/YYYY
    const fmtDate = (d) => {
        if (!d) return "";
        const parts = d.split('-');
        return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : d;
    };

    // Helper para preencher inputs
    const setVal = (eid, val) => {
        const el = document.getElementById(eid);
        if (el) el.value = val || "";
    };

    // Helper para lógica booleana e exibição condicional
    // Por padrão: Sim = vermelho, Não = verde (usado para campos de "problema").
    // Para campos "positivos" (ex.: resolvida pelo operador), podemos sobrescrever as cores via options.
    const handleBool = (dataVal, displayId, groupIds = [], options = {}) => {
        const el = document.getElementById(displayId);
        const isTrue = !!dataVal; // converte para bool real

        const simColor = options.simColor || "#b91c1c"; // padrão: vermelho
        const naoColor = options.naoColor || "#15803d"; // padrão: verde

        if (el) {
            el.value = isTrue ? "Sim" : "Não";
            el.style.color = isTrue ? simColor : naoColor;
            el.style.fontWeight = "bold";
        }

        // Mostra/Esconde grupos dependentes
        groupIds.forEach(gid => {
            const grp = document.getElementById(gid);
            if (grp) {
                if (isTrue) grp.classList.remove("hidden");
                else grp.classList.add("hidden");
            }
        });
    };

    // Configura os campos "Observações do Supervisor" e "Observações do Chefe de Serviço"
    function setupObservacoes() {
        const d = currentData;
        const me = currentUser;

        const txtSup = document.getElementById("observacao_supervisor");
        const txtChefe = document.getElementById("observacao_chefe");
        const acoesSup = document.getElementById("acoes-observacao-supervisor");
        const acoesChefe = document.getElementById("acoes-observacao-chefe");

        if (!d) return;
        if (!txtSup || !txtChefe) return;
        if (!acoesSup || !acoesChefe) return;

        const valorSup = (d.observacao_supervisor || "").trim();
        const valorChefe = (d.observacao_chefe || "").trim();

        const user = (me && me.user) ? me.user : {};
        const username = (user.username || "").toLowerCase();
        const email = (user.email || "").toLowerCase();

        const isSupervisor = username === "emanoel" && email === "emanoel@senado.leg.br";
        const isChefe = username === "evandrop" && email === "evandrop@senado.leg.br";

        const supervisorJaPreencheu = !!valorSup;
        const chefeJaPreencheu = !!valorChefe;

        const podeEditarSup = isSupervisor && !supervisorJaPreencheu;
        const podeEditarChefe = isChefe && !chefeJaPreencheu;

        // Supervisor
        txtSup.value = valorSup;
        txtSup.readOnly = !podeEditarSup;
        txtSup.classList.toggle("admin-editavel", podeEditarSup);
        acoesSup.style.display = podeEditarSup ? "flex" : "none";

        // Chefe de Serviço
        txtChefe.value = valorChefe;
        txtChefe.readOnly = !podeEditarChefe;
        txtChefe.classList.toggle("admin-editavel", podeEditarChefe);
        acoesChefe.style.display = podeEditarChefe ? "flex" : "none";
    }

    async function salvarObservacao(tipo) {
        if (!currentData) {
            alert("Dados ainda não foram carregados.");
            return;
        }
        if (!window.Auth || typeof Auth.authFetch !== "function") {
            alert("Sessão não encontrada.");
            return;
        }

        const isSupervisor = (tipo === "supervisor");
        const textareaId = isSupervisor ? "observacao_supervisor" : "observacao_chefe";
        const txt = document.getElementById(textareaId);
        if (!txt) return;

        const texto = (txt.value || "").trim();
        if (!texto) {
            alert("Preencha a observação antes de salvar.");
            return;
        }

        const endpointKey = isSupervisor
            ? AppConfig.endpoints.adminDashboard.anormalidades.observacaoSupervisor
            : AppConfig.endpoints.adminDashboard.anormalidades.observacaoChefe;

        const url = AppConfig.apiUrl(endpointKey);

        try {
            const resp = await Auth.authFetch(url, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ id, observacao: texto })
            });

            const json = await resp.json().catch(() => null);
            if (!resp.ok || !json || !json.ok) {
                const msg = json && (json.message || json.error) || `Erro HTTP ${resp.status}`;
                alert("Não foi possível salvar a observação: " + msg);
                return;
            }

            if (isSupervisor) {
                currentData.observacao_supervisor = texto;
            } else {
                currentData.observacao_chefe = texto;
            }

            alert("Observação salva com sucesso.");
            setupObservacoes();
        } catch (e) {
            alert("Erro ao salvar observação: " + e.message);
        }
    }

    function cancelarObservacao(tipo) {
        if (!currentData) return;

        const isSupervisor = (tipo === "supervisor");
        const textareaId = isSupervisor ? "observacao_supervisor" : "observacao_chefe";
        const txt = document.getElementById(textareaId);
        if (!txt) return;

        const original = isSupervisor
            ? (currentData.observacao_supervisor || "")
            : (currentData.observacao_chefe || "");

        txt.value = original;
    }

    async function loadData() {
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.adminDashboard.anormalidades.detalhe)}?id=${id}`;

        if (!window.Auth || typeof Auth.authFetch !== "function") return;

        try {
            // Descobre usuário logado (para as regras de Supervisor/Chefe de Serviço)
            if (typeof Auth.whoAmI === "function") {
                try {
                    currentUser = await Auth.whoAmI({ allowCached: true });
                } catch (errWho) {
                    console.warn("Falha ao consultar whoAmI:", errWho);
                    currentUser = null;
                }
            }

            const resp = await Auth.authFetch(url);
            if (!resp.ok) throw new Error("Erro HTTP " + resp.status);
            const json = await resp.json();

            if (!json.ok || !json.data) throw new Error("Registro não encontrado");

            const d = json.data;
            currentData = d;

            // Header
            document.getElementById("display-id").textContent = d.id;
            setVal("data", fmtDate(d.data));
            setVal("sala_nome", d.sala_nome);
            setVal("nome_evento", d.nome_evento);

            // Detalhes
            setVal("hora_inicio_anormalidade", (d.hora_inicio_anormalidade || "").substring(0, 5));
            setVal("descricao_anormalidade", d.descricao_anormalidade);

            // Solução (Lógica invertida de cor: Sim é verde)
            const elSol = document.getElementById("foi_solucionada");
            const temSolucao = !!d.data_solucao;
            if (elSol) {
                elSol.value = temSolucao ? "Sim" : "Não";
                elSol.style.color = temSolucao ? "#15803d" : "#b91c1c";
                elSol.style.fontWeight = "bold";
            }
            if (temSolucao) {
                const grpSol = document.getElementById("grp_solucao");
                if (grpSol) grpSol.classList.remove("hidden");
                const dt = fmtDate(d.data_solucao);
                const hr = (d.hora_solucao || "").substring(0, 5);
                setVal("data_hora_solucao", `${dt} às ${hr}`);
            }

            // Condicionais de Impacto (Sim = vermelho, Não = verde)
            handleBool(d.houve_prejuizo, "houve_prejuizo", ["grp_prejuizo"]);
            setVal("descricao_prejuizo", d.descricao_prejuizo);

            handleBool(d.houve_reclamacao, "houve_reclamacao", ["grp_reclamacao"]);
            setVal("autores_conteudo_reclamacao", d.autores_conteudo_reclamacao);

            handleBool(d.acionou_manutencao, "acionou_manutencao", ["grp_manutencao"]);
            setVal("hora_acionamento_manutencao", (d.hora_acionamento_manutencao || "").substring(0, 5));

            // Aqui a regra é invertida: Sim = verde (bom, operador resolveu), Não = vermelho
            handleBool(
                d.resolvida_pelo_operador,
                "resolvida_pelo_operador",
                ["grp_procedimentos"],
                { simColor: "#15803d", naoColor: "#b91c1c" }
            );
            setVal("procedimentos_adotados", d.procedimentos_adotados);

            // Responsáveis
            setVal("registrado_por", d.registrado_por || "Sistema");
            setVal("responsavel_evento", d.responsavel_evento);

            // Observações administrativas (Supervisor / Chefe de Serviço)
            setupObservacoes();
        } catch (e) {
            alert("Erro ao carregar: " + e.message);
            window.close();
        }
    }

    document.addEventListener("DOMContentLoaded", () => {
        const btnSupSalvar = document.getElementById("btn-supervisor-salvar");
        const btnSupCancelar = document.getElementById("btn-supervisor-cancelar");
        const btnChefeSalvar = document.getElementById("btn-chefe-salvar");
        const btnChefeCancelar = document.getElementById("btn-chefe-cancelar");

        if (btnSupSalvar) {
            btnSupSalvar.addEventListener("click", () => salvarObservacao("supervisor"));
        }
        if (btnSupCancelar) {
            btnSupCancelar.addEventListener("click", () => cancelarObservacao("supervisor"));
        }
        if (btnChefeSalvar) {
            btnChefeSalvar.addEventListener("click", () => salvarObservacao("chefe"));
        }
        if (btnChefeCancelar) {
            btnChefeCancelar.addEventListener("click", () => cancelarObservacao("chefe"));
        }

        loadData();
    });
})();