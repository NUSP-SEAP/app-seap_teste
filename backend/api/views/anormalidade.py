import logging

from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from ..utils import json_error, parse_json_body, get_user_id_or_error, service_error_response
from ..auth import jwt_required
from .. import db

from ..services.anormalidade_service import (
    registrar_anormalidade,
    ServiceValidationError,
)

logger = logging.getLogger(__name__)


@csrf_exempt
@jwt_required
def registro_anormalidade_view(request: HttpRequest):
    """
    Endpoint do 'Registro de Anormalidade na Operação de Áudio'.

    - GET  /operacao/anormalidade/registro?entrada_id=...
        → Busca o RAOA da entrada (usado para edição).
    - POST /operacao/anormalidade/registro
        → Cria ou atualiza o RAOA, delegando ao service.
    """
    try:
        user_id, err = get_user_id_or_error(request)
        if err:
            return err

        # GET: retorna RAOA por entrada_id (para edição)
        if request.method == "GET":
            entrada_id_raw = (request.GET.get("entrada_id") or "").strip()
            if not entrada_id_raw:
                return JsonResponse(
                    {"ok": False, "error": "missing_param", "detail": "entrada_id é obrigatório"},
                    status=400,
                )

            try:
                entrada_id = int(entrada_id_raw)
            except ValueError:
                return JsonResponse(
                    {"ok": False, "error": "invalid_param", "detail": "entrada_id inválido"},
                    status=400,
                )

            anom = db.get_registro_anormalidade_por_entrada(entrada_id)
            if not anom:
                return JsonResponse({"ok": False, "error": "not_found"}, status=404)

            return JsonResponse({"ok": True, "data": anom}, status=200)

        # Demais métodos: apenas POST é aceito
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        # Frontend envia FormData (multipart/form-data), não JSON
        if request.content_type and "application/json" in request.content_type:
            body = parse_json_body(request) or {}
        else:
            body = request.POST.dict()

        try:
            result = registrar_anormalidade(payload=body, user_id=user_id)
        except ServiceValidationError as e:
            return service_error_response(e)

        return JsonResponse(
            {
                "ok": True,
                "registro_anormalidade_id": result.registro_anormalidade_id,
                "registro_id": result.registro_id,
            },
            status=201,
        )

    except Exception:
        logger.exception("Erro em registro_anormalidade_view")
        return json_error(500, {"ok": False, "error": "internal_error"})
