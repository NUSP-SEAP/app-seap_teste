import logging

from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from ..utils import (
    json_error,
    parse_json_body,
    read_field,
    get_user_id_or_error,
    service_error_response,
    parse_sala_id,
)
from ..auth import jwt_required
from .. import db

from ..services.operacao_service import (
    registrar_operacao_audio,
    ServiceValidationError,
    RegistroOperacaoAudioResult,
    obter_estado_sessao_para_operador,
    salvar_entrada_operacao_audio,
    finalizar_sessao_operacao_audio,
    editar_entrada_operacao,
)

logger = logging.getLogger(__name__)


def _require_json(request):
    """Retorna JsonResponse de erro se Content-Type não for JSON, ou None se ok."""
    if not (request.content_type and "application/json" in request.content_type):
        return JsonResponse(
            {"ok": False, "error": "Content-Type deve ser 'application/json'."},
            status=400,
        )
    return None


@csrf_exempt
@require_GET
@jwt_required
def estado_sessao_operacao_audio_view(request: HttpRequest):
    """
    GET /api/operacao/audio/estado-sessao?sala_id=...
    Lookup do estado da sessão de operação de áudio para uma sala + operador.
    """
    try:
        sala_id = parse_sala_id(request.GET.get("sala_id"))
        if not sala_id:
            return JsonResponse(
                {"ok": False, "error": "sala_id inválido ou ausente."},
                status=400,
            )

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        try:
            estado = obter_estado_sessao_para_operador(
                sala_id=sala_id,
                operador_id=str(user_id),
            )
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse({"ok": True, "data": estado}, status=200)

    except Exception:
        logger.exception("Erro em estado_sessao_operacao_audio_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@require_POST
@jwt_required
def salvar_entrada_operacao_audio_view(request: HttpRequest):
    """
    POST /api/operacao/audio/salvar-entrada
    Cria/edita uma ENTRADA de operação de áudio para o operador autenticado.
    """
    try:
        json_err = _require_json(request)
        if json_err:
            return json_err

        body = parse_json_body(request) or {}

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        try:
            result = salvar_entrada_operacao_audio(payload=body, user_id=str(user_id))
        except ServiceValidationError as e:
            return service_error_response(e)

        is_edicao = bool(result.get("is_edicao"))
        status_code = 200 if is_edicao else 201

        payload_ok = {"ok": True}
        payload_ok.update(result)
        return JsonResponse(payload_ok, status=status_code)

    except Exception:
        logger.exception("Erro em salvar_entrada_operacao_audio_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@require_POST
@jwt_required
def finalizar_sessao_operacao_audio_view(request: HttpRequest):
    """
    POST /api/operacao/audio/finalizar-sessao
    Finaliza/encerra a sessão de operação de áudio de uma sala.
    """
    try:
        json_err = _require_json(request)
        if json_err:
            return json_err

        body = parse_json_body(request) or {}
        sala_id = parse_sala_id(body.get("sala_id"))
        if not sala_id:
            return JsonResponse(
                {"ok": False, "error": "sala_id inválido ou ausente."},
                status=400,
            )

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        try:
            result = finalizar_sessao_operacao_audio(sala_id=sala_id, user_id=str(user_id))
        except ServiceValidationError as e:
            return service_error_response(e)

        payload_ok = {"ok": True}
        if isinstance(result, dict):
            payload_ok.update(result)

        return JsonResponse(payload_ok, status=200)

    except Exception:
        logger.exception("Erro em finalizar_sessao_operacao_audio_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@require_GET
@jwt_required
def lookup_registro_operacao_view(request: HttpRequest):
    """
    GET /api/forms/lookup/registro-operacao?id=123&entrada_id=456
    Retorna dados básicos de um registro de operação para pré-preenchimento
    da tela de anormalidade.
    """
    try:
        rid_raw = request.GET.get("id") or request.GET.get("registro_id")
        if not rid_raw:
            return JsonResponse(
                {"ok": False, "error": "Parâmetro 'id' é obrigatório."},
                status=400,
            )

        try:
            registro_id = int(rid_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "error": "ID inválido."},
                status=400,
            )

        entrada_id = None
        entrada_raw = request.GET.get("entrada_id") or request.GET.get("entrada")
        if entrada_raw:
            try:
                entrada_id = int(entrada_raw)
            except (TypeError, ValueError):
                return JsonResponse(
                    {"ok": False, "error": "entrada_id inválido."},
                    status=400,
                )

        row = db.get_registro_operacao_audio_for_anormalidade(
            registro_id=registro_id,
            entrada_id=entrada_id,
        )
        if not row:
            return JsonResponse(
                {"ok": False, "error": "not_found", "detail": "Registro não encontrado."},
                status=404,
            )

        return JsonResponse({"ok": True, "data": row}, status=200)

    except Exception:
        logger.exception("Erro em lookup_registro_operacao_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@require_POST
@jwt_required
def registro_operacao_audio_view(request: HttpRequest):
    """
    POST /api/operacao/registro
    Endpoint original de cadastro do formulário "Registro de Operação de Áudio".
    Recebe dados via formulário (POST/multipart ou x-www-form-urlencoded).
    """
    try:
        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        # Leitura dos operadores (contrato do formulário)
        operadores = [
            op for op in [
                read_field(request, "operador_1"),
                read_field(request, "operador_2"),
                read_field(request, "operador_3"),
            ] if op
        ]

        payload = {
            "data_operacao": read_field(request, "data_operacao"),
            "horario_pauta": read_field(request, "horario_pauta"),
            "hora_inicio": read_field(request, "hora_inicio"),
            "hora_fim": read_field(request, "hora_fim"),
            "sala_id": read_field(request, "sala_id"),
            "nome_evento": read_field(request, "nome_evento"),
            "observacoes": read_field(request, "observacoes"),
            "usb_01": read_field(request, "usb_01"),
            "usb_02": read_field(request, "usb_02"),
            "houve_anormalidade": read_field(request, "houve_anormalidade") or "nao",
            "operadores": operadores,
        }

        try:
            result: RegistroOperacaoAudioResult = registrar_operacao_audio(
                payload=payload,
                user_id=str(user_id),
            )
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse(
            {
                "ok": True,
                "registro_id": result.registro_id,
                "houve_anormalidade": result.houve_anormalidade,
            },
            status=201,
        )

    except Exception:
        logger.exception("Erro em registro_operacao_audio_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@jwt_required
def entrada_operacao_editar_view(request: HttpRequest):
    """
    PUT /api/operacao/audio/editar-entrada
    Edita uma entrada de operador existente, com verificação de ownership.
    """
    try:
        if request.method != "PUT":
            return json_error(405, {"error": "method_not_allowed"})

        body = parse_json_body(request)
        entrada_id_raw = body.get("entrada_id")
        if not entrada_id_raw:
            return JsonResponse(
                {"ok": False, "error": "entrada_id obrigatório"}, status=400
            )

        try:
            entrada_id = int(entrada_id_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "error": "entrada_id inválido"}, status=400
            )

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        operador_id_owner = db.get_operador_id_by_entrada(entrada_id)
        if not operador_id_owner:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        if operador_id_owner != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        try:
            result = editar_entrada_operacao(
                entrada_id=entrada_id,
                payload=body,
                user_id=str(user_id),
            )
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse({
            "ok": True,
            "entrada_id": result.entrada_id,
            "registro_id": result.registro_id,
            "houve_anormalidade_nova": result.houve_anormalidade_nova,
        })

    except Exception:
        logger.exception("Erro em entrada_operacao_editar_view")
        return json_error(500, {"ok": False, "error": "internal_error"})
