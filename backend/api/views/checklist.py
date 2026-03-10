from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from ..utils import json_error, parse_json_body
from ..auth import jwt_required
from .. import db
from ..services.checklist_service import (
    registrar_checklist,
    editar_checklist,
    ChecklistResult,
    ChecklistEditResult,
    ServiceValidationError,
)

def _read_field(request: HttpRequest, key: str) -> str:
    """
    Lê um campo do request, aceitando tanto JSON quanto formulário.
    Mantém o comportamento usado nas outras views.
    """
    if request.content_type and "application/json" in request.content_type:
        data = parse_json_body(request)
        val = data.get(key, "")
    else:
        val = request.POST.get(key, "") or request.GET.get(key, "")
    return (val or "").strip()

@csrf_exempt
@jwt_required
def checklist_registro_view(request: HttpRequest):
    """
    Recebe o POST do formulário 'Testes Diários' (checklist) e
    delega a lógica de negócio para o service registrar_checklist.
    """
    try:
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        # 1) Monta o payload a partir da requisição
        if request.content_type and "application/json" in request.content_type:
            # Front-end atual envia JSON (Content-Type: application/json)
            body = parse_json_body(request)
        else:
            # Fallback: monta a partir de campos de formulário (pouco usado)
            def _rf(name: str) -> str:
                return _read_field(request, name)  # usa o helper local

            body = {
                "data_operacao": _rf("data_operacao") or None,
                "sala_id": _rf("sala_id") or None,
                "turno": _rf("turno") or None,
                "hora_inicio_testes": _rf("hora_inicio_testes") or None,
                "hora_termino_testes": _rf("hora_termino_testes") or None,
                "usb_01": _rf("usb_01") or None,
                "usb_02": _rf("usb_02") or None,
                "observacoes": _rf("observacoes") or None,
                # Sem suporte sofisticado para itens via form; cenário real usa JSON
                "itens": [],
            }

        # 2) Usuário autenticado (criado_por / atualizado_por)
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        # 3) Chama o service
        try:
            result = registrar_checklist(payload=body, user_id=user_id)
        except ServiceValidationError as e:
            # Erro de validação → HTTP 400, com mensagem e detalhes
            payload_erro = {
                "ok": False,
                "code": e.code,
                "message": e.message,
            }
            if e.extra:
                payload_erro["extra"] = e.extra
            return JsonResponse(payload_erro, status=400)

        # 4) Sucesso → mantém contrato simples (front só olha resp.ok)
        return JsonResponse(
            {
                "ok": True,
                "checklist_id": result.checklist_id,
                "total_respostas": result.total_respostas,
            },
            status=201,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {
                "ok": False,
                "error": f"internal_error: {e.__class__.__name__}: {e}",
            },
            status=500,
        )

@csrf_exempt
def checklist_itens_tipo_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    sala_id = request.GET.get("sala_id")
    if not sala_id:
        return JsonResponse({"ok": False, "error": "sala_id_required"}, status=400)

    try:
        # Agora busca específico da sala
        rows = db.checklist.list_checklist_itens_por_sala(int(sala_id))
        return JsonResponse({"ok": True, "data": rows})
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


@csrf_exempt
@jwt_required
def checklist_editar_view(request: HttpRequest):
    """
    PUT /webhook/forms/checklist/editar
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

        # Usuário autenticado
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        # Verificação de ownership: só quem criou pode editar
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(
                "SELECT criado_por FROM forms.checklist WHERE id = %s::bigint",
                [int(checklist_id)],
            )
            row = cur.fetchone()

        if not row:
            return JsonResponse(
                {"ok": False, "error": "not_found"}, status=404
            )
        if str(row[0]) != str(user_id):
            return JsonResponse(
                {"ok": False, "error": "forbidden"}, status=403
            )

        # Chama o service
        try:
            result = editar_checklist(
                checklist_id=int(checklist_id),
                payload=body,
                user_id=user_id,
            )
        except ServiceValidationError as e:
            payload_erro = {
                "ok": False,
                "code": e.code,
                "message": e.message,
            }
            if e.extra:
                payload_erro["extra"] = e.extra
            return JsonResponse(payload_erro, status=400)

        return JsonResponse({
            "ok": True,
            "checklist_id": result.checklist_id,
            "total_respostas_atualizadas": result.total_respostas_atualizadas,
        })

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e.__class__.__name__}: {e}"},
            status=500,
        )