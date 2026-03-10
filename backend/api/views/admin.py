import os
import json
import bcrypt

from django.conf import settings
from django.http import HttpRequest, JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.timezone import now

from ..utils import json_error, parse_json_body
from ..auth import jwt_required, admin_required
from ..db import admin_dashboard
from ..db import form_edit as form_edit_db
from ..db import rds as rds_db
from .. import db
from api.services import report_pdf_service
from api.services import report_docx_service
from api.services import rds_xlsx_service
from api.services import report_service

# Permissões específicas para observações de anormalidade
SUPERVISOR_USERNAME = "emanoel"
SUPERVISOR_EMAIL = "emanoel@senado.leg.br"

CHEFE_SERVICO_USERNAME = "evandrop"
CHEFE_SERVICO_EMAIL = "evandrop@senado.leg.br"

def _read_field(request: HttpRequest, key: str) -> str:
    # Lê do JSON (body) ou do formulário (POST/multipart),
    # igual ao helper usado nas outras views.
    if request.content_type and "application/json" in request.content_type:
        data = parse_json_body(request)
        val = data.get(key, "")
    else:
        val = request.POST.get(key, "") or request.GET.get(key, "")
    return (val or "").strip()


def _first_file(request: HttpRequest, keys=('foto','foto0','file','image','upload')):
    for k in keys:
        if k in request.FILES:
            return request.FILES[k]
    # fallback: qualquer arquivo
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

def _fetch_all_pages(fetch_fn, *, limit: int = 200, **kwargs):
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
            # fallback se o backend não trouxer total (evita loop infinito)
            if len(rows) < limit:
                break

        offset += limit

    return all_rows

# Helper auxiliar para ler parâmetros comuns de listagem
def get_list_params(request: HttpRequest):
    try:
        page = int(request.GET.get("page", 1))
        limit = int(request.GET.get("limit", 10))
        if page < 1: page = 1
        if limit < 1: limit = 10
        if limit > 100: limit = 100
    except ValueError:
        page, limit = 1, 10
    
    search = request.GET.get("search", "").strip()
    sort = request.GET.get("sort", "").strip()
    direction = request.GET.get("dir", "asc").strip().lower() # 'asc' ou 'desc'

    return page, limit, search, sort, direction

def get_periodo_param(request: HttpRequest):
    """
    Lê o parâmetro ?periodo= (JSON) e devolve um dict ou None.

    Formato esperado:
        {"ranges": [{"start": "2023-01-01", "end": "2023-03-31"}, ...]}
    """
    raw = request.GET.get("periodo")
    if not raw:
        return None

    try:
        return json.loads(raw)
    except Exception:
        # Se vier inválido, simplesmente ignora o filtro de período
        return None
    
def get_filters_param(request: HttpRequest):
    """
    Lê o parâmetro ?filters= (JSON) e devolve um dict ou None.

    Formato esperado:
        {
            "coluna": {
                "text": "abc",
                "values": ["x","y"],
                "range": {"from":"2025-01-01","to":"2025-01-31"}
            },
            ...
        }
    """
    raw = request.GET.get("filters")
    if not raw:
        return None

    try:
        value = json.loads(raw)
        return value if isinstance(value, dict) else None
    except Exception:
        return None

@csrf_exempt
@jwt_required
@admin_required
def admin_operador_novo(request: HttpRequest):
    # POST protegido, admin-only: cria operador (com ou sem foto)
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

    nome_completo = _read_field(request, "nome_completo")
    nome_exibicao = _read_field(request, "nome_exibicao")
    email = _read_field(request, "email").lower()
    username = _read_field(request, "username").lower()
    senha = _read_field(request, "senha")
    faltantes = []
    if not nome_completo:  faltantes.append("nome_completo")
    if not nome_exibicao:  faltantes.append("nome_exibicao")
    if not email:          faltantes.append("email")
    if not username:       faltantes.append("username")
    if not senha:          faltantes.append("senha")
    if faltantes:
        return JsonResponse({"ok": False, "error": "invalid_payload", "missing": ", ".join(faltantes)}, status=400)

    # Duplicidade
    email_exists = db.exists_operador_email(email)
    username_exists = db.exists_operador_username(username)
    if email_exists or username_exists:
        msg = "E-mail e usuário já cadastrados" if (email_exists and username_exists) else ("E-mail já cadastrado" if email_exists else "Nome de usuário já cadastrado")
        return JsonResponse({"ok": False, "error": "conflict", "message": msg}, status=409)

    # Upload (opcional)
    foto = _first_file(request)
    foto_url = ""
    if foto:
        ext = _ext_from_filename_or_content(foto)
        ts = int(now().timestamp() * 1000)
        filename = f"{username or 'sem_username'}_{ts}.{ext}"
        foto_url = settings.FILES_URL_PREFIX.rstrip("/") + "/" + settings.OPERADORES_DIRNAME + "/" + filename
        save_dir = os.path.join(settings.FILES_DIR, settings.OPERADORES_DIRNAME)
        os.makedirs(save_dir, exist_ok=True)
        foto_disk = os.path.join(save_dir, filename)
        # grava
        with open(foto_disk, "wb") as fh:
            for chunk in foto.chunks():
                fh.write(chunk)

    # Hash da senha (bcrypt)
    hashed = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    op = db.insert_operador(
        nome_completo=nome_completo,
        nome_exibicao=nome_exibicao,
        email=email,
        username=username,
        password_hash=hashed,
        foto_url=foto_url or ""
    )


    return JsonResponse({"ok": True, "operador": op}, status=201)

@csrf_exempt
@jwt_required
@admin_required
def admin_administrador_novo(request: HttpRequest):
    """
    POST protegido, admin-only: cria administrador (sem upload de foto).

    Regras:
      - Só o usuário com username 'douglas.antunes' pode criar administradores.
      - Duplicidade de e-mail / username é checada na tabela pessoa.administrador.
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

    # 0) trava real: só douglas.antunes
    auth_user = getattr(request, "auth_user", None)
    username = ""
    if isinstance(auth_user, dict):
        username = (auth_user.get("username") or "").lower()

    if username != "douglas.antunes":
        # Nada de mensagem bonita; é endpoint de API.
        return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

    # 1) Lê campos (JSON ou form-data)
    nome_completo = _read_field(request, "nome_completo")
    email = _read_field(request, "email").lower()
    username_admin = _read_field(request, "username").lower()
    senha = _read_field(request, "senha")

    faltantes = []
    if not nome_completo:
        faltantes.append("nome_completo")
    if not email:
        faltantes.append("email")
    if not username_admin:
        faltantes.append("username")
    if not senha:
        faltantes.append("senha")

    if faltantes:
        return JsonResponse(
            {
                "ok": False,
                "error": "invalid_payload",
                "missing": ", ".join(faltantes),
            },
            status=400,
        )

    # 2) Duplicidade em pessoa.administrador
    email_exists = db.exists_admin_email(email)
    username_exists = db.exists_admin_username(username_admin)
    if email_exists or username_exists:
        if email_exists and username_exists:
            msg = "E-mail e usuário já cadastrados"
        elif email_exists:
            msg = "E-mail já cadastrado"
        else:
            msg = "Nome de usuário já cadastrado"

        return JsonResponse(
            {"ok": False, "error": "conflict", "message": msg},
            status=409,
        )

    # 3) Hash da senha
    hashed = bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    # 4) Inserção
    admin = db.insert_administrador(
        nome_completo=nome_completo,
        email=email,
        username=username_admin,
        password_hash=hashed,
    )

    return JsonResponse({"ok": True, "administrador": admin}, status=201)

@csrf_exempt
@jwt_required
@admin_required
def dashboard_operadores_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    page, limit, search, sort, direction = get_list_params(request)
    offset = (page - 1) * limit
    filters = get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_operadores_dashboard(
            limit=limit,
            offset=offset,
            search=search,
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
                "pages": (total + limit - 1) // limit
            }
        })
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

def get_pagination_params(request: HttpRequest):
    try:
        page = int(request.GET.get("page", 1))
        limit = int(request.GET.get("limit", 10)) # Padrão: 10 itens por página
        if page < 1: page = 1
        if limit < 1: limit = 10
        if limit > 100: limit = 100 # Segurança
        return page, limit
    except ValueError:
        return 1, 10

@csrf_exempt
@jwt_required
@admin_required
def dashboard_checklists_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    page, limit, search, sort, direction = get_list_params(request)
    offset = (page - 1) * limit
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_checklists_dashboard(
            limit=limit,
            offset=offset,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
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
                "pages": (total + limit - 1) // limit
            }
        })
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

@csrf_exempt
@jwt_required
@admin_required
def dashboard_operacoes_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    page, limit, search, sort, direction = get_list_params(request)
    offset = (page - 1) * limit
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_operacoes_dashboard(
            limit=limit,
            offset=offset,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
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
                "pages": (total + limit - 1) // limit
            }
        })
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)
    
@csrf_exempt
@jwt_required
@admin_required
def dashboard_operacoes_entradas_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    page, limit, search, sort, direction = get_list_params(request)
    offset = (page - 1) * limit
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        data, total, distinct = admin_dashboard.list_operacoes_entradas_dashboard(
            limit=limit,
            offset=offset,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
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
                "pages": (total + limit - 1) // limit,
            }
        })
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

@csrf_exempt
@jwt_required
@admin_required
def operacao_detalhe_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    entrada_id = request.GET.get("entrada_id")
    if not entrada_id:
        return JsonResponse({"ok": False, "error": "entrada_id obrigatorio"}, status=400)
    
    try:
        data = admin_dashboard.get_entrada_operacao_detalhe(entrada_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

@csrf_exempt
@jwt_required
@admin_required
def checklist_detalhe_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    checklist_id = request.GET.get("checklist_id")
    if not checklist_id:
        return JsonResponse({"ok": False, "error": "checklist_id obrigatorio"}, status=400)
    
    try:
        data = admin_dashboard.get_checklist_detalhe(checklist_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)
    
@csrf_exempt
@jwt_required
@admin_required
def dashboard_anormalidades_salas_view(request: HttpRequest):
    """
    Retorna apenas as salas que têm anormalidades (para montar o nível 1 da tabela).
    Agora suporta filtro textual (?search=...).
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    search = request.GET.get("search", "").strip()

    try:
        # Passamos o termo de busca para filtrar apenas as salas RELEVANTES
        salas = admin_dashboard.list_salas_com_anormalidades(search=search)
        return JsonResponse({"ok": True, "data": salas})
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)


@csrf_exempt
@jwt_required
@admin_required
def dashboard_anormalidades_lista_view(request: HttpRequest):
    ...
    sala_id_raw = request.GET.get("sala_id")
    sala_id = int(sala_id_raw) if sala_id_raw else None

    try:
        # Reutiliza get_list_params para pegar os padrões de paginação, busca e ordenação
        page, limit, search, sort, direction = get_list_params(request)
        offset = (page - 1) * limit
        periodo = get_periodo_param(request)
        filters = get_filters_param(request)

        # Chama a função de banco passando sala_id (pode ser None)
        data, total, distinct = admin_dashboard.list_anormalidades_por_sala(
            limit=limit,
            offset=offset,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            sala_id=sala_id,
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
                "pages": (total + limit - 1) // limit
            }
        })
    except ValueError:
        return JsonResponse({"ok": False, "error": "local_id invalido"}, status=400)
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

@csrf_exempt
@jwt_required
@admin_required
def dashboard_operadores_relatorio_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    _page, _limit, search, sort, direction = get_list_params(request)
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        rows = _fetch_all_pages(
            admin_dashboard.list_operadores_dashboard,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_operadores_audio",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_operadores(rows),
            docx_builder=lambda: report_docx_service.gerar_relatorio_operadores(rows),
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
@admin_required
def dashboard_checklists_relatorio_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    _page, _limit, search, sort, direction = get_list_params(request)
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        rows = _fetch_all_pages(
            admin_dashboard.list_checklists_dashboard,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_checklists",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_checklists(rows),
            docx_builder=lambda: report_docx_service.gerar_relatorio_checklists(rows),
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
@admin_required
def dashboard_anormalidades_relatorio_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    _page, _limit, search, sort, direction = get_list_params(request)
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        rows = _fetch_all_pages(
            admin_dashboard.list_anormalidades_por_sala,
            sala_id=None,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_anormalidades",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_anormalidades(rows),
            docx_builder=lambda: report_docx_service.gerar_relatorio_anormalidades(rows),
            pdf_inline=True,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e}"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )
    
@csrf_exempt
@jwt_required
@admin_required
def dashboard_operacoes_relatorio_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    _page, _limit, search, sort, direction = get_list_params(request)
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        rows = _fetch_all_pages(
            admin_dashboard.list_operacoes_dashboard,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_operacoes_sessoes",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_operacoes_sessoes(rows),
            docx_builder=lambda: report_docx_service.gerar_relatorio_operacoes_sessoes(rows),
            pdf_inline=True,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e}"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )


@csrf_exempt
@jwt_required
@admin_required
def dashboard_operacoes_entradas_relatorio_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"ok": False, "error": "method_not_allowed"})

    _page, _limit, search, sort, direction = get_list_params(request)
    periodo = get_periodo_param(request)
    filters = get_filters_param(request)

    try:
        rows = _fetch_all_pages(
            admin_dashboard.list_operacoes_entradas_dashboard,
            search=search,
            sort=sort,
            direction=direction,
            periodo=periodo,
            filters=filters,
        )

        return report_service.respond(
            request,
            filename_base="relatorio_operacoes_entradas",
            pdf_builder=lambda: report_pdf_service.gerar_relatorio_operacoes_entradas(rows),
            docx_builder=lambda: report_docx_service.gerar_relatorio_operacoes_entradas(rows),
            pdf_inline=True,
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e}"},
            status=500,
            json_dumps_params={"ensure_ascii": False},
        )

@csrf_exempt
@jwt_required
@admin_required
def anormalidade_detalhe_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})
    
    anom_id = request.GET.get("id")
    if not anom_id:
        return JsonResponse({"ok": False, "error": "id obrigatorio"}, status=400)
    
    try:
        data = admin_dashboard.get_anormalidade_detalhe(anom_id)
        if not data:
            return JsonResponse({"ok": False, "error": "not_found"}, status=404)
        return JsonResponse({"ok": True, "data": data})
    except Exception as e:
        return JsonResponse({"ok": False, "error": str(e)}, status=500)

@csrf_exempt
@jwt_required
@admin_required
def anormalidade_observacao_supervisor_view(request: HttpRequest):
    """POST: salva a observação do Supervisor para uma anormalidade.

    Regras:
      - Apenas o administrador com username/email configurados em SUPERVISOR_* pode salvar.
      - A observação só pode ser preenchida uma única vez.
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

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

    # Trava: só o supervisor configurado
    if username != SUPERVISOR_USERNAME or email != SUPERVISOR_EMAIL:
        return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

    try:
        admin_dashboard.set_anormalidade_observacao_supervisor(anom_id, observacao, user_id)
        return JsonResponse({"ok": True})
    except ValueError as e:
        # Regra de negócio (já preenchido, etc.)
        return JsonResponse(
            {"ok": False, "error": "VALIDACAO", "message": str(e)},
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {"ok": False, "error": "ERRO_INTERNO", "message": str(e)},
            status=500,
        )


@csrf_exempt
@jwt_required
@admin_required
def anormalidade_observacao_chefe_view(request: HttpRequest):
    """POST: salva a observação do Chefe de Serviço para uma anormalidade.

    Regras:
      - Apenas o administrador com username/email configurados em CHEFE_SERVICO_* pode salvar.
      - A observação só pode ser preenchida uma única vez.
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

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

    # Trava: só o chefe de serviço configurado
    if username != CHEFE_SERVICO_USERNAME or email != CHEFE_SERVICO_EMAIL:
        return JsonResponse({"ok": False, "error": "forbidden"}, status=403)

    try:
        admin_dashboard.set_anormalidade_observacao_chefe(anom_id, observacao, user_id)
        return JsonResponse({"ok": True})
    except ValueError as e:
        return JsonResponse(
            {"ok": False, "error": "VALIDACAO", "message": str(e)},
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {"ok": False, "error": "ERRO_INTERNO", "message": str(e)},
            status=500,
        )

@csrf_exempt
@jwt_required
@admin_required
def form_edit_list_view(request: HttpRequest, entidade: str):
    """
    GET /admin/form-edit/<entidade>/list

    Retorna os itens para a tela de edição de formulários.
    Entidades suportadas: 'salas', 'comissoes'
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    if entidade == "checklist-itens":
        return JsonResponse(
            {"success": False, "error": "DEPRECATED",
             "message": "Use /sala-config/<sala_id>/list ao invés."},
            status=410,
        )

    try:
        items = form_edit_db.list_form_edit_items(entidade)
        return JsonResponse(
            {
                "success": True,
                "entity": entidade,
                "items": items,
            }
        )
    except form_edit_db.EntidadeInvalidaError as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ENTIDADE_INVALIDA",
                "message": str(e),
            },
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ERRO_INTERNO",
                "message": str(e),
            },
            status=500,
        )

@csrf_exempt
@jwt_required
@admin_required
def form_edit_save_view(request: HttpRequest, entidade: str):
    """
    POST /admin/form-edit/<entidade>/save

    Salva as alterações de ordem, nome e ativo.
    Entidades suportadas: 'salas', 'comissoes'
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

    if entidade == "checklist-itens":
        return JsonResponse(
            {"success": False, "error": "DEPRECATED",
             "message": "Use /sala-config/<sala_id>/save ao invés."},
            status=410,
        )

    body = parse_json_body(request) or {}
    items = body.get("items")

    if not isinstance(items, list):
        return JsonResponse(
            {
                "success": False,
                "error": "PAYLOAD_INVALIDO",
                "message": "Campo 'items' é obrigatório e deve ser uma lista.",
            },
            status=400,
        )

    # usuário autenticado (para criado_por / atualizado_por em comissões)
    auth_user = getattr(request, "auth_user", None)
    user_id = None
    if isinstance(auth_user, dict):
        user_id = auth_user.get("id")

    try:
        created, updated = form_edit_db.save_form_edit_items(
            entidade,
            items,
            user_id=user_id,
        )
        return JsonResponse(
            {
                "success": True,
                "entity": entidade,
                "created": created,
                "updated": updated,
            }
        )
    except form_edit_db.EntidadeInvalidaError as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ENTIDADE_INVALIDA",
                "message": str(e),
            },
            status=400,
        )
    except ValueError as e:
        # Erros de validação de dados (nome vazio, id inexistente, etc.)
        return JsonResponse(
            {
                "success": False,
                "error": "VALIDACAO",
                "message": str(e),
            },
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ERRO_INTERNO",
                "message": str(e),
            },
            status=500,
        )

@csrf_exempt
@jwt_required
@admin_required
def sala_config_list_view(request: HttpRequest, sala_id: str):
    """
    GET /admin/form-edit/sala-config/<sala_id>/list

    Lista os itens de checklist configurados para uma sala específica.
    """
    if request.method != "GET":
        return json_error(405, {"error": "method_not_allowed"})

    try:
        sala_id_int = int(sala_id)
    except (ValueError, TypeError):
        return JsonResponse(
            {
                "success": False,
                "error": "LOCAL_ID_INVALIDO",
                "message": "O ID do local deve ser um número válido.",
            },
            status=400,
        )

    try:
        items = form_edit_db.list_sala_config_items(sala_id_int)
        return JsonResponse(
            {
                "success": True,
                "sala_id": sala_id_int,
                "items": items,
            }
        )
    except Exception as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ERRO_INTERNO",
                "message": str(e),
            },
            status=500,
        )


@csrf_exempt
@jwt_required
@admin_required
def sala_config_save_view(request: HttpRequest, sala_id: str):
    """
    POST /admin/form-edit/sala-config/<sala_id>/save

    Salva a configuração de itens de checklist para uma sala.
    O backend usa find-or-create: busca item_tipo por (nome + tipo_widget),
    cria novo se não existir.

    Payload esperado:
        {
            "sala_id": int,
            "items": [
                {
                    "nome": str,
                    "tipo_widget": str ("radio" ou "text"),
                    "ativo": bool
                },
                ...
            ]
        }
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

    try:
        sala_id_int = int(sala_id)
    except (ValueError, TypeError):
        return JsonResponse(
            {
                "success": False,
                "error": "LOCAL_ID_INVALIDO",
                "message": "O ID do local deve ser um número válido.",
            },
            status=400,
        )

    body = parse_json_body(request) or {}
    items = body.get("items")

    if not isinstance(items, list):
        return JsonResponse(
            {
                "success": False,
                "error": "PAYLOAD_INVALIDO",
                "message": "Campo 'items' é obrigatório e deve ser uma lista.",
            },
            status=400,
        )

    try:
        created, updated = form_edit_db.save_sala_config_items(sala_id_int, items)
        return JsonResponse(
            {
                "success": True,
                "sala_id": sala_id_int,
                "created": created,
                "updated": updated,
            }
        )
    except ValueError as e:
        return JsonResponse(
            {
                "success": False,
                "error": "VALIDACAO",
                "message": str(e),
            },
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ERRO_INTERNO",
                "message": str(e),
            },
            status=500,
        )


@csrf_exempt
@jwt_required
@admin_required
def sala_config_aplicar_todas_view(request: HttpRequest):
    """
    POST /admin/form-edit/sala-config/aplicar-todas

    Aplica a configuração de uma sala a todas as outras salas ativas.

    Payload esperado:
        {
            "source_sala_id": int,
            "items": [
                {
                    "nome": str,
                    "tipo_widget": str ("radio" ou "text"),
                    "ativo": bool
                },
                ...
            ]
        }
    """
    if request.method != "POST":
        return json_error(405, {"error": "method_not_allowed"})

    body = parse_json_body(request) or {}
    source_sala_id_raw = body.get("source_sala_id")
    items = body.get("items")

    if not source_sala_id_raw:
        return JsonResponse(
            {
                "success": False,
                "error": "PAYLOAD_INVALIDO",
                "message": "Campo 'source_sala_id' é obrigatório.",
            },
            status=400,
        )

    try:
        source_sala_id = int(source_sala_id_raw)
    except (ValueError, TypeError):
        return JsonResponse(
            {
                "success": False,
                "error": "LOCAL_ID_INVALIDO",
                "message": "O ID do local de origem deve ser um número válido.",
            },
            status=400,
        )

    if not isinstance(items, list):
        return JsonResponse(
            {
                "success": False,
                "error": "PAYLOAD_INVALIDO",
                "message": "Campo 'items' é obrigatório e deve ser uma lista.",
            },
            status=400,
        )

    try:
        count = form_edit_db.apply_sala_config_to_all(source_sala_id, items)
        return JsonResponse(
            {
                "success": True,
                "source_sala_id": source_sala_id,
                "salas_atualizadas": count,
            }
        )
    except ValueError as e:
        return JsonResponse(
            {
                "success": False,
                "error": "VALIDACAO",
                "message": str(e),
            },
            status=400,
        )
    except Exception as e:
        return JsonResponse(
            {
                "success": False,
                "error": "ERRO_INTERNO",
                "message": str(e),
            },
            status=500,
        )


@csrf_exempt
@jwt_required
@admin_required
def rds_anos_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, "Método não permitido")

    anos = rds_db.list_rds_anos()
    return JsonResponse({"ok": True, "anos": anos}, json_dumps_params={"ensure_ascii": False})


@csrf_exempt
@jwt_required
@admin_required
def rds_meses_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, "Método não permitido")

    try:
        ano = int(request.GET.get("ano", "0"))
    except ValueError:
        return json_error(400, "Parâmetro 'ano' inválido")

    if ano < 1900:
        return json_error(400, "Parâmetro 'ano' inválido")

    meses = rds_db.list_rds_meses(ano)
    return JsonResponse({"ok": True, "meses": meses}, json_dumps_params={"ensure_ascii": False})


@csrf_exempt
@jwt_required
@admin_required
def rds_gerar_view(request: HttpRequest):
    if request.method != "GET":
        return json_error(405, "Método não permitido")

    try:
        ano = int(request.GET.get("ano", "0"))
        mes = int(request.GET.get("mes", "0"))
    except ValueError:
        return json_error(400, "Parâmetros 'ano'/'mes' inválidos")

    if ano < 1900 or mes < 1 or mes > 12:
        return json_error(400, "Parâmetros 'ano'/'mes' inválidos")

    rows = rds_db.fetch_rds_rows(ano, mes)
    content = rds_xlsx_service.gerar_rds_xlsx(ano, mes, rows)

    filename = f"RDS {ano}-{mes:02d}.xlsx"
    resp = HttpResponse(
        content,
        content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    resp["Content-Disposition"] = f'attachment; filename="{filename}"'
    return resp