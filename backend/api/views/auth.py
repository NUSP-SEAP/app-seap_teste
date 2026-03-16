import bcrypt
import logging

from django.conf import settings
from django.http import JsonResponse, HttpRequest
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from django.utils.timezone import now

from ..utils import json_error, parse_json_body
import jwt as pyjwt

from ..auth import jwt_encode, jwt_decode, jwt_required
from ..db.auth import session_touch_ok
from .. import db

logger = logging.getLogger(__name__)

# -----------------------
# Configuração do cookie de sessão HTML
# -----------------------
AUTH_COOKIE_NAME = getattr(settings, "AUTH_JWT_COOKIE_NAME", "sn_auth_jwt")
AUTH_COOKIE_DOMAIN = getattr(settings, "AUTH_JWT_COOKIE_DOMAIN", "")  # vazio = host atual
AUTH_COOKIE_MAX_AGE = int(getattr(settings, "AUTH_JWT_TTL_SEC", 3600))


def _build_claims(user_id, perfil, username, nome, email, sid):
    """Monta o dict de claims do JWT. Usado em login e refresh."""
    iat = int(now().timestamp())
    exp = iat + int(settings.AUTH_JWT_TTL_SEC)
    return {
        "sub": user_id,
        "perfil": perfil,
        "username": username,
        "nome": nome,
        "email": email,
        "sid": str(sid),
        "iat": iat,
        "exp": exp,
    }


def _set_auth_cookie(resp, token):
    """Grava o JWT no cookie HttpOnly de sessão. Usado em login e refresh."""
    cookie_domain = AUTH_COOKIE_DOMAIN or None
    resp.set_cookie(
        AUTH_COOKIE_NAME,
        token,
        max_age=AUTH_COOKIE_MAX_AGE,
        httponly=True,
        secure=not settings.DEBUG,
        samesite="Lax",
        path="/",
        domain=cookie_domain,
    )

@csrf_exempt
@require_POST
def login_view(request: HttpRequest):
    """
    POST /api/login

    - Valida credenciais.
    - Cria sessão (tabela pessoa.auth_sessions).
    - Gera JWT.
    - Devolve JSON (token + user) E grava o token em cookie HttpOnly.
    """
    data = parse_json_body(request) if request.body else {}
    usuario = (data.get("usuario") or request.POST.get("usuario", "") or "").strip()
    senha   = (data.get("senha")   or request.POST.get("senha", "")   or "").strip()

    if not usuario or not senha:
        return JsonResponse({"error": "Credenciais inválidas"}, status=401)

    u = db.get_user_for_login(usuario)
    if not u:
        return JsonResponse({"error": "Credenciais inválidas"}, status=401)

    try:
        ok = bcrypt.checkpw(
            senha.encode("utf-8"),
            u["password_hash"].encode("utf-8"),
        )
    except (ValueError, TypeError):
        ok = False

    if not ok:
        return JsonResponse({"error": "Credenciais inválidas"}, status=401)

    sid = db.create_session(u["id"])
    claims = _build_claims(u["id"], u["perfil"], u["username"], u["nome_completo"], u["email"], sid)
    token = jwt_encode(claims)

    resp = JsonResponse(
        {
            "token": token,
            "user": {
                "id": u["id"],
                "role": u["perfil"],
                "username": u["username"],
                "nome": u["nome_completo"],
                "email": u["email"],
            },
        }
    )
    _set_auth_cookie(resp, token)
    return resp

@csrf_exempt
@require_GET
@jwt_required
def whoami_view(request: HttpRequest):
    # Implementa o GET /whoami
    au = request.auth_user
    foto_url = db.get_foto_url_by_id(au["id"], au["role"])
    return JsonResponse({
        "ok": True,
        "user": {
            "id": au["id"],
            "username": au["username"],
            "name": au["name"],
            "email": au["email"],
            "foto_url": foto_url,
        },
        "role": au["role"],
        "exp": au["exp"],
    })

@csrf_exempt
@require_POST
@jwt_required
def logout_view(request: HttpRequest):
    """
    POST /api/logout

    - Revoga a sessão atual no banco.
    - Limpa o cookie de sessão HTML (sn_auth_jwt).
    """
    sid = int(request.auth_user.get("sid"))
    sub = request.auth_user.get("id")
    count = db.revoke_session(sid, sub)

    resp = JsonResponse({"ok": True, "revoked": bool(count)})
    resp.delete_cookie(AUTH_COOKIE_NAME, path="/", domain=AUTH_COOKIE_DOMAIN or None)
    return resp

@csrf_exempt
@require_POST
@jwt_required
def refresh_view(request: HttpRequest):
    """
    POST /api/auth/refresh

    Renova o JWT do usuário se a sessão ainda estiver ativa no banco.
    Isso permite que usuários ativos não sejam deslogados após o TTL inicial.
    """
    au = request.auth_user
    claims = _build_claims(au["id"], au["role"], au["username"], au["name"], au["email"], int(au["sid"]))
    token = jwt_encode(claims)

    resp = JsonResponse({"ok": True, "token": token, "exp": claims["exp"]})
    _set_auth_cookie(resp, token)
    return resp

@csrf_exempt
def html_guard_view(request: HttpRequest):
    """
    GET /api/auth/html-guard

    Usado pelo Nginx (auth_request) para decidir se libera HTML protegido.

    Regras:
      - Lê o JWT do cookie AUTH_COOKIE_NAME (sn_auth_jwt).
      - Valida o token (assinatura + exp).
      - Confere sessão via session_touch_ok(sid, sub):
          - se sessão expirada/revogada -> 401
      - Se OK -> 200 com dados básicos do usuário.
    """
    token = request.COOKIES.get(AUTH_COOKIE_NAME, "")
    if not token:
        return JsonResponse(
            {"ok": False, "error": "not_authenticated"},
            status=401,
        )

    # 1) Decodifica token
    try:
        claims = jwt_decode(token)
    except pyjwt.InvalidTokenError:
        return JsonResponse(
            {"ok": False, "error": "invalid_token"},
            status=401,
        )

    sid_raw = claims.get("sid")
    sub = claims.get("sub")

    if not sid_raw or not sub:
        return JsonResponse(
            {"ok": False, "error": "invalid_token"},
            status=401,
        )

    try:
        sid = int(sid_raw)
    except (TypeError, ValueError):
        return JsonResponse(
            {"ok": False, "error": "invalid_token"},
            status=401,
        )

    # 2) Confirma que a sessão não foi revogada nem expirou na tabela pessoa.auth_sessions
    try:
        ok = session_touch_ok(sid, sub)
    except Exception:
        # Se der erro de banco, devolve 500 (melhor que liberar HTML)
        return JsonResponse(
            {"ok": False, "error": "internal_error"},
            status=500,
        )

    if not ok:
        return JsonResponse(
            {"ok": False, "error": "not_authenticated"},
            status=401,
        )

    # 3) OK -> devolve alguns dados do usuário (para debug/log se quiser bater direto)
    return JsonResponse(
        {
            "ok": True,
            "user": {
                "id": claims.get("sub"),
                "role": claims.get("perfil"),
                "username": claims.get("username"),
                "nome": claims.get("nome"),
                "email": claims.get("email"),
            },
            "exp": claims.get("exp"),
        }
    )
