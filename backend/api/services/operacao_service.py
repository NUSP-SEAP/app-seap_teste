from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from django.db import transaction

from api.db import operacao as db


class ServiceValidationError(Exception):
    """
    Erro de validação de regra de negócio.
    As views vão capturar isso e devolver HTTP 400.
    """

    def __init__(self, code: str, message: str, extra: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.extra = extra or {}

@dataclass
class SessaoOperacaoContextEntrada:
    id: int
    registro_id: int
    operador_id: str
    operador_nome: str
    ordem: int
    seq: int
    nome_evento: Optional[str]
    horario_pauta: Optional[str]
    horario_inicio: Optional[str]
    horario_termino: Optional[str]
    tipo_evento: str
    usb_01: Optional[str]
    usb_02: Optional[str]
    observacoes: Optional[str]
    comissao_id: Optional[int]
    responsavel_evento: Optional[str]
    houve_anormalidade: Optional[bool]
    anormalidade_id: Optional[int]
    hora_entrada: Optional[str]
    hora_saida: Optional[str]


@dataclass
class SessaoOperacaoContext:
    sala_id: int
    sala_nome: Optional[str]
    existe_sessao: bool
    registro_id: Optional[int]
    data: Optional[str]  # "YYYY-MM-DD"
    checklist_do_dia_id: Optional[int]
    checklist_do_dia_ok: Optional[bool]
    entradas: List[SessaoOperacaoContextEntrada]
    entradas_operador: List[SessaoOperacaoContextEntrada]
    situacao_operador: str  # "sem_sessao" | "sem_entrada" | "uma_entrada" | "duas_entradas"
    nomes_operadores_sessao: List[str]



@dataclass
class RegistroOperacaoAudioResult:
    registro_id: int
    houve_anormalidade: bool


def registrar_operacao_audio(
    payload: Dict[str, Any],
    user_id: Optional[str],
) -> RegistroOperacaoAudioResult:
    """
    Registra uma operação de áudio com a mesma lógica antiga da view,
    mas agora já entendendo Tipo do Evento e aplicando a regra:
    - Anormalidade só existe em Operação Comum.
    """

    def _s(key: str, default: str = "") -> str:
        return (str(payload.get(key, default)) or "").strip()

    # 1) Leitura / normalização dos campos básicos
    data_operacao = _s("data_operacao")
    horario_pauta = _s("horario_pauta")
    hora_inicio = _s("hora_inicio")
    hora_fim = _s("hora_fim")
    sala_id_raw = _s("sala_id")
    nome_evento = _s("nome_evento")
    observacoes = _s("observacoes")
    usb_01 = _s("usb_01")
    usb_02 = _s("usb_02")

    # Tipo do Evento vindo do front (texto ou código)
    tipo_evento_raw = _s("tipo_evento", "operacao")

    # Houve anormalidade? (texto “sim/nao” vindo do front)
    houve_anormalidade_raw = _s("houve_anormalidade", "nao")

    # Lista de operadores já montada pela view (modo legado)
    operadores_raw = payload.get("operadores") or []
    operadores: List[str] = []
    for op in operadores_raw:
        op_str = (str(op) or "").strip()
        if op_str:
            operadores.append(op_str)

    # 2) Validações de obrigatoriedade (mesmas chaves da view atual)
    errors: Dict[str, str] = {}

    if not data_operacao:
        errors["data_operacao"] = "Campo obrigatório."
    if not nome_evento:
        errors["nome_evento"] = "Campo obrigatório."
    if not sala_id_raw:
        errors["sala_id"] = "Campo obrigatório."
    if not hora_inicio:
        errors["hora_inicio"] = "Campo obrigatório."
    
    # CORREÇÃO: Removida a obrigatoriedade de hora_fim aqui também
    # if not hora_fim:
    #     errors["hora_fim"] = "Campo obrigatório."

    if not operadores:
        # Mantém a mesma chave usada hoje na view
        errors["operador_1"] = "Informe pelo menos um operador."

    # Normalização + validação de tipo_evento
    tipo_evento_norm = (tipo_evento_raw or "").strip().lower()
    if not tipo_evento_norm:
        tipo_evento = "operacao"
    elif tipo_evento_norm in ("operacao", "operação comum", "operacao comum", "operacao_comum"):
        tipo_evento = "operacao"
    elif tipo_evento_norm in ("cessao", "cessão de sala", "cessao de sala", "cessao_sala"):
        tipo_evento = "cessao"
    elif tipo_evento_norm in ("outros", "outros eventos", "outros_eventos"):
        tipo_evento = "outros"
    else:
        errors["tipo_evento"] = "Tipo de evento inválido."

    if errors:
        # A view espera extra={"errors": {...}}
        raise ServiceValidationError(
            code="invalid_payload",
            message="Erros de validação no formulário.",
            extra={"errors": errors},
        )

    # 3) Conversões
    try:
        sala_id_int = int(sala_id_raw)
    except (TypeError, ValueError):
        raise ServiceValidationError(
            code="invalid_sala_id",
            message="Local inválido.",
            extra={"errors": {"sala_id": "Local inválido."}},
        )

    # Regra da especificação:
    # - Anormalidade só existe em Operação Comum
    #   → em Cessão/Outros, forçamos houve_anormalidade=False.
    permite_anormalidade = tipo_evento == "operacao"
    if permite_anormalidade:
        houve_anormalidade = (houve_anormalidade_raw or "").strip().lower() == "sim"
    else:
        houve_anormalidade = False

    # 4) Inserções transacionais (por enquanto, mesmas tabelas de antes)
    with transaction.atomic():
        registro_id = db.insert_registro_operacao_audio(
            data_operacao=data_operacao,
            nome_evento=nome_evento,
            sala_id=str(sala_id_int),
            horario_pauta=horario_pauta or None,
            hora_inicio=hora_inicio,
            hora_fim=hora_fim or None,
            tipo_evento=tipo_evento,
            houve_anormalidade=houve_anormalidade,
            observacoes=observacoes or None,
            usb_01=usb_01 or None,
            usb_02=usb_02 or None,
            criado_por=user_id,
            atualizado_por=user_id,
        )

        ordem = 1
        for operador_id in operadores:
            db.insert_registro_operacao_operador(
                registro_id=registro_id,
                operador_id=operador_id,
                ordem=ordem,
                hora_entrada=None,
                hora_saida=None,
                criado_por=user_id,
                atualizado_por=user_id,
            )
            ordem += 1

    return RegistroOperacaoAudioResult(
        registro_id=registro_id,
        houve_anormalidade=houve_anormalidade,
    )

def _fetch_sessao_aberta_por_sala(sala_id: int) -> Optional[Dict[str, Any]]:
    """
    Wrapper fino sobre db.get_sessao_aberta_por_sala, para manter
    o acoplamento com a camada db em um único ponto.
    """
    return db.get_sessao_aberta_por_sala(sala_id)


def obter_contexto_sessao(sala_id: int, operador_id: Optional[str]) -> SessaoOperacaoContext:
    sessao = db.get_sessao_aberta_por_sala(sala_id)
    if not sessao:
        return SessaoOperacaoContext(
            sala_id=sala_id,
            sala_nome=None,
            existe_sessao=False,
            registro_id=None,
            data=None,
            checklist_do_dia_id=None,
            checklist_do_dia_ok=None,
            entradas=[],
            entradas_operador=[],
            situacao_operador="sem_sessao",
            nomes_operadores_sessao=[],
        )

    registro_id = sessao["id"]
    data_raw = sessao["data"]
    data_str = data_raw.isoformat() if hasattr(data_raw, "isoformat") else str(data_raw)

    rows = db.listar_entradas_da_sessao(registro_id)
    entradas: List[SessaoOperacaoContextEntrada] = []

    for r in rows:
        tipo = (r.get("tipo_evento") or "operacao").strip().lower()
        if tipo not in ("operacao", "cessao", "outros"):
            tipo = "operacao"

        def _fmt_time(v):
            return v.strftime("%H:%M") if v is not None and hasattr(v, "strftime") else (str(v) if v else None)

        entradas.append(
            SessaoOperacaoContextEntrada(
                id=r["id"],
                registro_id=r["registro_id"],
                operador_id=str(r["operador_id"]),
                operador_nome=r["operador_nome"],
                ordem=r["ordem"],
                seq=r["seq"],
                nome_evento=r.get("nome_evento"),
                horario_pauta=_fmt_time(r.get("horario_pauta")),
                horario_inicio=_fmt_time(r.get("horario_inicio")),
                horario_termino=_fmt_time(r.get("horario_termino")),
                tipo_evento=tipo,
                usb_01=r.get("usb_01"),
                usb_02=r.get("usb_02"),
                observacoes=r.get("observacoes"),
                comissao_id=r.get("comissao_id"),
                responsavel_evento=r.get("responsavel_evento"),
                houve_anormalidade=r.get("houve_anormalidade"),
                anormalidade_id=r.get("anormalidade_id"),
                hora_entrada=_fmt_time(r.get("hora_entrada")),
                hora_saida=_fmt_time(r.get("hora_saida")),
            )
        )

    entradas.sort(key=lambda e: (e.ordem, e.id))

    if operador_id:
        entradas_operador = [e for e in entradas if e.operador_id == str(operador_id)]
    else:
        entradas_operador = []

    qtd = len(entradas_operador)
    if not sessao:
        situacao = "sem_sessao"
    elif qtd == 0:
        situacao = "sem_entrada"
    elif qtd == 1:
        situacao = "uma_entrada"
    else:
        situacao = "duas_entradas"

    nomes_operadores: List[str] = []
    vistos = set()
    for e in entradas:
        if e.operador_nome not in vistos:
            vistos.add(e.operador_nome)
            nomes_operadores.append(e.operador_nome)

    return SessaoOperacaoContext(
        sala_id=sala_id,
        sala_nome=sessao.get("sala_nome"),
        existe_sessao=True,
        registro_id=registro_id,
        data=data_str,
        checklist_do_dia_id=sessao.get("checklist_do_dia_id"),
        checklist_do_dia_ok=sessao.get("checklist_do_dia_ok"),
        entradas=entradas,
        entradas_operador=entradas_operador,
        situacao_operador=situacao,
        nomes_operadores_sessao=nomes_operadores,
    )


def obter_estado_sessao_para_operador(
    sala_id: int,
    operador_id: Optional[str],
) -> Dict[str, Any]:
    ctx = obter_contexto_sessao(sala_id=sala_id, operador_id=operador_id)

    def _serialize(e: SessaoOperacaoContextEntrada) -> Dict[str, Any]:
        return {
            "entrada_id": e.id,
            "registro_id": e.registro_id,
            "operador_id": e.operador_id,
            "operador_nome": e.operador_nome,
            "ordem": e.ordem,
            "seq": e.seq,
            "nome_evento": e.nome_evento,
            "horario_pauta": e.horario_pauta,
            "horario_inicio": e.horario_inicio,
            "horario_termino": e.horario_termino,
            "tipo_evento": e.tipo_evento,
            "usb_01": e.usb_01,
            "usb_02": e.usb_02,
            "observacoes": e.observacoes,
            "comissao_id": e.comissao_id,
            "responsavel_evento": e.responsavel_evento,
            "houve_anormalidade": e.houve_anormalidade,
            "anormalidade_id": e.anormalidade_id,
            "hora_entrada": e.hora_entrada,
            "hora_saida": e.hora_saida,
        }

    if not ctx.existe_sessao or ctx.registro_id is None:
        return {
            "sala_id": sala_id,
            "sala_nome": ctx.sala_nome,
            "existe_sessao_aberta": False,
            "registro_id": None,
            "tipo_evento": "operacao",
            "permite_anormalidade": True,
            "data": None,
            "nome_evento": None,
            "horario_pauta": None,
            "horario_inicio": None,
            "horario_termino": None,
            "nomes_operadores_sessao": [],
            "situacao_operador": ctx.situacao_operador,
            "entradas_operador": [],
            "entradas_sessao": [],
            "max_entradas_por_operador": 2,
        }

    # Escolhe uma entrada "de referência" para o cabeçalho (normalmente a primeira da sessão)
    entrada_header: Optional[SessaoOperacaoContextEntrada] = None
    for e in ctx.entradas:
        if e.comissao_id is not None:
            entrada_header = e
            break
    if entrada_header is None and ctx.entradas:
        entrada_header = ctx.entradas[0]

    if entrada_header:
        tipo_header = entrada_header.tipo_evento
        nome_evento_header = entrada_header.nome_evento
        horario_pauta_header = entrada_header.horario_pauta
        horario_inicio_header = entrada_header.horario_inicio
        horario_termino_header = entrada_header.horario_termino
        responsavel_evento_header = entrada_header.responsavel_evento
        comissao_id_header = entrada_header.comissao_id
    else:
        tipo_header = "operacao"
        nome_evento_header = None
        horario_pauta_header = None
        horario_inicio_header = None
        horario_termino_header = None
        responsavel_evento_header = None
        comissao_id_header = None

    permite_anormalidade = tipo_header == "operacao"

    return {
        "sala_id": sala_id,
        "sala_nome": ctx.sala_nome,
        "existe_sessao_aberta": True,
        "registro_id": ctx.registro_id,
        "tipo_evento": tipo_header,
        "permite_anormalidade": permite_anormalidade,
        "data": ctx.data,
        "nome_evento": nome_evento_header,
        "horario_pauta": horario_pauta_header,
        "horario_inicio": horario_inicio_header,
        "horario_termino": horario_termino_header,
        "responsavel_evento": responsavel_evento_header,
        "comissao_id": comissao_id_header,
        "nomes_operadores_sessao": ctx.nomes_operadores_sessao,
        "situacao_operador": ctx.situacao_operador,
        "entradas_operador": [_serialize(e) for e in ctx.entradas_operador],
        "entradas_sessao": [_serialize(e) for e in ctx.entradas],
        "max_entradas_por_operador": 2,
    }

def salvar_entrada_operacao_audio(
    payload: Dict[str, Any],
    user_id: Optional[str],
) -> Dict[str, Any]:
    """
    Cria ou edita uma ENTRADA de operador na sessão de operação de áudio.

    Regras principais:
      - Máx. 2 entradas por operador na sessão (seq = 1 ou 2).
      - Tipo do Evento é por entrada (não mais por sessão).
      - Houve anormalidade só é permitido quando tipo_evento = "operacao".
    """
    if not user_id:
        raise ServiceValidationError(
            code="unauthorized",
            message="Usuário não autenticado.",
            extra={"errors": {"geral": "Sessão expirada ou usuário não autenticado."}},
        )

    data_operacao = (payload.get("data_operacao") or "").strip()
    horario_pauta = (payload.get("horario_pauta") or "").strip() or None
    hora_inicio = (payload.get("hora_inicio") or "").strip() or None
    hora_fim = (payload.get("hora_fim") or "").strip() or None
    sala_id_raw = (payload.get("sala_id") or "").strip()
    nome_evento = (payload.get("nome_evento") or "").strip() or None
    observacoes = (payload.get("observacoes") or "").strip() or None
    usb_01 = (payload.get("usb_01") or "").strip() or None
    usb_02 = (payload.get("usb_02") or "").strip() or None
    responsavel_evento = (payload.get("responsavel_evento") or "").strip() or None
    hora_entrada = (payload.get("hora_entrada") or "").strip() or None
    hora_saida = (payload.get("hora_saida") or "").strip() or None
    tipo_evento_raw = (payload.get("tipo_evento") or "operacao").strip().lower()
    houve_anormalidade_raw = (payload.get("houve_anormalidade") or "nao").strip().lower()
    entrada_id_raw = payload.get("entrada_id")

    comissao_id_raw = (payload.get("comissao_id") or "").strip()
    comissao_id: Optional[int]
    if comissao_id_raw:
        try:
            comissao_id = int(comissao_id_raw)
        except ValueError:
            comissao_id = None
    else:
        comissao_id = None


    # Normaliza tipo_evento
    if tipo_evento_raw not in ("operacao", "cessao", "outros"):
        tipo_evento = "operacao"
    else:
        tipo_evento = tipo_evento_raw

    # Flag vindo do formulário (para o fluxo da tela)
    houve_anormalidade = houve_anormalidade_raw == "sim"
    if tipo_evento not in ("operacao", "cessao", "outros"):
        houve_anormalidade = False

    # Este é o flag que será devolvido para o front
    houve_anormalidade_front = houve_anormalidade

    # Validações básicas
    errors: Dict[str, str] = {}
    if not data_operacao:
        errors["data_operacao"] = "Campo obrigatório."
    if not sala_id_raw:
        errors["sala_id"] = "Campo obrigatório."
    if not nome_evento:
        errors["nome_evento"] = "Campo obrigatório."
    if not hora_inicio:
        errors["hora_inicio"] = "Campo obrigatório."

    # CORREÇÃO: hora_fim não é mais obrigatório
    # if not hora_fim:
    #     errors["hora_fim"] = "Campo obrigatório."

    if errors:
        raise ServiceValidationError(
            code="validation_error",
            message="Erro de validação.",
            extra={"errors": errors},
        )

    try:
        sala_id_int = int(sala_id_raw)
    except (TypeError, ValueError):
        raise ServiceValidationError(
            code="validation_error",
            message="Local inválido.",
            extra={"errors": {"sala_id": "Local inválido."}},
        )

    operador_id = str(user_id)
    ctx = obter_contexto_sessao(sala_id_int, operador_id)

    # --- EDIÇÃO -------------------------------------------------------------
    if entrada_id_raw:
        try:
            entrada_id = int(entrada_id_raw)
        except (TypeError, ValueError):
            raise ServiceValidationError(
                code="entrada_invalida",
                message="Entrada inválida para edição.",
                extra={"errors": {"geral": "Entrada inválida para edição."}},
            )

        entrada_atual = next((e for e in ctx.entradas_operador if e.id == entrada_id), None)
        if not entrada_atual:
            raise ServiceValidationError(
                code="entrada_invalida",
                message="Esta entrada não pertence ao operador ou à sessão atual.",
                extra={"errors": {"geral": "Entrada inválida para edição."}},
            )

        if not ctx.existe_sessao or ctx.registro_id is None:
            raise ServiceValidationError(
                code="sem_sessao",
                message="Não existe sessão aberta para este local.",
                extra={"errors": {"geral": "Não existe sessão aberta para este local."}},
            )

        with transaction.atomic():
            # Atualiza somente os dados da entrada do operador.
            # Regra nova: NÃO mexemos no campo houve_anormalidade aqui;
            # ele passa a ser sincronizado pela RAOA (trigger no banco).
            db.update_registro_operacao_operador(
                entrada_id=entrada_atual.id,
                nome_evento=nome_evento,
                horario_pauta=horario_pauta,
                horario_inicio=hora_inicio,
                horario_termino=hora_fim,
                tipo_evento=tipo_evento,
                houve_anormalidade=None,
                observacoes=observacoes,
                usb_01=usb_01,
                usb_02=usb_02,
                comissao_id=comissao_id,
                responsavel_evento=responsavel_evento,
                hora_entrada=hora_entrada,
                hora_saida=hora_saida,
                atualizado_por=user_id,
            )

            # NOVA REGRA: Se informou hora_fim na edição, fecha a sessão
            if hora_fim:
                db.finalizar_sessao_operacao_audio(
                    registro_id=ctx.registro_id,
                    fechado_por=user_id
                )

        return {
            "registro_id": ctx.registro_id,
            "entrada_id": entrada_atual.id,
            # devolve o que veio do formulário/RAOA, não o que está no banco
            "houve_anormalidade": houve_anormalidade_front,
            "tipo_evento": tipo_evento,
            "seq": entrada_atual.seq,
            "is_edicao": True,
        }


    # --- CRIAÇÃO ------------------------------------------------------------
    qtd_entradas = len(ctx.entradas_operador)
    if qtd_entradas >= 2:
        raise ServiceValidationError(
            code="limite_entradas",
            message="Este operador já possui 2 entradas nesta sessão.",
            extra={"errors": {"operador": "Limite de 2 entradas por operador na sessão."}},
        )

    seq = 1 if qtd_entradas == 0 else 2

    # Na criação, o cabeçalho e a entrada nascem SEM anormalidade marcada.
    # Se o usuário marcar "Sim", isso só significa que vamos abrir a tela de RAOA;
    # o flag verdadeiro da anormalidade será ligado quando a RAOA for salva.
    houve_anormalidade_db = False

    with transaction.atomic():
        if not ctx.existe_sessao or ctx.registro_id is None:
            registro_id = db.insert_registro_operacao_audio(
                data_operacao=data_operacao,
                nome_evento=nome_evento,
                sala_id=str(sala_id_int),
                horario_pauta=horario_pauta,
                hora_inicio=hora_inicio,
                hora_fim=hora_fim,
                tipo_evento=tipo_evento,
                houve_anormalidade=houve_anormalidade_db,
                observacoes=observacoes,
                usb_01=usb_01,
                usb_02=usb_02,
                criado_por=user_id,
                atualizado_por=user_id,
            )
        else:
            registro_id = ctx.registro_id

        ordem = len(ctx.entradas) + 1

        entrada_id = db.insert_registro_operacao_operador(
            registro_id=registro_id,
            operador_id=operador_id,
            ordem=ordem,
            hora_entrada=hora_entrada,
            hora_saida=hora_saida,
            nome_evento=nome_evento,
            horario_pauta=horario_pauta,
            horario_inicio=hora_inicio,
            horario_termino=hora_fim,
            tipo_evento=tipo_evento,
            seq=seq,
            houve_anormalidade=houve_anormalidade_db,
            observacoes=observacoes,
            usb_01=usb_01,
            usb_02=usb_02,
            comissao_id=comissao_id,
            responsavel_evento=responsavel_evento,
            criado_por=user_id,
            atualizado_por=user_id,
        )

        # NOVA REGRA: Se informou hora_fim na criação, fecha a sessão
        if hora_fim:
            db.finalizar_sessao_operacao_audio(
                registro_id=registro_id,
                fechado_por=user_id
            )
            
    return {
        "registro_id": registro_id,
        "entrada_id": entrada_id,
        # devolve o que veio do formulário, para o front decidir abrir RAOA
        "houve_anormalidade": houve_anormalidade_front,
        "tipo_evento": tipo_evento,
        "seq": seq,
        "is_edicao": False,
    }

@dataclass
class EntradaOperacaoEditResult:
    entrada_id: int
    registro_id: int
    houve_anormalidade_nova: bool  # True se mudou de false→true


def editar_entrada_operacao(
    entrada_id: int,
    payload: Dict[str, Any],
    user_id: Optional[str],
) -> EntradaOperacaoEditResult:
    """
    Edita uma entrada de operador existente (tela de detalhe).
    Antes de aplicar as alterações, salva um snapshot do estado anterior
    na tabela de histórico para rastreabilidade.
    """
    if not user_id:
        raise ServiceValidationError(
            code="unauthorized",
            message="Usuário não autenticado.",
            extra={"errors": {"geral": "Sessão expirada ou usuário não autenticado."}},
        )

    body = payload or {}

    # 1) Campos obrigatórios
    nome_evento = (body.get("nome_evento") or "").strip()
    hora_inicio = (body.get("hora_inicio") or "").strip() or None
    responsavel_evento = (body.get("responsavel_evento") or "").strip()

    errors: Dict[str, str] = {}
    if not nome_evento:
        errors["nome_evento"] = "Campo obrigatório."
    if not hora_inicio:
        errors["hora_inicio"] = "Campo obrigatório."
    if not responsavel_evento:
        errors["responsavel_evento"] = "Campo obrigatório."

    if errors:
        raise ServiceValidationError(
            code="validation_error",
            message="Erro de validação.",
            extra={"errors": errors},
        )

    # 2) Campos opcionais
    horario_pauta = (body.get("horario_pauta") or "").strip() or None
    horario_termino = (body.get("hora_fim") or "").strip() or None
    usb_01 = (body.get("usb_01") or "").strip() or None
    usb_02 = (body.get("usb_02") or "").strip() or None
    observacoes = (body.get("observacoes") or "").strip() or None
    hora_entrada = (body.get("hora_entrada") or "").strip() or None
    hora_saida = (body.get("hora_saida") or "").strip() or None
    tipo_evento = (body.get("tipo_evento") or "operacao").strip().lower()
    if tipo_evento not in ("operacao", "cessao", "outros"):
        tipo_evento = "operacao"

    comissao_id_raw = (body.get("comissao_id") or "").strip() if isinstance(body.get("comissao_id"), str) else body.get("comissao_id")
    comissao_id: Optional[int] = None
    if comissao_id_raw:
        try:
            comissao_id = int(comissao_id_raw)
        except (TypeError, ValueError):
            comissao_id = None

    # 2b) sala_id (opcional, só quando total_entradas = 1)
    sala_id_raw = body.get("sala_id")
    novo_sala_id: Optional[int] = None
    if sala_id_raw is not None and str(sala_id_raw).strip():
        try:
            novo_sala_id = int(sala_id_raw)
        except (TypeError, ValueError):
            novo_sala_id = None

    # 2c) Verifica total de entradas na sessão para permitir edição de sala/hora_fim
    from api.db.operacao import count_entradas_por_sessao
    total_entradas = count_entradas_por_sessao(entrada_id)

    # Se há mais de 1 operador, ignora alterações em sala_id e horario_termino
    if total_entradas > 1:
        novo_sala_id = None
        horario_termino = None  # será preenchido com o valor original abaixo

    # 3) Verifica se houve_anormalidade mudou de false→true
    houve_anormalidade_raw = (body.get("houve_anormalidade") or "nao").strip().lower()
    houve_anormalidade_nova_val = houve_anormalidade_raw == "sim"

    # Busca o valor atual de houve_anormalidade no banco
    from api.db.operacao import get_entrada_operacao_snapshot
    snap_before_check = get_entrada_operacao_snapshot(entrada_id)
    houve_anormalidade_atual = bool(snap_before_check.get("houve_anormalidade", False))

    # Flag: houve mudança de false→true (precisa criar anormalidade)
    houve_anormalidade_nova = (not houve_anormalidade_atual) and houve_anormalidade_nova_val

    # Busca registro_id para retorno
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute(
            "SELECT registro_id FROM operacao.registro_operacao_operador WHERE id = %s::bigint",
            [entrada_id],
        )
        row = cur.fetchone()
        registro_id = int(row[0]) if row else 0

    # 4) Operações de banco em transação única
    # Se total_entradas > 1, mantém horario_termino original (não permite edição)
    if total_entradas > 1:
        horario_termino = snap_before_check.get("horario_termino")
        # Converte de isoformat string de volta se necessário
        if isinstance(horario_termino, str) and horario_termino:
            pass  # já é string, o banco aceita
        elif horario_termino is None:
            pass

    campos = {
        "nome_evento": nome_evento,
        "responsavel_evento": responsavel_evento,
        "horario_pauta": horario_pauta,
        "horario_inicio": hora_inicio,
        "horario_termino": horario_termino,
        "usb_01": usb_01,
        "usb_02": usb_02,
        "observacoes": observacoes,
        "comissao_id": comissao_id,
        "tipo_evento": tipo_evento,
        "hora_entrada": hora_entrada,
        "hora_saida": hora_saida,
    }

    with transaction.atomic():
        # 4.1) Captura snapshot antes da edição
        snapshot = db.get_entrada_operacao_snapshot(entrada_id)

        # 4.2) Grava snapshot no histórico
        db.insert_entrada_operacao_historico(
            entrada_id=entrada_id,
            snapshot=snapshot,
            editado_por=user_id,
        )

        # 4.3) Atualiza campos editáveis na entrada do operador
        db.update_entrada_operacao_detalhe(
            entrada_id=entrada_id,
            campos=campos,
            atualizado_por=user_id,
        )

        # 4.4) Atualiza sala_id no registro de áudio (só se permitido e informado)
        if novo_sala_id is not None:
            db.update_sala_registro_operacao_audio(
                entrada_id=entrada_id,
                novo_sala_id=novo_sala_id,
            )

    return EntradaOperacaoEditResult(
        entrada_id=entrada_id,
        registro_id=registro_id,
        houve_anormalidade_nova=houve_anormalidade_nova,
    )


def finalizar_sessao_operacao_audio(
    sala_id: int,
    user_id: Optional[str],
) -> Dict[str, Any]:
    """
    Finaliza o REGISTRO DA SALA (sessão de operação de áudio) para a sala informada.

    Regras:
      - Só faz sentido se houver uma sessão em_aberto = true para a sala.
      - Marca em_aberto=false, fechado_em=NOW(), fechado_por=user_id.
    """
    if not user_id:
        raise ServiceValidationError(
            code="unauthorized",
            message="Usuário não autenticado.",
            extra={"errors": {"geral": "Sessão expirada ou usuário não autenticado."}},
        )

    # Busca a sessão aberta diretamente pelo helper
    sessao = _fetch_sessao_aberta_por_sala(sala_id)
    if not sessao:
        raise ServiceValidationError(
            code="no_open_session",
            message="Não existe registro aberto para este local.",
            extra={"errors": {"geral": "Não existe registro aberto para este local."}},
        )

    registro_id = int(sessao["id"])

    with transaction.atomic():
        db.finalizar_sessao_operacao_audio(
            registro_id=registro_id,
            fechado_por=user_id,
        )

    return {
        "registro_id": registro_id,
        "sala_id": sala_id,
        "status": "finalizado",
    }