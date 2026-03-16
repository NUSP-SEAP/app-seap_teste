from functools import wraps
import jwt

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .db.auth import session_touch_ok


def parse_bearer(auth_header: str) -> str:
    if not auth_header:
        return ""
    parts = auth_header.strip().split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]
    return ""

def jwt_encode(payload: dict) -> str:
    return jwt.encode(payload, settings.AUTH_JWT_SECRET, algorithm="HS256")

def jwt_decode(token: str) -> dict:
    return jwt.decode(token, settings.AUTH_JWT_SECRET, algorithms=["HS256"])

def jwt_required(view):
    @wraps(view)
    def _wrapped(request, *args, **kwargs):
        auth = request.headers.get("Authorization") or request.headers.get("authorization") or ""
        token = parse_bearer(auth)
        if not token:
            return JsonResponse(
                {"error": "unauthorized", "message": "Missing Authorization header"},
                status=401
            )
        try:
            claims = jwt_decode(token)
        except jwt.ExpiredSignatureError:
            return JsonResponse({"error": "unauthorized", "message": "Token expirado"}, status=401)
        except jwt.InvalidTokenError:
            return JsonResponse({"error": "unauthorized", "message": "Token inválido"}, status=401)

        required = ["sub","perfil","username","nome","email","sid","exp"]
        if any(k not in claims for k in required):
            return JsonResponse({"error": "unauthorized", "message": "Token incompleto"}, status=401)

        sid = int(claims["sid"])
        sub = claims["sub"]

        ok = session_touch_ok(sid, sub)
        if not ok:
            return JsonResponse({"error": "unauthorized", "message": "Token inválido ou expirado."}, status=401)

        # Injeta dados do usuário na request (como o set_auth_user do n8n)
        request.auth_user = {
            "id": claims["sub"],
            "role": claims["perfil"],
            "username": claims["username"],
            "name": claims["nome"],
            "email": claims["email"],
            "exp": claims["exp"],
            "sid": claims["sid"],
        }
        request.jwt_claims = claims
        return view(request, *args, **kwargs)
    return _wrapped

def admin_required(view):
    @wraps(view)
    def _wrapped(request, *args, **kwargs):
        if not getattr(request, "auth_user", None):
            return JsonResponse({"error": "unauthorized", "message": "Não autenticado"}, status=401)
        if request.auth_user.get("role") != "administrador":
            return JsonResponse({"ok": False, "error": "forbidden", "message": "Somente administradores podem acessar este recurso."}, status=403)
        return view(request, *args, **kwargs)
    return _wrapped


def admin_view(view):
    """Decorator composto: @csrf_exempt + @jwt_required + @admin_required."""
    wrapped = admin_required(view)
    wrapped = jwt_required(wrapped)
    wrapped = csrf_exempt(wrapped)
    return wrapped
