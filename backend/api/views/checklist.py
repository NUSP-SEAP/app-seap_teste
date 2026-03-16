import logging

from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from ..utils import json_error, parse_json_body, get_user_id_or_error, service_error_response
from ..auth import jwt_required
from .. import db
from ..services.checklist_service import (
    registrar_checklist,
    editar_checklist,
    ChecklistResult,
    ChecklistEditResult,
    ServiceValidationError,
)

logger = logging.getLogger(__name__)


@csrf_exempt
@require_POST
@jwt_required
def checklist_registro_view(request: HttpRequest):
    """
    POST /api/forms/checklist/registro
    Recebe o formulário 'Testes Diários' (checklist) e
    delega a lógica de negócio para o service registrar_checklist.
    """
    try:
        body = parse_json_body(request)

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        try:
            result = registrar_checklist(payload=body, user_id=user_id)
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse(
            {
                "ok": True,
                "checklist_id": result.checklist_id,
                "total_respostas": result.total_respostas,
            },
            status=201,
        )

    except Exception:
        logger.exception("Erro em checklist_registro_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@require_GET
def checklist_itens_tipo_view(request: HttpRequest):
    sala_id = request.GET.get("sala_id")
    if not sala_id:
        return JsonResponse({"ok": False, "error": "sala_id_required"}, status=400)

    try:
        rows = db.checklist.list_checklist_itens_por_sala(int(sala_id))
        return JsonResponse({"ok": True, "data": rows})
    except Exception:
        logger.exception("Erro em checklist_itens_tipo_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@csrf_exempt
@jwt_required
def checklist_editar_view(request: HttpRequest):
    """
    PUT /api/forms/checklist/editar
    Edita um checklist existente, com verificação de ownership.
    """
    try:
        if request.method != "PUT":
            return json_error(405, {"error": "method_not_allowed"})

        body = parse_json_body(request)
        checklist_id = body.get("checklist_id")
        if not checklist_id:
            return JsonResponse(
                {"ok": False, "error": "checklist_id obrigatório"}, status=400
            )

        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        owner = db.get_owner_id("forms.checklist", "criado_por", int(checklist_id))
        if owner is None:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        if owner != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        try:
            result = editar_checklist(
                checklist_id=int(checklist_id),
                payload=body,
                user_id=user_id,
            )
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse({
            "ok": True,
            "checklist_id": result.checklist_id,
            "total_respostas_atualizadas": result.total_respostas_atualizadas,
        })

    except Exception:
        logger.exception("Erro em checklist_editar_view")
        return json_error(500, {"ok": False, "error": "internal_error"})
