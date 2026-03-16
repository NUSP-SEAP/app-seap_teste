from dataclasses import dataclass
from typing import Any, Dict, Optional

from django.db import transaction

from .. import db
from .exceptions import ServiceValidationError
from .utils import clean_str, parse_bool


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
    registro_id_raw = clean_str(body, "registro_id")
    data_str = clean_str(body, "data")
    sala_id_raw = clean_str(body, "sala_id")
    nome_evento = clean_str(body, "nome_evento")

    hora_inicio_anormalidade = clean_str(body, "hora_inicio_anormalidade")
    descricao_anormalidade = clean_str(body, "descricao_anormalidade")

    houve_prejuizo = parse_bool(clean_str(body, "houve_prejuizo")) or False
    descricao_prejuizo = clean_str(body, "descricao_prejuizo")

    houve_reclamacao = parse_bool(clean_str(body, "houve_reclamacao")) or False
    autores_conteudo_reclamacao = clean_str(body, "autores_conteudo_reclamacao")

    acionou_manutencao = parse_bool(clean_str(body, "acionou_manutencao")) or False
    hora_acionamento_manutencao = clean_str(body, "hora_acionamento_manutencao")

    resolvida_pelo_operador = parse_bool(clean_str(body, "resolvida_pelo_operador")) or False
    procedimentos_adotados = clean_str(body, "procedimentos_adotados")

    data_solucao = clean_str(body, "data_solucao")
    hora_solucao = clean_str(body, "hora_solucao")

    responsavel_evento = clean_str(body, "responsavel_evento")

    # vínculo com a ENTRADA (registro_operacao_operador.id)
    entrada_id_raw = clean_str(body, "entrada_id")

    # id da própria anormalidade (para edição)
    anom_id_raw = clean_str(body, "id") or clean_str(body, "registro_anormalidade_id")

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

    if resolvida_pelo_operador and not procedimentos_adotados:
        errors["procedimentos_adotados"] = (
            "Campo obrigatório quando a anormalidade foi resolvida pelo operador."
        )

    # Validação de datas coerentes (evita IntegrityError da constraint 'ck_datas_coerentes')
    if data_solucao:
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
    entrada_id: Optional[int] = None
    if entrada_id_raw:
        try:
            entrada_id_val = int(entrada_id_raw)
            if entrada_id_val <= 0:
                raise ValueError()
            entrada_id = entrada_id_val
        except (TypeError, ValueError):
            errors["entrada_id"] = "Entrada inválida."

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
    # Dict de parâmetros comum a INSERT e UPDATE
    params = dict(
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
        hora_acionamento_manutencao=hora_acionamento_manutencao or None,
        resolvida_pelo_operador=resolvida_pelo_operador,
        procedimentos_adotados=procedimentos_adotados or None,
        data_solucao=data_solucao or None,
        hora_solucao=hora_solucao or None,
        responsavel_evento=responsavel_evento,
        atualizado_por=user_id,
    )

    # 5) Inserção / atualização transacional
    with transaction.atomic():
        if anom_id is not None:
            db.update_registro_anormalidade(anom_id=anom_id, **params)
            registro_anom_id = anom_id
        else:
            registro_anom_id = db.insert_registro_anormalidade(
                registro_id=registro_id,
                criado_por=user_id,
                entrada_id=entrada_id,
                **params,
            )

    return RegistroAnormalidadeResult(
        registro_anormalidade_id=int(registro_anom_id),
        registro_id=registro_id,
    )
