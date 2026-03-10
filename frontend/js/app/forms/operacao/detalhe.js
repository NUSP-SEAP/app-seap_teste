(function () {
    "use strict";

    // ====== Parâmetro da URL ======
    const params = new URLSearchParams(window.location.search);
    const entradaId = params.get("entrada_id");

    if (!entradaId) {
        alert("ID de entrada não fornecido.");
        window.close();
        return;
    }

    // ====== Estado centralizado ======
    const state = {
        editMode: false,
        originalData: null,           // dados completos da API
        originalAnormalidade: false,   // valor original de houve_anormalidade (bool)
        originalEventoEncerrado: true,  // derivado: true se hora_fim tinha valor
        comissoesLoaded: false,
        salasLoaded: false,
        salaExigeComissao: false,      // se a sala requer dropdown de comissão
        totalEntradas: 0,              // quantos operadores na sessão (1 = permite editar Local/hora_fim)
        _syncHoraInicio: null,         // listener removível para input hora_inicio
        _syncHoraFim: null,            // listener removível para input hora_fim
    };

    // ====== Helpers ======
    const $ = (id) => document.getElementById(id);

    const setVal = (id, val) => {
        const el = $(id);
        if (el) el.value = val || "";
    };

    const setRadio = (name, val) => {
        if (val === undefined || val === null) return;
        let normalized = String(val).toLowerCase().trim();

        if (name === "houve_anormalidade") {
            if (["true", "t", "1", "sim", "s"].includes(normalized)) {
                normalized = "sim";
            } else {
                normalized = "nao";
            }
        }

        const radios = document.querySelectorAll(`input[name="${name}"]`);
        radios.forEach((radio) => {
            radio.checked = String(radio.value).toLowerCase().trim() === normalized;
        });
    };

    /**
     * Determina se a sala exige comissão (dropdown).
     * Mesma regex do formulário de criação (ui.js):
     * - "Auditório" (qualquer) → NÃO exige
     * - "Plenário" sem número → NÃO exige
     * - "Plenário 1", "Plenário 2", etc. (numerados) → EXIGE
     * - Qualquer outra sala → EXIGE
     */
    function determineSalaExigeComissao(salaName) {
        if (!salaName) return false;
        const lower = salaName.toLowerCase();
        const isAuditorio = /audit[oó]rio/.test(lower);
        const isPlenario = /plen[áa]rio(?!\s*\d)/.test(lower);
        return !isAuditorio && !isPlenario;
    }

    // ====== Carregar dados (readonly) ======
    async function loadData() {
        const url = `${AppConfig.apiUrl(AppConfig.endpoints.operadorDashboard.detalheOperacao)}?entrada_id=${entradaId}`;

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
            state.originalData = d;

            // Normaliza houve_anormalidade para boolean
            const ha = d.houve_anormalidade;
            state.originalAnormalidade = (ha === true || ha === "true" || ha === "t" || ha === "sim" || ha === "s" || ha === 1 || ha === "1");

            // Determina se a sala exige comissão
            state.salaExigeComissao = determineSalaExigeComissao(d.sala_nome);

            // Total de entradas na sessão (controla edição de Local e hora_fim)
            state.totalEntradas = parseInt(d.total_entradas, 10) || 0;

            // Mostra/esconde a seção "Atividade Legislativa" conforme a sala
            const divAtividade = document.getElementById("div-atividade-legislativa");
            if (divAtividade) {
                if (state.salaExigeComissao) {
                    divAtividade.classList.remove("hidden");
                } else {
                    divAtividade.classList.add("hidden");
                }
            }

            // Preenche campos readonly
            setVal("sala_nome", d.sala_nome || d.sala_id || "");
            setVal("atividade_legislativa", d.comissao_nome || "");
            setVal("nome_evento", d.nome_evento || "");
            setVal("responsavel_evento", d.responsavel_evento || "");
            setVal("data_operacao", d.data_operacao || "");
            setVal("horario_pauta", d.horario_pauta ? String(d.horario_pauta).substring(0, 5) : "");
            setVal("hora_inicio", d.hora_inicio ? String(d.hora_inicio).substring(0, 5) : "");
            setVal("hora_fim", d.hora_fim ? String(d.hora_fim).substring(0, 5) : "");
            setVal("usb_01", d.usb_01 || "");
            setVal("usb_02", d.usb_02 || "");
            setVal("observacoes", d.observacoes || "");
            setRadio("houve_anormalidade", d.houve_anormalidade);

            // Novos campos
            setVal("hora_entrada", d.hora_entrada ? String(d.hora_entrada).substring(0, 5) : "");
            setVal("hora_saida", d.hora_saida ? String(d.hora_saida).substring(0, 5) : "");
            const encerradoDerivado = !!(d.hora_fim);
            state.originalEventoEncerrado = encerradoDerivado;
            setRadio("evento_encerrado", encerradoDerivado ? "sim" : "nao");

            // Badges de edição
            renderEditadoBadgeHeader(d.editado);
            renderFieldBadges(d);

        } catch (e) {
            console.error("Erro ao carregar detalhe da operação:", e);
            alert("Erro ao carregar detalhes da operação: " + e.message);
        }
    }

    // ====== Badges "editado" ======

    /**
     * Mapeamento: chave = nome do campo _editado retornado pela API,
     * valor = seletor CSS do elemento onde o badge será inserido.
     * - label[for="X"] para campos com <label>
     * - #id para section-titles com id
     */
    const FIELD_BADGE_MAP = {
        sala_editado:               'label[for="sala_nome"]',
        nome_evento_editado:        'label[for="nome_evento"]',
        responsavel_evento_editado: 'label[for="responsavel_evento"]',
        comissao_editado:           'label[for="atividade_legislativa"]',
        horario_pauta_editado:      'label[for="horario_pauta"]',
        horario_inicio_editado:     'label[for="hora_inicio"]',
        horario_termino_editado:    'label[for="hora_fim"]',
        usb_01_editado:             '#section-title-usb01',
        usb_02_editado:             '#section-title-usb02',
        observacoes_editado:        '#section-title-obs',
        hora_entrada_editado:       'label[for="hora_entrada"]',
        hora_saida_editado:         'label[for="hora_saida"]',
    };

    function renderEditadoBadgeHeader(editado) {
        const old = document.querySelector('.header-edited-badge');
        if (old) old.remove();

        if (editado) {
            const badge = document.createElement('span');
            badge.className = 'edited-badge header-edited-badge';
            badge.textContent = 'editado';
            badge.style.marginLeft = '12px';
            const h1 = document.querySelector('h1');
            if (h1) h1.appendChild(badge);
        }
    }

    function renderFieldBadges(data) {
        // Remove badges anteriores de campos
        document.querySelectorAll('.field-edited-badge').forEach(el => el.remove());

        for (const [field, selector] of Object.entries(FIELD_BADGE_MAP)) {
            if (data[field]) {
                const target = document.querySelector(selector);
                if (target) {
                    const badge = document.createElement('span');
                    badge.className = 'edited-badge field-edited-badge';
                    badge.textContent = 'editado';
                    target.appendChild(badge);
                }
            }
        }
    }

    // ====== Carregar comissões (para dropdown de edição) ======
    async function loadComissoes() {
        if (state.comissoesLoaded) return;

        const url = AppConfig.apiUrl(AppConfig.endpoints.lookups.comissoes);
        const sel = $("comissao_id_edit");

        try {
            let resp;
            if (window.Auth && Auth.authFetch) resp = await Auth.authFetch(url, { method: 'GET' });
            else resp = await fetch(url, { method: 'GET' });

            const json = await resp.json().catch(() => ({}));
            const rows = Array.isArray(json?.data) ? json.data : (Array.isArray(json) ? json : []);

            const opts = ['<option value="">Selecione...</option>'].concat(
                rows.map(r => `<option value="${r.id}">${r.nome}</option>`)
            ).join('');

            sel.innerHTML = opts;
            sel.disabled = false;
            state.comissoesLoaded = true;
        } catch (e) {
            console.error("Erro ao carregar comissões:", e);
            sel.innerHTML = '<option value="">Falha ao carregar</option>';
        }
    }

    // ====== Carregar salas (para dropdown de edição) ======
    async function loadSalas() {
        if (state.salasLoaded) return;

        const url = AppConfig.apiUrl(AppConfig.endpoints.lookups.salas);
        const sel = $("sala_id_edit");

        try {
            let resp;
            if (window.Auth && Auth.authFetch) resp = await Auth.authFetch(url, { method: 'GET' });
            else resp = await fetch(url, { method: 'GET' });

            const json = await resp.json().catch(() => ({}));
            const rows = Array.isArray(json?.data) ? json.data : (Array.isArray(json) ? json : []);

            const opts = ['<option value="">Selecione...</option>'].concat(
                rows.map(r => `<option value="${r.id}">${r.nome}</option>`)
            ).join('');

            sel.innerHTML = opts;
            sel.disabled = false;
            state.salasLoaded = true;
        } catch (e) {
            console.error("Erro ao carregar salas:", e);
            sel.innerHTML = '<option value="">Falha ao carregar</option>';
        }
    }

    // ====== Calcular tipo_evento ======
    function getTipoEvento() {
        const sel = $("comissao_id_edit");
        if (!sel || sel.classList.contains("hidden")) return state.originalData?.tipo_evento || "operacao";
        const val = sel.value;

        // Determina a sala atual (pode ter sido editada via dropdown)
        const salaEdit = $("sala_id_edit");
        let salaNome = state.originalData?.sala_nome || "";
        if (salaEdit && !salaEdit.classList.contains("hidden") && salaEdit.value) {
            salaNome = salaEdit.options[salaEdit.selectedIndex]?.text || salaNome;
        }
        const exigeComissao = determineSalaExigeComissao(salaNome);

        if (!val) {
            return exigeComissao ? "outros" : "operacao";
        }
        return "cessao";
    }

    // ====== Remover listeners de sincronização do modo edição ======
    function _removeEditListeners() {
        if (state._syncHoraInicio) {
            var elHI = $("hora_inicio");
            if (elHI) elHI.removeEventListener("input", state._syncHoraInicio);
            state._syncHoraInicio = null;
        }
        if (state._syncHoraFim) {
            var elHF = $("hora_fim");
            if (elHF) elHF.removeEventListener("input", state._syncHoraFim);
            state._syncHoraFim = null;
        }
    }

    // ====== Regras de UI em modo edição (Cancelado + Encerrado + horários da operação) ======
    function aplicarRegrasEditDetalhe() {
        if (!state.editMode) return;

        const radioEncerrado = document.querySelector('input[name="evento_encerrado"]:checked');
        const encerrado = radioEncerrado ? radioEncerrado.value === "sim" : false;

        const ordem = parseInt((state.originalData || {}).ordem, 10) || 1;
        const primeiroOperador = ordem === 1;

        const horaInicioEl  = $("hora_inicio");
        const horaFimEl     = $("hora_fim");
        const horaEntradaEl = $("hora_entrada");
        const horaSaidaEl   = $("hora_saida");
        const labelHoraFim  = document.querySelector('label[for="hora_fim"]');
        const radioAnorNao  = $("houve_anormalidade_nao");
        const radioAnorSim  = $("houve_anormalidade_sim");
        const anorNota      = $("anormalidade-nota");

        // hora_inicio: habilitado e obrigatório
        if (horaInicioEl) {
            horaInicioEl.disabled = false;
            horaInicioEl.readOnly = false;
            horaInicioEl.required = true;
        }

        // hora_entrada: readonly para primeiroOperador (espelha hora_inicio), editável para os demais
        if (horaEntradaEl) {
            if (primeiroOperador) {
                horaEntradaEl.disabled = false;
                horaEntradaEl.readOnly = true;
                horaEntradaEl.required = false;
                horaEntradaEl.value = horaInicioEl ? (horaInicioEl.value || "") : "";
            } else {
                horaEntradaEl.disabled = false;
                horaEntradaEl.readOnly = false;
                horaEntradaEl.required = true;
            }
        }

        // hora_fim e hora_saida dependem do Evento Encerrado
        if (encerrado) {
            if (horaFimEl) {
                horaFimEl.disabled = false;
                horaFimEl.readOnly = false;
                horaFimEl.required = true;
                if (labelHoraFim) labelHoraFim.classList.add("required");
            }
            // hora_saida: readonly, espelha hora_fim
            if (horaSaidaEl) {
                horaSaidaEl.disabled = false;
                horaSaidaEl.readOnly = true;
                horaSaidaEl.required = false;
                horaSaidaEl.value = horaFimEl ? (horaFimEl.value || "") : "";
            }
        } else {
            // Evento não encerrado: hora_fim desabilitado
            if (horaFimEl) {
                horaFimEl.disabled = true;
                horaFimEl.readOnly = false;
                horaFimEl.required = false;
                horaFimEl.value = "";
                if (labelHoraFim) labelHoraFim.classList.remove("required");
            }
            // hora_saida: editável e obrigatório
            if (horaSaidaEl) {
                horaSaidaEl.disabled = false;
                horaSaidaEl.readOnly = false;
                horaSaidaEl.required = true;
            }
        }

        // Houve Anormalidade
        if (state.originalAnormalidade) {
            if (radioAnorNao) radioAnorNao.disabled = true;
            if (radioAnorSim) radioAnorSim.disabled = true;
        } else {
            if (radioAnorNao) radioAnorNao.disabled = false;
            if (radioAnorSim) radioAnorSim.disabled = false;
            if (anorNota) anorNota.classList.remove("hidden");
        }
    }

    // ====== Entrar em modo de edição ======
    async function enterEditMode() {
        state.editMode = true;
        const d = state.originalData;
        const form = $("form-roa-readonly");
        form.classList.add("editing");

        // Local: sempre readonly (não editável)

        // Atividade Legislativa: editável via dropdown apenas para salas que exigem
        if (state.salaExigeComissao) {
            $("atividade_legislativa").classList.add("hidden");
            const comEdit = $("comissao_id_edit");
            comEdit.classList.remove("hidden");
            await loadComissoes();
            if (d.comissao_id) comEdit.value = String(d.comissao_id);
        }

        // Descrição do Evento: desbloqueia
        $("nome_evento").removeAttribute("readonly");

        // Responsável pelo Evento: desbloqueia
        $("responsavel_evento").removeAttribute("readonly");

        // Horário da Pauta: desbloqueia
        $("horario_pauta").removeAttribute("readonly");

        // Trilhas: desbloqueia (aplicarRegrasEditDetalhe pode reabilitar/desabilitar conforme cancelado)
        $("usb_01").removeAttribute("readonly");
        $("usb_02").removeAttribute("readonly");

        // Observações: desbloqueia
        $("observacoes").removeAttribute("readonly");

        // Evento Encerrado: sempre bloqueado (não pode ser alterado)
        // (já está disabled no HTML — não faz nada aqui)

        // Listeners de sincronização
        state._syncHoraInicio = function () { aplicarRegrasEditDetalhe(); };
        var hiEl = $("hora_inicio");
        if (hiEl) hiEl.addEventListener("input", state._syncHoraInicio);

        state._syncHoraFim = function () { aplicarRegrasEditDetalhe(); };
        var hfEl = $("hora_fim");
        if (hfEl) hfEl.addEventListener("input", state._syncHoraFim);

        // Aplica regras iniciais (hora_inicio, hora_fim, hora_entrada, hora_saida, anormalidade)
        aplicarRegrasEditDetalhe();

        // Botões
        $("btn-editar").classList.add("hidden");
        $("btn-salvar").classList.remove("hidden");
        $("btn-cancelar").classList.remove("hidden");
    }

    // ====== Sair do modo de edição (cancelar) ======
    function exitEditMode() {
        state.editMode = false;
        const d = state.originalData;
        const form = $("form-roa-readonly");
        form.classList.remove("editing");

        // Local: restaura texto, esconde dropdown
        $("sala_nome").classList.remove("hidden");
        $("sala_id_edit").classList.add("hidden");
        $("sala_id_edit").onchange = null;

        // Atividade Legislativa: restaura visibilidade conforme a sala original
        const divAtividade = document.getElementById("div-atividade-legislativa");
        if (divAtividade) {
            if (state.salaExigeComissao) {
                divAtividade.classList.remove("hidden");
                $("atividade_legislativa").classList.remove("hidden");
            } else {
                divAtividade.classList.add("hidden");
            }
        }
        $("comissao_id_edit").classList.add("hidden");

        // Remove disabled de campos que podem ter sido desabilitados pelo cancelado
        ["hora_inicio", "hora_fim", "hora_entrada", "hora_saida", "usb_01", "usb_02"].forEach(function (id) {
            var el = $(id);
            if (el) el.disabled = false;
        });

        // Restaura readonly em todos os campos editáveis
        $("nome_evento").setAttribute("readonly", "");
        $("responsavel_evento").setAttribute("readonly", "");
        $("horario_pauta").setAttribute("readonly", "");
        $("hora_inicio").setAttribute("readonly", "");
        $("hora_fim").setAttribute("readonly", "");
        $("hora_entrada").setAttribute("readonly", "");
        $("hora_saida").setAttribute("readonly", "");
        $("usb_01").setAttribute("readonly", "");
        $("usb_02").setAttribute("readonly", "");
        $("observacoes").setAttribute("readonly", "");

        // Restaura valores originais
        setVal("sala_nome", d.sala_nome || d.sala_id || "");
        setVal("nome_evento", d.nome_evento || "");
        setVal("responsavel_evento", d.responsavel_evento || "");
        setVal("horario_pauta", d.horario_pauta ? String(d.horario_pauta).substring(0, 5) : "");
        setVal("hora_inicio", d.hora_inicio ? String(d.hora_inicio).substring(0, 5) : "");
        setVal("hora_fim", d.hora_fim ? String(d.hora_fim).substring(0, 5) : "");
        setVal("hora_entrada", d.hora_entrada ? String(d.hora_entrada).substring(0, 5) : "");
        setVal("hora_saida", d.hora_saida ? String(d.hora_saida).substring(0, 5) : "");
        setVal("usb_01", d.usb_01 || "");
        setVal("usb_02", d.usb_02 || "");
        setVal("observacoes", d.observacoes || "");

        // Restaura radio de encerrado e desabilita
        setRadio("evento_encerrado", state.originalEventoEncerrado ? "sim" : "nao");
        document.querySelectorAll('input[name="evento_encerrado"]').forEach(function (r) { r.disabled = true; });

        // Remove listeners de sincronização
        _removeEditListeners();

        // Limpa classe "required" do label hora_fim (pode ter sido adicionada)
        var labelHoraFim = document.querySelector('label[for="hora_fim"]');
        if (labelHoraFim) labelHoraFim.classList.remove("required");

        // Houve anormalidade: restaura e desabilita
        setRadio("houve_anormalidade", d.houve_anormalidade);
        $("houve_anormalidade_nao").disabled = true;
        $("houve_anormalidade_sim").disabled = true;
        $("anormalidade-nota").classList.add("hidden");

        // Botões
        $("btn-editar").classList.remove("hidden");
        $("btn-salvar").classList.add("hidden");
        $("btn-cancelar").classList.add("hidden");
    }

    // ====== Coletar dados editados ======
    function collectEditData() {
        const comissaoSel = $("comissao_id_edit");
        // Se o dropdown de comissão está visível, usa o valor selecionado.
        // Se está oculto (sala não exige comissão), envia null para limpar no banco.
        const comissaoId = (comissaoSel && !comissaoSel.classList.contains("hidden"))
            ? comissaoSel.value || null
            : null;

        // Houve anormalidade
        const radioSim = $("houve_anormalidade_sim");
        const houveAnormalidade = radioSim.checked ? "sim" : "nao";

        // Local (sala_id): não editável, sempre null
        const salaId = null;

        return {
            entrada_id: parseInt(entradaId, 10),
            nome_evento: $("nome_evento").value.trim(),
            responsavel_evento: $("responsavel_evento").value.trim(),
            horario_pauta: $("horario_pauta").value || null,
            hora_inicio: $("hora_inicio").value || null,
            hora_fim: $("hora_fim").value || null,
            hora_entrada: $("hora_entrada").value || null,
            hora_saida: $("hora_saida").value || null,
            usb_01: $("usb_01").value.trim() || null,
            usb_02: $("usb_02").value.trim() || null,
            observacoes: $("observacoes").value.trim() || null,
            comissao_id: comissaoId,
            tipo_evento: getTipoEvento(),
            houve_anormalidade: houveAnormalidade,
            sala_id: salaId,
        };
    }

    // ====== Validar dados ======
    function validateEditData(payload) {
        const radioEncerrado = document.querySelector('input[name="evento_encerrado"]:checked');
        const encerrado = radioEncerrado ? radioEncerrado.value === "sim" : false;
        const ordem = parseInt((state.originalData || {}).ordem, 10) || 1;
        const primeiroOperador = ordem === 1;

        if (!payload.nome_evento) {
            return { valid: false, message: "A Descrição do Evento é obrigatória." };
        }
        if (!payload.responsavel_evento) {
            return { valid: false, message: "O Responsável pelo Evento é obrigatório." };
        }
        if (!payload.hora_inicio) {
            return { valid: false, message: "O Início do evento é obrigatório." };
        }
        if (encerrado && !payload.hora_fim) {
            return { valid: false, message: 'O "Término do evento" é obrigatório.' };
        }
        if (!primeiroOperador && !payload.hora_entrada) {
            return { valid: false, message: 'O "Início da operação" é obrigatório.' };
        }
        if (!encerrado && !payload.hora_saida) {
            return { valid: false, message: 'O "Término da operação" é obrigatório.' };
        }
        return { valid: true };
    }

    // ====== Enviar edição ======
    async function submitEdit() {
        const payload = collectEditData();
        const validation = validateEditData(payload);

        if (!validation.valid) {
            alert(validation.message);
            return;
        }

        const btn = $("btn-salvar");
        const originalTxt = btn.textContent;
        btn.disabled = true;
        btn.textContent = "Salvando...";

        try {
            const url = AppConfig.apiUrl(AppConfig.endpoints.operacaoAudio.editarEntrada);

            const resp = await Auth.authFetch(url, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });

            if (resp.status === 401 || resp.status === 403) {
                alert("Sem permissão para editar este registro.");
                return;
            }

            const json = await resp.json().catch(() => ({}));

            if (resp.ok && json.ok) {
                if (json.houve_anormalidade_nova) {
                    // Redireciona para formulário de anormalidade
                    alert("Edição salva com sucesso.\n\nRedirecionando para Registro de Anormalidade.");
                    window.location.href = `/forms/operacao/anormalidade.html?registro_id=${json.registro_id}&entrada_id=${json.entrada_id}&modo=novo`;
                    return;
                }

                alert("Edição salva com sucesso!");

                // Sai do modo edição e recarrega
                state.editMode = false;
                const form = $("form-roa-readonly");
                form.classList.remove("editing");

                // Restaura campos de leitura
                $("sala_nome").classList.remove("hidden");
                $("sala_id_edit").classList.add("hidden");
                $("sala_id_edit").onchange = null;
                $("atividade_legislativa").classList.remove("hidden");
                $("comissao_id_edit").classList.add("hidden");
                $("nome_evento").setAttribute("readonly", "");
                $("responsavel_evento").setAttribute("readonly", "");
                $("horario_pauta").setAttribute("readonly", "");

                // Remove disabled e restaura readonly nos campos de horário
                ["hora_inicio", "hora_fim", "hora_entrada", "hora_saida", "usb_01", "usb_02"].forEach(function (id) {
                    var el = $(id);
                    if (el) el.disabled = false;
                });
                $("hora_inicio").setAttribute("readonly", "");
                $("hora_fim").setAttribute("readonly", "");
                $("hora_entrada").setAttribute("readonly", "");
                $("hora_saida").setAttribute("readonly", "");
                $("usb_01").setAttribute("readonly", "");
                $("usb_02").setAttribute("readonly", "");
                $("observacoes").setAttribute("readonly", "");

                // Radio de encerrado: desabilita
                document.querySelectorAll('input[name="evento_encerrado"]').forEach(function (r) { r.disabled = true; });

                // Remove listeners de sincronização
                _removeEditListeners();

                // Limpa classe "required" do label hora_fim
                var labelHoraFim = document.querySelector('label[for="hora_fim"]');
                if (labelHoraFim) labelHoraFim.classList.remove("required");

                // Houve anormalidade: desabilita novamente
                $("houve_anormalidade_nao").disabled = true;
                $("houve_anormalidade_sim").disabled = true;
                $("anormalidade-nota").classList.add("hidden");

                // Botões
                $("btn-editar").classList.remove("hidden");
                $("btn-salvar").classList.add("hidden");
                $("btn-cancelar").classList.add("hidden");

                // Recarrega dados do servidor
                await loadData();
            } else {
                const msg = json.message || json.error || "Erro ao salvar.";
                alert("Não foi possível salvar: " + msg);
            }

        } catch (e) {
            console.error(e);
            alert("Erro de conexão ao salvar.");
        } finally {
            btn.disabled = false;
            btn.textContent = originalTxt;
        }
    }

    // ====== Init ======
    document.addEventListener("DOMContentLoaded", () => {
        loadData();

        $("btn-editar").addEventListener("click", enterEditMode);
        $("btn-salvar").addEventListener("click", submitEdit);
        $("btn-cancelar").addEventListener("click", exitEditMode);
    });

})();
