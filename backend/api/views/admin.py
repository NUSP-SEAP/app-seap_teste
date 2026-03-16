import logging
import os

import bcrypt

from django.conf import settings
from django.http import HttpRequest, JsonResponse, HttpResponse
from django.views.decorators.http import require_GET, require_POST

from ..utils import (
    json_error,
    parse_json_body,
    read_field,
    get_list_params,
    get_periodo_param,
    get_filters_param,
    fetch_all_pages,
    parse_sala_id,
)
from ..auth import admin_view
from .. import db
from ..db import (
    dashboard_operadores,
    dashboard_checklists,
    dashboard_operacoes,
    dashboard_anormalidades,
)
from ..db import form_edit as form_edit_db
from ..db import rds as rds_db
from api.services import report_pdf_service
from api.services import report_docx_service
from api.services import rds_xlsx_service
from api.services import report_service

logger = logging.getLogger(__name__)

# Permissões específicas para observações de anormalidade
SUPERVISOR_USERNAME = "emanoel"
SUPERVISOR_EMAIL = "emanoel@senado.leg.br"

CHEFE_SERVICO_USERNAME = "evandrop"
CHEFE_SERVICO_EMAIL = "evandrop@senado.leg.br"


# ── Helpers de upload ────────────────────────────────────────────

def _first_file(request: HttpRequest, keys=('foto', 'foto0', 'file', 'image', 'upload')):
    for k in keys:
        if k in request.FILES:
            return request.FILES[k]
    if request.FILES:
        return list(request.FILES.values())[0]
    return None


def _ext_from_filename_or_content(f):
    name = getattr(f, "name", "") or ""
    if "." in name:
        return name.split(".")[-1].lower()
    ctype = getattr(f, "content_type", "") or ""
    if "/" in ctype:
        return ctype.split("/")[-1].lower()
    return "jpg"


# ── Helpers genéricos de views admin ─────────────────────────────

def _admin_list_view(request, fetch_fn, *, include_periodo=True, **extra_kwargs):
    """View genérica de listagem paginada para admin."""
    page, limit, search, sort, direction = get_list_params(request)
    offset = (page - 1) * limit
    filters = get_filters_param(request)

    kwargs = dict(
        limit=limit, offset=offset, search=search,
        sort=sort, direction=direction, filters=filters,
    )
    if include_periodo:
        kwargs["periodo"] = get_periodo_param(request)
    kwargs.update(extra_kwargs)

    try:
        data, total, distinct = fetch_fn(**kwargs)
        return JsonResponse({
            "ok": True,
            "data": data,
            "meta": {
                "distinct": distinct,
                "page": page,
                "limit": limit,
                "total": total,
                "pages": (total + limit - 1) // limit,
            }
        })
    except Exception:
        logger.exception("Erro em _admin_list_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


def _admin_relatorio_view(
    request, fetch_fn, filename_base, pdf_builder, docx_builder,
    *, include_periodo=True, **extra_fetch_kwargs
):
    """View genérica de relatório (PDF/DOCX) para admin."""
    _page, _limit, search, sort, direction = get_list_params(request)
    filters = get_filters_param(request)

    kwargs = dict(search=search, sort=sort, direction=direction, filters=filters)
    if include_periodo:
        kwargs["periodo"] = get_periodo_param(request)
    kwargs.update(extra_fetch_kwargs)

    try:
        rows = fetch_all_pages(fetch_fn, **kwargs)

        return report_service.respond(
            request,
            filename_base=filename_base,
            pdf_builder=lambda: pdf_builder(rows),
            docx_builder=lambda: docx_builder(rows),
            pdf_inline=True,
        )
    except Exception:
        logger.exception("Erro ao gerar relatório")
        return JsonResponse(
            {"ok": False, "error": "internal_error"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


def _observacao_view(request, *, allowed_username, allowed_email, db_fn):
    """View genérica para salvar observação (supervisor ou chefe) em anormalidade."""
    body = parse_json_body(request)
    anom_id_raw = body.get("id")
    observacao = (body.get("observacao") or "").strip()

    if not anom_id_raw:
        return JsonResponse({"ok": False, "error": "id_obrigatorio"}, status=400)

    try:
        anom_id = int(anom_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({"ok": False, "error": "id_invalido"}, status=400)

    if not observacao:
        return JsonResponse({"ok": False, "error": "observacao_obrigatoria"}, status=400)

    auth_user = getattr(request, "auth_user", {}) or {}
    username = (auth_user.get("username") or "").lower()
    email = (auth_user.get("email") or "").lower()
    user_id = auth_user.get("id")

    if not user_id:
        return JsonResponse({"ok": False, "error": "user_id_missing"}, status=500)

    if username != allowed_username or email != allowed_email:
        return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

    try:
        db_fn(anom_id, observacao, user_id)
        return JsonResponse({"ok": True})
    except ValueError as e:
        return JsonResponse(
            {"ok": False, "error": "validation_error", "message": str(e)},
            status=400,
        )
    except Exception:
        logger.exception("Erro em _observacao_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


# ── Cadastro de operador / administrador ─────────────────────────

@admin_view
@require_POST
def admin_operador_novo(request: HttpRequest):
    nome_completo = read_field(request, "nome_completo")
    nome_exibicao = read_field(request, "nome_exibicao")
    email = read_field(request, "email").lower()
    username = read_field(request, "username").lower()
    senha = read_field(request, "senha")

    faltantes = []
    if not nome_completo:  faltantes.append("nome_completo")
    if not nome_exibicao:  faltantes.append("nome_exibicao")
    if not email:          faltantes.append("email")
    if not username:       faltantes.append("username")
    if not senha:          faltantes.append("senha")
    if faltantes:
        return JsonResponse({"ok": False, "error": "invalid_payload", "missing": ", ".join(faltantes)}, status=400)

    email_exists = db.exists_user("pessoa.operador", "email", email)
    username_exists = db.exists_user("pessoa.operador", "username", username)
    if email_exists or username_exists:
        msg = (
            "E-mail e usuário já cadastrados" if (email_exists and username_exists)
            else ("E-mail já cadastrado" if email_exists else "Nome de usuário já cadastrado")
        )
        return JsonResponse({"ok": False, "error": "conflict", "message": msg}, status=409)

    foto = _first_file(request)
    foto_url = ""
    if foto:
        ext = _ext_from_filename_or_content(foto)
        from django.utils.timezone import now
        ts = int(now().timestamp() * 1000)
        filename = f"{username or 'sem_username'}_{ts}.{ext}"
        foto_url = settings.FILES_URL_PREFIX.rstrip("/") + "/" + settings.OPERADORES_DIRNAME + "/" + filename
        save_dir = os.path.join(settings.FILES_DIR, settings.OPERADORES_DIRNAME)
        os.makedirs(save_dir, exist_ok=True)
        with open(os.path.join(save_dir, filename), "wb") as fh:
            for chunk in foto.chunks():
                fh.write(chunk)

    hashed = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    op = db.insert_operador(
        nome_completo=nome_completo,
        nome_exibicao=nome_exibicao,
        email=email,
        username=username,
        password_hash=hashed,
        foto_url=foto_url or "",
    )

    return JsonResponse({"ok": True, "operador": op}, status=201)


@admin_view
@require_POST
def admin_administrador_novo(request: HttpRequest):
    auth_user = getattr(request, "auth_user", None)
    username = ""
    if isinstance(auth_user, dict):
        username = (auth_user.get("username") or "").lower()

    if username != "douglas.antunes":
        return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

    nome_completo = read_field(request, "nome_completo")
    email = read_field(request, "email").lower()
    username_admin = read_field(request, "username").lower()
    senha = read_field(request, "senha")

    faltantes = []
    if not nome_completo:   faltantes.append("nome_completo")
    if not email:           faltantes.append("email")
    if not username_admin:  faltantes.append("username")
    if not senha:           faltantes.append("senha")
    if faltantes:
        return JsonResponse({"ok": False, "error": "invalid_payload", "missing": ", ".join(faltantes)}, status=400)

    email_exists = db.exists_user("pessoa.administrador", "email", email)
    username_exists = db.exists_user("pessoa.administrador", "username", username_admin)
    if email_exists or username_exists:
        msg = (
            "E-mail e usuário já cadastrados" if (email_exists and username_exists)
            else ("E-mail já cadastrado" if email_exists else "Nome de usuário já cadastrado")
        )
        return JsonResponse({"ok": False, "error": "conflict", "message": msg}, status=409)

    hashed = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    admin = db.insert_administrador(
        nome_completo=nome_completo,
        email=email,
        username=username_admin,
        password_hash=hashed,
    )

    return JsonResponse({"ok": True, "administrador": admin}, status=201)


# ── Dashboard — listagem ─────────────────────────────────────────

@admin_view
@require_GET
def dashboard_operadores_view(request: HttpRequest):
    return _admin_list_view(request, dashboard_operadores.list_operadores_dashboard, include_periodo=False)


@admin_view
@require_GET
def dashboard_checklists_view(request: HttpRequest):
    return _admin_list_view(request, dashboard_checklists.list_checklists_dashboard)


@admin_view
@require_GET
def dashboard_operacoes_view(request: HttpRequest):
    return _admin_list_view(request, dashboard_operacoes.list_operacoes_dashboard)


@admin_view
@require_GET
def dashboard_operacoes_entradas_view(request: HttpRequest):
    return _admin_list_view(request, dashboard_operacoes.list_operacoes_entradas_dashboard)


@admin_view
@require_GET
def dashboard_anormalidades_salas_view(request: HttpRequest):
    search = request.GET.get("search", "").strip()
    try:
        salas = dashboard_anormalidades.list_salas_com_anormalidades(search=search)
        return JsonResponse({"ok": True, "data": salas})
    except Exception:
        logger.exception("Erro em dashboard_anormalidades_salas_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_GET
def dashboard_anormalidades_lista_view(request: HttpRequest):
    sala_id = parse_sala_id(request.GET.get("sala_id"))
    return _admin_list_view(
        request,
        dashboard_anormalidades.list_anormalidades_por_sala,
        sala_id=sala_id,
    )


# ── Dashboard — detalhe ──────────────────────────────────────────

@admin_view
@require_GET
def operacao_detalhe_view(request: HttpRequest):
    entrada_id = request.GET.get("entrada_id")
    if not entrada_id:
        return JsonResponse({"ok": False, "error": "entrada_id obrigatorio"}, status=400)

    try:
        data = dashboard_operacoes.get_entrada_operacao_detalhe(entrada_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception:
        logger.exception("Erro em operacao_detalhe_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_GET
def checklist_detalhe_view(request: HttpRequest):
    checklist_id = request.GET.get("checklist_id")
    if not checklist_id:
        return JsonResponse({"ok": False, "error": "checklist_id obrigatorio"}, status=400)

    try:
        data = dashboard_checklists.get_checklist_detalhe(checklist_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception:
        logger.exception("Erro em checklist_detalhe_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_GET
def anormalidade_detalhe_view(request: HttpRequest):
    anom_id = request.GET.get("id")
    if not anom_id:
        return JsonResponse({"ok": False, "error": "id obrigatorio"}, status=400)

    try:
        data = dashboard_anormalidades.get_anormalidade_detalhe(anom_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception:
        logger.exception("Erro em anormalidade_detalhe_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


# ── Dashboard — relatórios ───────────────────────────────────────

@admin_view
@require_GET
def dashboard_operadores_relatorio_view(request: HttpRequest):
    return _admin_relatorio_view(
        request,
        dashboard_operadores.list_operadores_dashboard,
        "relatorio_operadores_audio",
        report_pdf_service.gerar_relatorio_operadores,
        report_docx_service.gerar_relatorio_operadores,
        include_periodo=False,
    )


@admin_view
@require_GET
def dashboard_checklists_relatorio_view(request: HttpRequest):
    return _admin_relatorio_view(
        request,
        dashboard_checklists.list_checklists_dashboard,
        "relatorio_checklists",
        report_pdf_service.gerar_relatorio_checklists,
        report_docx_service.gerar_relatorio_checklists,
    )


@admin_view
@require_GET
def dashboard_anormalidades_relatorio_view(request: HttpRequest):
    return _admin_relatorio_view(
        request,
        dashboard_anormalidades.list_anormalidades_por_sala,
        "relatorio_anormalidades",
        report_pdf_service.gerar_relatorio_anormalidades,
        report_docx_service.gerar_relatorio_anormalidades,
        sala_id=None,
    )


@admin_view
@require_GET
def dashboard_operacoes_relatorio_view(request: HttpRequest):
    return _admin_relatorio_view(
        request,
        dashboard_operacoes.list_operacoes_dashboard,
        "relatorio_operacoes_sessoes",
        report_pdf_service.gerar_relatorio_operacoes_sessoes,
        report_docx_service.gerar_relatorio_operacoes_sessoes,
    )


@admin_view
@require_GET
def dashboard_operacoes_entradas_relatorio_view(request: HttpRequest):
    return _admin_relatorio_view(
        request,
        dashboard_operacoes.list_operacoes_entradas_dashboard,
        "relatorio_operacoes_entradas",
        report_pdf_service.gerar_relatorio_operacoes_entradas,
        report_docx_service.gerar_relatorio_operacoes_entradas,
    )


# ── Anormalidades — observações ──────────────────────────────────

@admin_view
@require_POST
def anormalidade_observacao_supervisor_view(request: HttpRequest):
    return _observacao_view(
        request,
        allowed_username=SUPERVISOR_USERNAME,
        allowed_email=SUPERVISOR_EMAIL,
        db_fn=dashboard_anormalidades.set_anormalidade_observacao_supervisor,
    )


@admin_view
@require_POST
def anormalidade_observacao_chefe_view(request: HttpRequest):
    return _observacao_view(
        request,
        allowed_username=CHEFE_SERVICO_USERNAME,
        allowed_email=CHEFE_SERVICO_EMAIL,
        db_fn=dashboard_anormalidades.set_anormalidade_observacao_chefe,
    )


# ── Form Edit (salas / comissões) ────────────────────────────────

@admin_view
@require_GET
def form_edit_list_view(request: HttpRequest, entidade: str):
    if entidade == "checklist-itens":
        return JsonResponse(
            {"ok": False, "error": "DEPRECATED", "message": "Use /sala-config/<sala_id>/list ao invés."},
            status=410,
        )

    try:
        items = form_edit_db.list_form_edit_items(entidade)
        return JsonResponse({"ok": True, "entity": entidade, "items": items})
    except form_edit_db.EntidadeInvalidaError as e:
        return JsonResponse({"ok": False, "error": "ENTIDADE_INVALIDA", "message": str(e)}, status=400)
    except Exception:
        logger.exception("Erro em form_edit_list_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_POST
def form_edit_save_view(request: HttpRequest, entidade: str):
    if entidade == "checklist-itens":
        return JsonResponse(
            {"ok": False, "error": "DEPRECATED", "message": "Use /sala-config/<sala_id>/save ao invés."},
            status=410,
        )

    body = parse_json_body(request) or {}
    items = body.get("items")

    if not isinstance(items, list):
        return JsonResponse(
            {"ok": False, "error": "PAYLOAD_INVALIDO", "message": "Campo 'items' é obrigatório e deve ser uma lista."},
            status=400,
        )

    auth_user = getattr(request, "auth_user", None)
    user_id = auth_user.get("id") if isinstance(auth_user, dict) else None

    try:
        created, updated = form_edit_db.save_form_edit_items(entidade, items, user_id=user_id)
        return JsonResponse({"ok": True, "entity": entidade, "created": created, "updated": updated})
    except form_edit_db.EntidadeInvalidaError as e:
        return JsonResponse({"ok": False, "error": "ENTIDADE_INVALIDA", "message": str(e)}, status=400)
    except ValueError as e:
        return JsonResponse({"ok": False, "error": "VALIDACAO", "message": str(e)}, status=400)
    except Exception:
        logger.exception("Erro em form_edit_save_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


# ── Sala Config (checklist por sala) ─────────────────────────────

@admin_view
@require_GET
def sala_config_list_view(request: HttpRequest, sala_id: str):
    sala_id_int = parse_sala_id(sala_id)
    if sala_id_int is None:
        return JsonResponse(
            {"ok": False, "error": "LOCAL_ID_INVALIDO", "message": "O ID do local deve ser um número válido."},
            status=400,
        )

    try:
        items = form_edit_db.list_sala_config_items(sala_id_int)
        return JsonResponse({"ok": True, "sala_id": sala_id_int, "items": items})
    except Exception:
        logger.exception("Erro em sala_config_list_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_POST
def sala_config_save_view(request: HttpRequest, sala_id: str):
    sala_id_int = parse_sala_id(sala_id)
    if sala_id_int is None:
        return JsonResponse(
            {"ok": False, "error": "LOCAL_ID_INVALIDO", "message": "O ID do local deve ser um número válido."},
            status=400,
        )

    body = parse_json_body(request) or {}
    items = body.get("items")

    if not isinstance(items, list):
        return JsonResponse(
            {"ok": False, "error": "PAYLOAD_INVALIDO", "message": "Campo 'items' é obrigatório e deve ser uma lista."},
            status=400,
        )

    try:
        created, updated = form_edit_db.save_sala_config_items(sala_id_int, items)
        return JsonResponse({"ok": True, "sala_id": sala_id_int, "created": created, "updated": updated})
    except ValueError as e:
        return JsonResponse({"ok": False, "error": "VALIDACAO", "message": str(e)}, status=400)
    except Exception:
        logger.exception("Erro em sala_config_save_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


@admin_view
@require_POST
def sala_config_aplicar_todas_view(request: HttpRequest):
    body = parse_json_body(request) or {}
    source_sala_id_raw = body.get("source_sala_id")
    items = body.get("items")

    if not source_sala_id_raw:
        return JsonResponse(
            {"ok": False, "error": "PAYLOAD_INVALIDO", "message": "Campo 'source_sala_id' é obrigatório."},
            status=400,
        )

    source_sala_id = parse_sala_id(source_sala_id_raw)
    if source_sala_id is None:
        return JsonResponse(
            {"ok": False, "error": "LOCAL_ID_INVALIDO", "message": "O ID do local de origem deve ser um número válido."},
            status=400,
        )

    if not isinstance(items, list):
        return JsonResponse(
            {"ok": False, "error": "PAYLOAD_INVALIDO", "message": "Campo 'items' é obrigatório e deve ser uma lista."},
            status=400,
        )

    try:
        count = form_edit_db.apply_sala_config_to_all(source_sala_id, items)
        return JsonResponse({"ok": True, "source_sala_id": source_sala_id, "salas_atualizadas": count})
    except ValueError as e:
        return JsonResponse({"ok": False, "error": "VALIDACAO", "message": str(e)}, status=400)
    except Exception:
        logger.exception("Erro em sala_config_aplicar_todas_view")
        return json_error(500, {"ok": False, "error": "internal_error"})


# ── RDS (Relatório Diário de Serviço) ────────────────────────────

@admin_view
@require_GET
def rds_anos_view(request: HttpRequest):
    anos = rds_db.list_rds_anos()
    return JsonResponse({"ok": True, "anos": anos}, json_dumps_params={"ensure_ascii": False})


@admin_view
@require_GET
def rds_meses_view(request: HttpRequest):
    try:
        ano = int(request.GET.get("ano", "0"))
    except ValueError:
        return json_error(400, {"ok": False, "error": "Parâmetro 'ano' inválido"})

    if ano < 1900:
        return json_error(400, {"ok": False, "error": "Parâmetro 'ano' inválido"})

    meses = rds_db.list_rds_meses(ano)
    return JsonResponse({"ok": True, "meses": meses}, json_dumps_params={"ensure_ascii": False})


@admin_view
@require_GET
def rds_gerar_view(request: HttpRequest):
    try:
        ano = int(request.GET.get("ano", "0"))
        mes = int(request.GET.get("mes", "0"))
    except ValueError:
        return json_error(400, {"ok": False, "error": "Parâmetros 'ano'/'mes' inválidos"})

    if ano < 1900 or mes < 1 or mes > 12:
        return json_error(400, {"ok": False, "error": "Parâmetros 'ano'/'mes' inválidos"})

    rows = rds_db.fetch_rds_rows(ano, mes)
    content = rds_xlsx_service.gerar_rds_xlsx(ano, mes, rows)

    filename = f"RDS {ano}-{mes:02d}.xlsx"
    resp = HttpResponse(
        content,
        content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    resp["Content-Disposition"] = f'attachment; filename="{filename}"'
    return resp
