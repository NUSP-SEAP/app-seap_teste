(function () {
    "use strict";

    // Pega o ID da URL
    const params = new URLSearchParams(window.location.search);
    const entradaId = params.get("entrada_id");

    if (!entradaId) {
        alert("ID de entrada não fornecido.");
        window.close();
        return;
    }

    // Helper simples para setar valor em inputs
    const setVal = (id, val) => {
        const el = document.getElementById(id);
        if (el) el.value = val || "";
    };

    const setRadio = (name, val) => {
        if (val === undefined || val === null) return;

        // Normaliza para string
        let normalized = String(val).toLowerCase().trim();

        // Tratamento especial para campos sim/nao (pode vir bool, 't', 'f', 'sim', 'nao', 0/1)
        if (name === "houve_anormalidade" || name === "evento_encerrado") {
            if (
                normalized === "true" ||
                normalized === "t" ||
                normalized === "1" ||
                normalized === "sim" ||
                normalized === "s"
            ) {
                normalized = "sim";
            } else {
                normalized = "nao";
            }
        }

        // Primeiro tenta marcar radios reais (nosso caso atual)
        const radios = document.querySelectorAll(`input[name="${name}"]`);
        if (radios && radios.length) {
            radios.forEach((radio) => {
                radio.checked =
                    String(radio.value).toLowerCase().trim() === normalized;
            });
        }

        // Compat: se houver um campo *_display em outra tela, continua preenchendo
        const display = document.getElementById(name + "_display");
        if (display) {
            let text = normalized;

            if (name === "houve_anormalidade") {
                text = normalized === "sim" ? "Sim" : "Não";
            }

            if (name === "tipo_evento") {
                const v = String(val).toLowerCase();
                if (v === "operacao") text = "Operação Comum";
                else if (v === "cessao") text = "Cessão de Sala";
                else if (v === "outros") text = "Outros Eventos";
                else text = val;
            }

            display.value = text;
        }
    };

    async function loadData() {
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.adminDashboard.detalheOperacao)}?entrada_id=${entradaId}`;

        // Reusa authFetch do sistema
        if (!window.Auth || typeof Auth.authFetch !== "function") {
            console.error("Auth não carregado");
            return;
        }

        try {
            const resp = await Auth.authFetch(url);
            if (!resp.ok) throw new Error("Erro HTTP " + resp.status);

            const json = await resp.json();
            if (!json.ok || !json.data) {
                throw new Error("Registro não encontrado.");
            }

            const d = json.data;

            // Cabeçalho (nº da entrada)
            const displayIdEl = document.getElementById("display-id");
            if (displayIdEl) {
                displayIdEl.textContent = d.entrada_id || entradaId;
            }

            // Local
            setVal("sala_nome", d.sala_nome || d.sala_id || "");

            // Atividade Legislativa (usa o nome da comissão; se não tiver, fica vazio mesmo)
            setVal("atividade_legislativa", d.comissao_nome || "");

            // Descrição + Responsável
            setVal("nome_evento", d.nome_evento || "");
            setVal("responsavel_evento", d.responsavel_evento || "");

            // Datas / horários
            setVal("data_operacao", d.data_operacao || "");
            setVal(
                "horario_pauta",
                d.horario_pauta ? String(d.horario_pauta).substring(0, 5) : ""
            );
            setVal(
                "hora_inicio",
                d.hora_inicio ? String(d.hora_inicio).substring(0, 5) : ""
            );
            setVal(
                "hora_fim",
                d.hora_fim ? String(d.hora_fim).substring(0, 5) : ""
            );

            // Evento encerrado (derivado da presença de hora_fim, igual ao form do operador)
            setRadio("evento_encerrado", d.hora_fim ? "sim" : "nao");

            // Horários da operação
            setVal(
                "hora_entrada",
                d.hora_entrada ? String(d.hora_entrada).substring(0, 5) : ""
            );
            setVal(
                "hora_saida",
                d.hora_saida ? String(d.hora_saida).substring(0, 5) : ""
            );

            // Trilhas e observações
            setVal("usb_01", d.usb_01 || "");
            setVal("usb_02", d.usb_02 || "");
            setVal("observacoes", d.observacoes || "");

            // Operador responsável (campo extra do admin)
            setVal("operador_nome", d.operador_nome || "");

            // Houve anormalidade? → marca radio Sim/Não
            setRadio("houve_anormalidade", d.houve_anormalidade);
        } catch (e) {
            console.error("Erro ao carregar detalhe da operação:", e);
            alert("Erro ao carregar detalhes da operação: " + e.message);
            window.close();
        }
    }

    document.addEventListener("DOMContentLoaded", loadData);
})();