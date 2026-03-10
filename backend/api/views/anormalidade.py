from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from ..utils import json_error, parse_json_body
from ..auth import jwt_required
from .. import db

from ..services.anormalidade_service import (
    registrar_anormalidade,
    ServiceValidationError,
)


def _read_field(request: HttpRequest, key: str) -> str:
    """
    Lê um campo do request, aceitando tanto JSON quanto formulário.
    Mantém o padrão usado nas outras views.
    """
    if request.content_type and "application/json" in request.content_type:
        data = parse_json_body(request) or {}
        val = data.get(key, "")
    else:
        val = request.POST.get(key, "") or request.GET.get(key, "")
    return (val or "").strip()


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
        # ------------------------------------------------------------------
        # 1) Usuário autenticado
        # ------------------------------------------------------------------
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        # GET pode não exigir user_id, mas mantemos o mesmo padrão:
        # se não tiver user_id, devolvemos 401.
        if not user_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        # ------------------------------------------------------------------
        # 2) GET: retorna RAOA por entrada_id (para edição)
        # ------------------------------------------------------------------
        if request.method == "GET":
            entrada_id_raw = (request.GET.get("entrada_id") or "").strip()
            if not entrada_id_raw:
                return JsonResponse(
                    {
                        "ok": False,
                        "error": "missing_param",
                        "detail": "entrada_id é obrigatório",
                    },
                    status=400,
                )

            try:
                entrada_id = int(entrada_id_raw)
            except ValueError:
                return JsonResponse(
                    {
                        "ok": False,
                        "error": "invalid_param",
                        "detail": "entrada_id inválido",
                    },
                    status=400,
                )

            anom = db.get_registro_anormalidade_por_entrada(entrada_id)
            if not anom:
                return JsonResponse(
                    {"ok": False, "error": "not_found"},
                    status=404,
                )

            return JsonResponse({"ok": True, "data": anom}, status=200)

        # ------------------------------------------------------------------
        # 3) Demais métodos: apenas POST é aceito
        # ------------------------------------------------------------------
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        # ------------------------------------------------------------------
        # 4) Monta payload a partir da requisição (POST)
        # ------------------------------------------------------------------
        if request.content_type and "application/json" in request.content_type:
            # JSON: usamos o corpo diretamente
            body = parse_json_body(request) or {}
        else:
            # Formulário (POST ou multipart): reproduz nomes dos campos do form
            def _rf(name: str) -> str:
                return _read_field(request, name)

            body = {
                # chave usada para UPDATE (vinda do hidden no form)
                "id": _rf("id") or _rf("registro_anormalidade_id"),
                "registro_anormalidade_id": _rf("registro_anormalidade_id"),
                "registro_id": _rf("registro_id"),
                "entrada_id": _rf("entrada_id"),
                "data": _rf("data"),
                "sala_id": _rf("sala_id"),
                "nome_evento": _rf("nome_evento"),
                "hora_inicio_anormalidade": _rf("hora_inicio_anormalidade"),
                "descricao_anormalidade": _rf("descricao_anormalidade"),
                "houve_prejuizo": _rf("houve_prejuizo"),
                "descricao_prejuizo": _rf("descricao_prejuizo"),
                "houve_reclamacao": _rf("houve_reclamacao"),
                "autores_conteudo_reclamacao": _rf(
                    "autores_conteudo_reclamacao"
                ),
                "acionou_manutencao": _rf("acionou_manutencao"),
                "hora_acionamento_manutencao": _rf(
                    "hora_acionamento_manutencao"
                ),
                "resolvida_pelo_operador": _rf("resolvida_pelo_operador"),
                "procedimentos_adotados": _rf("procedimentos_adotados"),
                "anormalidade_solucionada": _rf("anormalidade_solucionada"),
                "data_solucao": _rf("data_solucao"),
                "hora_solucao": _rf("hora_solucao"),
                "responsavel_evento": _rf("responsavel_evento"),
                "operador_responsavel_id": _rf("operador_responsavel_id"),
            }

        # ------------------------------------------------------------------
        # 5) Chama o service de negócio
        # ------------------------------------------------------------------
        try:
            result = registrar_anormalidade(payload=body, user_id=user_id)
        except ServiceValidationError as e:
            errors = (e.extra or {}).get("errors", {})
            return JsonResponse({"ok": False, "errors": errors}, status=400)

        # ------------------------------------------------------------------
        # 6) Sucesso
        # ------------------------------------------------------------------
        return JsonResponse(
            {
                "ok": True,
                "registro_anormalidade_id": result.registro_anormalidade_id,
                "registro_id": result.registro_id,
            },
            status=201,
        )

    except Exception as e:
        import traceback

        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e.__class__.__name__}: {e}"},
            status=500,
        )
