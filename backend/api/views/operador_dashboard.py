import logging

from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET

from ..utils import json_error, get_list_params, get_filters_param, fetch_all_pages
from ..auth import jwt_required
from .. import db
from ..db import dashboard_home, dashboard_checklists, dashboard_operacoes, dashboard_anormalidades
from api.services import report_pdf_service
from api.services import report_service

logger = logging.getLogger(__name__)


# ── Helpers genéricos ──────────────────────────────────────────────

def _get_user_id(request):
    """Extrai user_id do auth_user. Retorna (user_id, err_response)."""
    user = getattr(request, "auth_user", None)
    if not user:
        return None, JsonResponse({"ok": False, "error": "unauthorized"}, status=401)
    user_id = user.get("id")
    if not user_id:
        return None, JsonResponse({"ok": False, "error": "unauthorized"}, status=401)
    return user_id, None


def _meus_list_view(request, fetch_fn):
    """View genérica de listagem paginada para o operador logado."""
    user_id, err = _get_user_id(request)
    if err:
        return err

    page, limit, _search, sort, direction = get_list_params(request, include_search=False, default_dir="desc")
    offset = (page - 1) * limit
    filters = get_filters_param(request)

    try:
        data, total, distinct = fetch_fn(
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
    except Exception:
        logger.exception("Erro em _meus_list_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


def _meus_relatorio_view(request, fetch_fn, pdf_builder, filename_base):
    """View genérica de relatório PDF para o operador logado."""
    user_id, err = _get_user_id(request)
    if err:
        return err

    _page, _limit, _search, sort, direction = get_list_params(request, include_search=False, default_dir="desc")
    filters = get_filters_param(request)

    try:
        rows = fetch_all_pages(
            fetch_fn,
            user_id=user_id,
            sort=sort,
            direction=direction,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base=filename_base,
            pdf_builder=lambda: pdf_builder(rows),
            docx_builder=None,
            pdf_inline=True,
        )

    except Exception:
        logger.exception("Erro em _meus_relatorio_view")
        return JsonResponse(
            {"ok": False, "error": "internal_error"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


def _meu_detalhe_view(request, param_name, fetch_fn, table, column):
    """View genérica de detalhe com verificação de ownership."""
    user_id, err = _get_user_id(request)
    if err:
        return err

    record_id = request.GET.get(param_name)
    if not record_id:
        return JsonResponse({"ok": False, "error": f"{param_name} obrigatório"}, status=400)

    try:
        data = fetch_fn(int(record_id))
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)

        owner = db.get_owner_id(table, column, int(record_id))
        if not owner or owner != str(user_id):
            return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

        return JsonResponse({"ok": True, "data": data})
    except Exception:
        logger.exception("Erro em _meu_detalhe_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


# ── Checklists ─────────────────────────────────────────────────────

@csrf_exempt
@require_GET
@jwt_required
def meus_checklists_view(request: HttpRequest):
    """GET /api/operador/meus-checklists"""
    return _meus_list_view(request, dashboard_home.list_meus_checklists)


@csrf_exempt
@require_GET
@jwt_required
def meus_checklists_relatorio_view(request: HttpRequest):
    """GET /api/operador/meus-checklists/relatorio?format=pdf"""
    return _meus_relatorio_view(
        request,
        fetch_fn=dashboard_home.list_meus_checklists,
        pdf_builder=report_pdf_service.gerar_relatorio_meus_checklists,
        filename_base="relatorio_verificacao_salas",
    )


@csrf_exempt
@require_GET
@jwt_required
def meu_checklist_detalhe_view(request: HttpRequest):
    """GET /api/operador/checklist/detalhe?checklist_id=<id>"""
    return _meu_detalhe_view(
        request,
        param_name="checklist_id",
        fetch_fn=dashboard_checklists.get_checklist_detalhe,
        table="forms.checklist",
        column="criado_por",
    )


# ── Operações de Áudio ────────────────────────────────────────────

@csrf_exempt
@require_GET
@jwt_required
def minhas_operacoes_view(request: HttpRequest):
    """GET /api/operador/minhas-operacoes"""
    return _meus_list_view(request, dashboard_home.list_minhas_operacoes)


@csrf_exempt
@require_GET
@jwt_required
def minhas_operacoes_relatorio_view(request: HttpRequest):
    """GET /api/operador/minhas-operacoes/relatorio?format=pdf"""
    return _meus_relatorio_view(
        request,
        fetch_fn=dashboard_home.list_minhas_operacoes,
        pdf_builder=report_pdf_service.gerar_relatorio_minhas_operacoes,
        filename_base="relatorio_operacoes_audio",
    )


@csrf_exempt
@require_GET
@jwt_required
def minha_operacao_detalhe_view(request: HttpRequest):
    """GET /api/operador/operacao/detalhe?entrada_id=<id>"""
    return _meu_detalhe_view(
        request,
        param_name="entrada_id",
        fetch_fn=dashboard_operacoes.get_entrada_operacao_detalhe,
        table="operacao.registro_operacao_operador",
        column="operador_id",
    )


@csrf_exempt
@require_GET
@jwt_required
def minha_anormalidade_detalhe_view(request: HttpRequest):
    """GET /api/operador/anormalidade/detalhe?id=<id>"""
    return _meu_detalhe_view(
        request,
        param_name="id",
        fetch_fn=dashboard_anormalidades.get_anormalidade_detalhe,
        table="operacao.registro_anormalidade",
        column="criado_por",
    )
