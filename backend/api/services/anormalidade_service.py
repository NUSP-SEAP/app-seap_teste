from dataclasses import dataclass
from typing import Any, Dict, Optional

from django.db import transaction

from .. import db


class ServiceValidationError(Exception):
    """
    Erro de validação para o domínio de anormalidade.
    A view vai capturar isso e devolver HTTP 400 com o mesmo formato
    de erros que você já usa hoje (payload com "errors").
    """

    def __init__(self, code: str, message: str, extra: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.extra = extra or {}


@dataclass
class RegistroAnormalidadeResult:
    registro_anormalidade_id: int
    registro_id: int


def registrar_anormalidade(payload: Dict[str, Any], user_id: Optional[str]) -> RegistroAnormalidadeResult:
    """
    Registra o formulário 'Registro de Anormalidade na Operação de Áudio'.

    - data_solucao e hora_solucao: OPCIONAIS (só preenchidos se o operador informar solução).

    Espera um payload com a mesma estrutura enviada pelo front (form ou JSON),
    com pelo menos:

        registro_id, data, sala_id, nome_evento,
        hora_inicio_anormalidade, descricao_anormalidade,
        houve_prejuizo, descricao_prejuizo,
        houve_reclamacao, autores_conteudo_reclamacao,
        acionou_manutencao, hora_acionamento_manutencao,
        resolvida_pelo_operador, procedimentos_adotados,
        data_solucao, hora_solucao,
        responsavel_evento,
        entrada_id (opcional, mas validado se vier).
    """
    body = payload or {}

    # 1) Leitura dos campos (strings cruas)
    registro_id_raw = (body.get("registro_id") or "").strip()
    data_str = (body.get("data") or "").strip()
    sala_id_raw = (body.get("sala_id") or "").strip()
    nome_evento = (body.get("nome_evento") or "").strip()

    hora_inicio_anormalidade = (body.get("hora_inicio_anormalidade") or "").strip()
    descricao_anormalidade = (body.get("descricao_anormalidade") or "").strip()

    houve_prejuizo_raw = (body.get("houve_prejuizo") or "").strip()
    descricao_prejuizo = (body.get("descricao_prejuizo") or "").strip()

    houve_reclamacao_raw = (body.get("houve_reclamacao") or "").strip()
    autores_conteudo_reclamacao = (body.get("autores_conteudo_reclamacao") or "").strip()

    acionou_manutencao_raw = (body.get("acionou_manutencao") or "").strip()
    hora_acionamento_manutencao = (body.get("hora_acionamento_manutencao") or "").strip()

    resolvida_pelo_operador_raw = (body.get("resolvida_pelo_operador") or "").strip()
    procedimentos_adotados = (body.get("procedimentos_adotados") or "").strip()

    data_solucao = (body.get("data_solucao") or "").strip()
    hora_solucao = (body.get("hora_solucao") or "").strip()

    responsavel_evento = (body.get("responsavel_evento") or "").strip()

    # vínculo com a ENTRADA (registro_operacao_operador.id)
    entrada_id_raw = (body.get("entrada_id") or "").strip()

    # id da própria anormalidade (para edição)
    anom_id_raw = (body.get("id") or body.get("registro_anormalidade_id") or "").strip()

    def _as_bool(v: str) -> bool:
        return (v or "").strip().lower() in ("sim", "true", "1", "on")

    houve_prejuizo = _as_bool(houve_prejuizo_raw)
    houve_reclamacao = _as_bool(houve_reclamacao_raw)
    acionou_manutencao = _as_bool(acionou_manutencao_raw)
    resolvida_pelo_operador = _as_bool(resolvida_pelo_operador_raw)

    # 2) Validações de obrigatoriedade (mesmo padrão da versão antiga)
    errors: Dict[str, str] = {}

    if not registro_id_raw:
        errors["registro_id"] = "Campo obrigatório."
    if not data_str:
        errors["data"] = "Campo obrigatório."
    if not sala_id_raw:
        errors["sala_id"] = "Campo obrigatório."
    if not nome_evento:
        errors["nome_evento"] = "Campo obrigatório."

    if not hora_inicio_anormalidade:
        errors["hora_inicio_anormalidade"] = "Campo obrigatório."
    if not descricao_anormalidade:
        errors["descricao_anormalidade"] = "Campo obrigatório."
    if not responsavel_evento:
        errors["responsavel_evento"] = "Campo obrigatório."

    # Regras condicionais alinhadas às CHECK constraints
    if houve_prejuizo and not descricao_prejuizo:
        errors["descricao_prejuizo"] = "Campo obrigatório quando houve prejuízo."

    if houve_reclamacao and not autores_conteudo_reclamacao:
        errors["autores_conteudo_reclamacao"] = "Campo obrigatório quando houve reclamação."

    if acionou_manutencao and not hora_acionamento_manutencao:
        errors["hora_acionamento_manutencao"] = "Campo obrigatório quando houve acionamento de manutenção."

    # NOVO: se foi resolvida pelo operador, precisa descrever o que foi feito
    if resolvida_pelo_operador and not procedimentos_adotados:
        errors["procedimentos_adotados"] = (
            "Campo obrigatório quando a anormalidade foi resolvida pelo operador."
        )
    # --- NOVA VALIDAÇÃO: Datas Coerentes ---
    # Evita IntegrityError da constraint 'ck_datas_coerentes'
    if data_solucao:
        # Comparação léxica de strings ISO (YYYY-MM-DD) funciona corretamente
        if data_solucao < data_str:
            errors["data_solucao"] = (
                "Data da solução da anormalidade não pode ser anterior à data da ocorrência."
            )
        elif data_solucao == data_str:
            if hora_solucao and hora_inicio_anormalidade and hora_solucao < hora_inicio_anormalidade:
                errors["hora_solucao"] = (
                    "Hora da solução não pode ser anterior ao início da anormalidade."
                )

    # entrada_id é opcional, mas se vier, deve ser inteiro positivo
    entrada_id: Optional[int]
    if entrada_id_raw:
        try:
            entrada_id_val = int(entrada_id_raw)
            if entrada_id_val <= 0:
                raise ValueError()
            entrada_id = entrada_id_val
        except (TypeError, ValueError):
            errors["entrada_id"] = "Entrada inválida."
            entrada_id = None
    else:
        entrada_id = None

    if errors:
        raise ServiceValidationError(
            code="validation_error",
            message="Erros de validação nos campos.",
            extra={"errors": errors},
        )

    # 3) Conversões numéricas obrigatórias
    try:
        registro_id = int(registro_id_raw)
    except ValueError:
        raise ServiceValidationError(
            code="invalid_registro_id",
            message="Registro inválido.",
            extra={"errors": {"registro_id": "Registro inválido."}},
        )

    try:
        sala_id = int(sala_id_raw)
    except ValueError:
        raise ServiceValidationError(
            code="invalid_sala_id",
            message="Local inválido.",
            extra={"errors": {"sala_id": "Local inválido."}},
        )

    # Conversão do id da anormalidade (edição), se fornecido
    anom_id: Optional[int] = None
    if anom_id_raw:
        try:
            anom_id_val = int(anom_id_raw)
            if anom_id_val <= 0:
                raise ValueError()
            anom_id = anom_id_val
        except (TypeError, ValueError):
            raise ServiceValidationError(
                code="invalid_registro_anormalidade_id",
                message="Registro de anormalidade inválido.",
                extra={"errors": {"id": "Registro de anormalidade inválido."}},
            )

    # 4) Normalização de opcionais (NULL se vazio)
    data_solucao_val = data_solucao or None
    hora_solucao_val = hora_solucao or None
    hora_acionamento_manutencao_val = hora_acionamento_manutencao or None

    # 5) Inserção / atualização transacional
    with transaction.atomic():
        if anom_id is not None:
            # UPDATE
            db.update_registro_anormalidade(
                anom_id=anom_id,
                data=data_str,
                sala_id=sala_id,
                nome_evento=nome_evento,
                hora_inicio_anormalidade=hora_inicio_anormalidade,
                descricao_anormalidade=descricao_anormalidade,
                houve_prejuizo=houve_prejuizo,
                descricao_prejuizo=descricao_prejuizo or None,
                houve_reclamacao=houve_reclamacao,
                autores_conteudo_reclamacao=autores_conteudo_reclamacao or None,
                acionou_manutencao=acionou_manutencao,
                hora_acionamento_manutencao=hora_acionamento_manutencao_val,
                resolvida_pelo_operador=resolvida_pelo_operador,
                procedimentos_adotados=procedimentos_adotados or None,
                data_solucao=data_solucao_val,
                hora_solucao=hora_solucao_val,
                responsavel_evento=responsavel_evento,
                atualizado_por=user_id,
            )
            registro_anom_id = anom_id
        else:
            # INSERT
            registro_anom_id = db.insert_registro_anormalidade(
                registro_id=registro_id,
                data=data_str,
                sala_id=sala_id,
                nome_evento=nome_evento,
                hora_inicio_anormalidade=hora_inicio_anormalidade,
                descricao_anormalidade=descricao_anormalidade,
                houve_prejuizo=houve_prejuizo,
                descricao_prejuizo=descricao_prejuizo or None,
                houve_reclamacao=houve_reclamacao,
                autores_conteudo_reclamacao=autores_conteudo_reclamacao or None,
                acionou_manutencao=acionou_manutencao,
                hora_acionamento_manutencao=hora_acionamento_manutencao_val,
                resolvida_pelo_operador=resolvida_pelo_operador,
                procedimentos_adotados=procedimentos_adotados or None,
                data_solucao=data_solucao_val,
                hora_solucao=hora_solucao_val,
                responsavel_evento=responsavel_evento,
                criado_por=user_id,
                atualizado_por=user_id,
                # <<< conforme a especificação: insert_registro_anormalidade ganhou entrada_id
                entrada_id=entrada_id,
            )

    return RegistroAnormalidadeResult(
        registro_anormalidade_id=int(registro_anom_id),
        registro_id=registro_id,
    )
