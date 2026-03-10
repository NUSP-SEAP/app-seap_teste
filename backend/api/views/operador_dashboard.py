import traceback

from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from ..utils import json_error
from ..auth import jwt_required
from ..db import admin_dashboard
from api.services import report_pdf_service
from api.services import report_service


def _get_list_params(request: HttpRequest):
    try:
        page = int(request.GET.get("page", 1))
        limit = int(request.GET.get("limit", 10))
        if page < 1:
            page = 1
        if limit < 1:
            limit = 10
        if limit > 100:
            limit = 100
    except ValueError:
        page, limit = 1, 10

    sort = request.GET.get("sort", "").strip()
    direction = request.GET.get("dir", "desc").strip().lower()

    return page, limit, sort, direction


def _get_filters_param(request: HttpRequest):
    import json
    raw = request.GET.get("filters")
    if not raw:
        return None
    try:
        value = json.loads(raw)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def _fetch_all_pages_meus(fetch_fn, *, limit: int = 200, **kwargs):
    offset = 0
    all_rows = []

    while True:
        rows, total, _distinct = fetch_fn(limit=limit, offset=offset, **kwargs)
        if not rows:
            break
        all_rows.extend(rows)
        if total is not None and len(all_rows) >= total:
            break
        if len(rows) < limit:
            break
        offset += limit

    return all_rows


@csrf_exempt
@jwt_required
def meus_checklists_view(request: HttpRequest):
    """
    GET /webhook/operador/meus-checklists
    Lista checklists do operador logado, com contagens OK/Falha.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    page, limit, sort, direction = _get_list_params(request)
    offset = (page - 1) * limit
    filters = _get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_meus_checklists(
            user_id=user_id,
            limit=limit,
            offset=offset,
            sort=sort,
            direction=direction,
            filters=filters,
        )

        return JsonResponse({
            "ok": True,
            "data": data,
            "meta": {
                "distinct": distinct,
                "page": page,
                "limit": limit,
                "total": total,
                "pages": max(1, (total + limit - 1) // limit),
            }
        })
    except Exception as e:
        traceback.print_exc()
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


@csrf_exempt
@jwt_required
def meus_checklists_relatorio_view(request: HttpRequest):
    """
    GET /webhook/operador/meus-checklists/relatorio?format=pdf
    Gera relatório PDF dos checklists do operador logado.
    Colunas: Sala, Data, Qtde. OK, Qtde. Falha
    """
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    _page, _limit, sort, direction = _get_list_params(request)
    filters = _get_filters_param(request)

    try:
        rows = _fetch_all_pages_meus(
            admin_dashboard.list_meus_checklists,
            user_id=user_id,
            sort=sort,
            direction=direction,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_verificacao_salas",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_meus_checklists(rows),
            docx_builder=None,
            pdf_inline=True,
        )

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e}"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


@csrf_exempt
@jwt_required
def meu_checklist_detalhe_view(request: HttpRequest):
    """
    GET /webhook/operador/checklist/detalhe?checklist_id=<id>
    Retorna detalhe de um checklist, verificando que pertence ao operador logado.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    checklist_id = request.GET.get("checklist_id")
    if not checklist_id:
        return JsonResponse({"ok": False, "error": "checklist_id obrigatório"}, status=400)

    try:
        data = admin_dashboard.get_checklist_detalhe(int(checklist_id))
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)

        # Verifica que o checklist pertence ao operador logado
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(
                "SELECT criado_por FROM forms.checklist WHERE id = %s::bigint",
                [int(checklist_id)],
            )
            row = cur.fetchone()

        if not row or str(row[0]) != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        traceback.print_exc()
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


# =====================================================================
# Operações de Áudio do Operador
# =====================================================================

@csrf_exempt
@jwt_required
def minhas_operacoes_view(request: HttpRequest):
    """
    GET /webhook/operador/minhas-operacoes
    Lista entradas de operação de áudio do operador logado.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    page, limit, sort, direction = _get_list_params(request)
    offset = (page - 1) * limit
    filters = _get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_minhas_operacoes(
            user_id=user_id,
            limit=limit,
            offset=offset,
            sort=sort,
            direction=direction,
            filters=filters,
        )

        return JsonResponse({
            "ok": True,
            "data": data,
            "meta": {
                "distinct": distinct,
                "page": page,
                "limit": limit,
                "total": total,
                "pages": max(1, (total + limit - 1) // limit),
            }
        })
    except Exception as e:
        traceback.print_exc()
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


@csrf_exempt
@jwt_required
def minhas_operacoes_relatorio_view(request: HttpRequest):
    """
    GET /webhook/operador/minhas-operacoes/relatorio?format=pdf
    Gera relatório PDF das operações de áudio do operador logado.
    Colunas: Sala, Data, Pauta, Início, Fim, Anormalidade?
    """
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    _page, _limit, sort, direction = _get_list_params(request)
    filters = _get_filters_param(request)

    try:
        rows = _fetch_all_pages_meus(
            admin_dashboard.list_minhas_operacoes,
            user_id=user_id,
            sort=sort,
            direction=direction,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_operacoes_audio",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_minhas_operacoes(rows),
            docx_builder=None,
            pdf_inline=True,
        )

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e}"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


@csrf_exempt
@jwt_required
def minha_operacao_detalhe_view(request: HttpRequest):
    """
    GET /webhook/operador/operacao/detalhe?entrada_id=<id>
    Retorna detalhe de uma entrada de operação, verificando pertencimento.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    entrada_id = request.GET.get("entrada_id")
    if not entrada_id:
        return JsonResponse({"ok": False, "error": "entrada_id obrigatório"}, status=400)

    try:
        data = admin_dashboard.get_entrada_operacao_detalhe(int(entrada_id))
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)

        # Verifica que a entrada pertence ao operador logado
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(
                "SELECT operador_id FROM operacao.registro_operacao_operador WHERE id = %s::bigint",
                [int(entrada_id)],
            )
            row = cur.fetchone()

        if not row or str(row[0]) != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        traceback.print_exc()
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


@csrf_exempt
@jwt_required
def minha_anormalidade_detalhe_view(request: HttpRequest):
    """
    GET /webhook/operador/anormalidade/detalhe?id=<id>
    Retorna detalhe de uma anormalidade, verificando pertencimento.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    user = getattr(request, "auth_user", None)
    if not user:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    user_id = user.get("id")
    if not user_id:
        return JsonResponse({"ok": False, "error": "unauthorized"}, status=401)

    anom_id = request.GET.get("id")
    if not anom_id:
        return JsonResponse({"ok": False, "error": "id obrigatório"}, status=400)

    try:
        data = admin_dashboard.get_anormalidade_detalhe(int(anom_id))
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)

        # Verifica que a anormalidade pertence ao operador logado
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(
                "SELECT criado_por FROM operacao.registro_anormalidade WHERE id = %s::bigint",
                [int(anom_id)],
            )
            row = cur.fetchone()

        if not row or str(row[0]) != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        traceback.print_exc()
        return JsonResponse({"ok": False, "error": str(e)}, status=500)
