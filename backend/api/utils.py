"""
Utilitários compartilhados entre as views da API.

Funções centralizadas que substituem helpers duplicados em
views/admin.py, views/operador_dashboard.py, views/operacao.py, etc.
"""

import json
import logging

from django.http import JsonResponse

logger = logging.getLogger(__name__)


# ── Resposta de erro ──────────────────────────────────────────────

def json_error(status: int, data: dict):
    resp = JsonResponse(data)
    resp.status_code = status
    return resp


# ── Parse de body ─────────────────────────────────────────────────

def parse_json_body(request):
    try:
        if request.body:
            return json.loads(request.body.decode('utf-8'))
    except Exception:
        pass
    return {}


# ── Leitura de campo ──────────────────────────────────────────────

def read_field(request, key, default=""):
    """
    Lê campo de body JSON ou form-data.
    Substitui _read_field duplicada em 4+ views.
    """
    if request.content_type and "application/json" in request.content_type:
        data = parse_json_body(request)
        val = data.get(key, default)
    else:
        val = request.POST.get(key, default) or request.GET.get(key, default)
    return (val or "").strip()


# ── User ID ───────────────────────────────────────────────────────

def get_user_id_or_error(request):
    """
    Extrai user_id do request.auth_user.
    Retorna (user_id, None) em sucesso ou (None, JsonResponse) em falha.
    """
    auth_user = getattr(request, "auth_user", None)
    if not auth_user or not isinstance(auth_user, dict):
        return None, json_error(401, {"error": "not_authenticated"})
    user_id = auth_user.get("id")
    if not user_id:
        return None, json_error(401, {"error": "not_authenticated"})
    return user_id, None


# ── ServiceValidationError → JsonResponse ─────────────────────────

def service_error_response(e):
    """
    Converte ServiceValidationError em JsonResponse padronizado.
    Inclui 'errors' (validação por campo) e 'extra' se presentes.
    """
    body = {
        "ok": False,
        "error": getattr(e, "code", "validation_error"),
        "message": getattr(e, "message", str(e)),
    }
    extra = getattr(e, "extra", None)
    if extra:
        body.update(extra)
    errors = getattr(e, "errors", None)
    if errors:
        body["errors"] = errors
    return json_error(400, body)


# ── Parâmetros de listagem ────────────────────────────────────────

def get_list_params(request, *, include_search=True, default_dir="asc"):
    """
    Extrai page/limit/sort/direction/search da query string.
    Substitui versões em admin.py e operador_dashboard.py.
    """
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

    search = request.GET.get("search", "").strip() if include_search else ""
    sort = request.GET.get("sort", "").strip()
    direction = request.GET.get("dir", default_dir).strip().lower()

    return page, limit, search, sort, direction


def get_periodo_param(request):
    """Lê o parâmetro ?periodo= (JSON) e devolve um dict ou None."""
    raw = request.GET.get("periodo")
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None


def get_filters_param(request):
    """Lê o parâmetro ?filters= (JSON) e devolve um dict ou None."""
    raw = request.GET.get("filters")
    if not raw:
        return None
    try:
        value = json.loads(raw)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


# ── Fetch all pages ───────────────────────────────────────────────

def fetch_all_pages(fetch_fn, *, limit=200, **kwargs):
    """Busca todos os registros sem paginação. Usada para relatórios."""
    offset = 0
    all_rows = []
    total = None

    while True:
        rows, total, _distinct = fetch_fn(limit=limit, offset=offset, **kwargs)
        if not rows:
            break

        all_rows.extend(rows)

        if total is not None:
            if len(all_rows) >= total:
                break
        else:
            if len(rows) < limit:
                break

        offset += limit

    return all_rows


# ── Parse sala_id ─────────────────────────────────────────────────

def parse_sala_id(raw):
    """Valida e converte sala_id. Retorna int ou None."""
    if raw is None:
        return None
    try:
        val = int(str(raw).strip())
        return val if val > 0 else None
    except (TypeError, ValueError):
        return None
