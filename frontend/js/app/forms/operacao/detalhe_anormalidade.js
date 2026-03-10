(function () {
    "use strict";

    const params = new URLSearchParams(window.location.search);
    const id = params.get("id");

    if (!id) {
        alert("ID não fornecido.");
        window.close();
        return;
    }

    const fmtDate = (d) => {
        if (!d) return "";
        const parts = d.split('-');
        return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : d;
    };

    const setVal = (eid, val) => {
        const el = document.getElementById(eid);
        if (el) el.value = val || "";
    };

    const handleBool = (dataVal, displayId, groupIds = [], options = {}) => {
        const el = document.getElementById(displayId);
        const isTrue = !!dataVal;

        const simColor = options.simColor || "#b91c1c";
        const naoColor = options.naoColor || "#15803d";

        if (el) {
            el.value = isTrue ? "Sim" : "Não";
            el.style.color = isTrue ? simColor : naoColor;
            el.style.fontWeight = "bold";
        }

        groupIds.forEach(gid => {
            const grp = document.getElementById(gid);
            if (grp) {
                if (isTrue) grp.classList.remove("hidden");
                else grp.classList.add("hidden");
            }
        });
    };

    async function loadData() {
        // Usa o endpoint do operador (não do admin)
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.operadorDashboard.detalheAnormalidade)}?id=${id}`;

        if (!window.Auth || typeof Auth.authFetch !== "function") return;

        try {
            const resp = await Auth.authFetch(url);
            if (!resp.ok) throw new Error("Erro HTTP " + resp.status);
            const json = await resp.json();

            if (!json.ok || !json.data) throw new Error("Registro não encontrado");

            const d = json.data;

            // Referência ao registro
            setVal("data", fmtDate(d.data));
            setVal("sala_nome", d.sala_nome);
            setVal("nome_evento", d.nome_evento);

            // Detalhes
            setVal("hora_inicio_anormalidade", (d.hora_inicio_anormalidade || "").substring(0, 5));
            setVal("descricao_anormalidade", d.descricao_anormalidade);

            // Condicionais de Impacto
            handleBool(d.houve_prejuizo, "houve_prejuizo", ["grp_prejuizo"]);
            setVal("descricao_prejuizo", d.descricao_prejuizo);

            handleBool(d.houve_reclamacao, "houve_reclamacao", ["grp_reclamacao"]);
            setVal("autores_conteudo_reclamacao", d.autores_conteudo_reclamacao);

            handleBool(d.acionou_manutencao, "acionou_manutencao", ["grp_manutencao"]);
            setVal("hora_acionamento_manutencao", (d.hora_acionamento_manutencao || "").substring(0, 5));

            handleBool(
                d.resolvida_pelo_operador,
                "resolvida_pelo_operador",
                ["grp_procedimentos"],
                { simColor: "#15803d", naoColor: "#b91c1c" }
            );
            setVal("procedimentos_adotados", d.procedimentos_adotados);

            // Responsáveis
            setVal("responsavel_evento", d.responsavel_evento);

            // Observações administrativas (sempre read-only para operador)
            setVal("observacao_supervisor", d.observacao_supervisor || "");
            setVal("observacao_chefe", d.observacao_chefe || "");
        } catch (e) {
            alert("Erro ao carregar: " + e.message);
            window.close();
        }
    }

    document.addEventListener("DOMContentLoaded", loadData);
})();
