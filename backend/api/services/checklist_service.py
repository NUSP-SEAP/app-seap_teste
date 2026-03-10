from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from django.db import transaction

from .. import db


class ServiceValidationError(Exception):
    """
    Erro de validação de regra de negócio para o domínio de checklist.
    As views vão capturar isso e devolver HTTP 400 com o payload apropriado.
    """

    def __init__(self, code: str, message: str, extra: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.extra = extra or {}


@dataclass
class ChecklistResult:
    checklist_id: int
    total_respostas: int


def registrar_checklist(payload: Dict[str, Any], user_id: Optional[str]) -> ChecklistResult:
    """
    Registra o checklist 'Testes Diários'.
    Aceita payload com itens contendo 'item_tipo_id' (novo padrão) ou 'nome' (legado).
    """
    body = payload or {}

    # 1) Campos mínimos do cabeçalho
    req_fields = ["data_operacao", "sala_id", "hora_inicio_testes", "hora_termino_testes"]
    faltantes = [k for k in req_fields if not body.get(k)]
    if faltantes:
        raise ServiceValidationError(
            code="invalid_payload",
            message="Campos obrigatórios ausentes.",
            extra={"missing": faltantes},
        )

    data_operacao = body.get("data_operacao")
    sala_id_raw = body.get("sala_id")
    turno = body.get("turno")
    hora_inicio = body.get("hora_inicio_testes")
    hora_termino = body.get("hora_termino_testes")
    observacoes = body.get("observacoes")
    usb_01 = body.get("usb_01")
    usb_02 = body.get("usb_02")

    # 2) Itens
    itens = body.get("itens") if isinstance(body.get("itens"), list) else []

    # 2.1) Valida itens e aplica regras de negócio
    invalid: List[int] = []
    falha_sem_desc: List[int] = []
    total_marcados = 0

    for idx, it in enumerate(itens):
        if not isinstance(it, dict):
            invalid.append(idx)
            continue

        # --- MUDANÇA AQUI: Aceita ID ou Nome ---
        item_id = it.get("item_tipo_id")
        nome_raw = it.get("nome")
        nome = (nome_raw or "").strip()

        # Se não tiver nem ID nem Nome, é inválido
        if not item_id and not nome:
            invalid.append(idx)
            continue

        status_raw = it.get("status")
        status = (status_raw or "").strip()

        desc_raw = it.get("descricao_falha")
        descricao_falha = (desc_raw or "").strip()
        
        # Leitura do valor texto (novo campo)
        valor_texto = (it.get("valor_texto") or "").strip()

        # Se tiver valor texto, conta como marcado mesmo sem status explícito (embora o front mande status='Ok')
        if status or valor_texto:
            total_marcados += 1

            # Se marcou Falha, exige descrição
            if status.lower() == "falha" and not descricao_falha:
                falha_sem_desc.append(idx)

    if invalid:
        raise ServiceValidationError(
            code="invalid_items",
            message="Itens de checklist inválidos (deve conter 'item_tipo_id').",
            extra={"invalid_indexes": invalid},
        )

    # Pelo menos 1 item marcado
    if total_marcados == 0:
        raise ServiceValidationError(
            code="no_item_marked",
            message="Pelo menos um item do checklist deve ser preenchido.",
            extra={"total_itens": len(itens)},
        )

    # Falha sem descrição
    if falha_sem_desc:
        raise ServiceValidationError(
            code="missing_failure_description",
            message="Itens marcados como Falha precisam de descrição.",
            extra={"indexes": falha_sem_desc},
        )

    # 3) Valida sala_id (int) e turno
    try:
        sala_id = int(sala_id_raw)
    except (TypeError, ValueError):
        raise ServiceValidationError(
            code="invalid_sala_id",
            message="Local inválido.",
            extra={"value": sala_id_raw},
        )

    # Se não veio turno, tenta inferir pela hora de início dos testes
    if not turno:
        try:
            hora_str = hora_inicio or ""
            hora = int(hora_str.split(":")[0])
            turno = "Matutino" if hora < 13 else "Vespertino"
        except (AttributeError, ValueError, IndexError):
            turno = "Matutino"  # Fallback seguro

    # 4) Operações de banco em transação única
    with transaction.atomic():
        # 4.1) Cabeçalho em forms.checklist
        checklist_id = db.insert_checklist(
            data_operacao=data_operacao,
            sala_id=str(sala_id),
            turno=turno,
            hora_inicio_testes=hora_inicio,
            hora_termino_testes=hora_termino,
            observacoes=observacoes,
            usb_01=usb_01,
            usb_02=usb_02,
            criado_por=user_id,
            atualizado_por=user_id,
        )

        # 4.2) Respostas em forms.checklist_resposta
        total_respostas = db.insert_checklist_respostas(
            checklist_id=checklist_id,
            itens=itens,
            criado_por=user_id,
            atualizado_por=user_id,
        )

    return ChecklistResult(
        checklist_id=checklist_id,
        total_respostas=total_respostas,
    )


# ──────────────────────────────────────────────
#  Edição de checklist
# ──────────────────────────────────────────────

@dataclass
class ChecklistEditResult:
    checklist_id: int
    total_respostas_atualizadas: int


def editar_checklist(
    checklist_id: int,
    payload: Dict[str, Any],
    user_id: Optional[str],
) -> ChecklistEditResult:
    """
    Edita um checklist existente.
    Antes de aplicar as alterações, salva um snapshot do estado anterior
    na tabela de histórico para rastreabilidade.
    """
    body = payload or {}

    # 1) Campos mínimos
    req_fields = ["data_operacao", "sala_id"]
    faltantes = [k for k in req_fields if not body.get(k)]
    if faltantes:
        raise ServiceValidationError(
            code="invalid_payload",
            message="Campos obrigatórios ausentes.",
            extra={"missing": faltantes},
        )

    data_operacao = body.get("data_operacao")
    sala_id_raw = body.get("sala_id")
    observacoes = body.get("observacoes")

    # 2) Valida sala_id
    try:
        sala_id = int(sala_id_raw)
    except (TypeError, ValueError):
        raise ServiceValidationError(
            code="invalid_sala_id",
            message="Local inválido.",
            extra={"value": sala_id_raw},
        )

    # 3) Itens
    itens = body.get("itens") if isinstance(body.get("itens"), list) else []

    falha_sem_desc: List[int] = []
    total_marcados = 0

    for idx, it in enumerate(itens):
        if not isinstance(it, dict):
            continue

        item_id = it.get("item_tipo_id")
        if not item_id:
            continue

        status = (it.get("status") or "").strip()
        descricao_falha = (it.get("descricao_falha") or "").strip()
        valor_texto = (it.get("valor_texto") or "").strip()

        if status or valor_texto:
            total_marcados += 1

            if status.lower() == "falha":
                if not descricao_falha or len(descricao_falha) < 10:
                    falha_sem_desc.append(idx)

    if total_marcados == 0:
        raise ServiceValidationError(
            code="no_item_marked",
            message="Pelo menos um item do checklist deve ser preenchido.",
            extra={"total_itens": len(itens)},
        )

    if falha_sem_desc:
        raise ServiceValidationError(
            code="missing_failure_description",
            message="Itens marcados como Falha precisam de descrição com no mínimo 10 caracteres.",
            extra={"indexes": falha_sem_desc},
        )

    # 4) Operações de banco em transação única
    with transaction.atomic():
        # 4.1) Captura snapshot antes da edição
        snapshot = db.get_checklist_snapshot(checklist_id)

        # 4.2) Grava snapshot no histórico
        db.insert_checklist_historico(
            checklist_id=checklist_id,
            snapshot=snapshot,
            editado_por=user_id,
        )

        # 4.3) Atualiza cabeçalho
        db.update_checklist(
            checklist_id=checklist_id,
            data_operacao=data_operacao,
            sala_id=sala_id,
            observacoes=observacoes,
            atualizado_por=user_id,
        )

        # 4.4) Atualiza respostas
        total_atualizadas = db.update_checklist_respostas(
            checklist_id=checklist_id,
            itens=itens,
            atualizado_por=user_id,
        )

    return ChecklistEditResult(
        checklist_id=checklist_id,
        total_respostas_atualizadas=total_atualizadas,
    )