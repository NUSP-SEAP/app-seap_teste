from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from typing import Optional

from ..utils import json_error, parse_json_body
from ..auth import jwt_required
from .. import db

from ..services.operacao_service import (
    registrar_operacao_audio,
    ServiceValidationError,
    RegistroOperacaoAudioResult,
    obter_estado_sessao_para_operador,
    salvar_entrada_operacao_audio,
    finalizar_sessao_operacao_audio,
    editar_entrada_operacao,
)


def _read_field(request: HttpRequest, key: str) -> str:
    """
    Helper para ler campos tanto de formulário (POST/multipart) quanto,
    em último caso, da querystring.

    Este helper é usado apenas no endpoint "antigo" de registro de
    operação de áudio, que continua recebendo dados via form.
    """
    # Para esse endpoint específico, priorizamos POST/form-data.
    val = request.POST.get(key, "") or request.GET.get(key, "")
    return (val or "").strip()


@csrf_exempt
@jwt_required
def estado_sessao_operacao_audio_view(request: HttpRequest):
    """
    Lookup do estado da sessão de operação de áudio para uma sala + operador.

    - Método: GET
    - Parâmetros (querystring):
        * sala_id (obrigatório)
    - Operador é inferido a partir do usuário autenticado (JWT).

    Resposta de sucesso:
        {
          "ok": true,
          "data": { ... dict retornado por obter_estado_sessao_para_operador ... }
        }

    Erros de validação:
        HTTP 400
        {
          "ok": false,
          "errors": { ... }
        }
    """
    try:
        if request.method != "GET":
            return json_error(405, {"error": "method_not_allowed"})

        sala_id_raw = (request.GET.get("sala_id") or "").strip()
        if not sala_id_raw:
            return JsonResponse(
                {"ok": False, "errors": {"sala_id": "Parâmetro 'sala_id' é obrigatório."}},
                status=400,
            )

        try:
            sala_id = int(sala_id_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "errors": {"sala_id": "Local inválido."}},
                status=400,
            )

        # Usuário autenticado (operador) vem do JWT
        auth_user = getattr(request, "auth_user", None)
        operador_id = None
        if isinstance(auth_user, dict):
            operador_id = auth_user.get("id")

        if not operador_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        try:
            estado = obter_estado_sessao_para_operador(
                sala_id=sala_id,
                operador_id=str(operador_id),
            )
        except ServiceValidationError as e:
            errors = (e.extra or {}).get("errors", {})
            return JsonResponse({"ok": False, "errors": errors}, status=400)

        return JsonResponse({"ok": True, "data": estado}, status=200)

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
@jwt_required
def salvar_entrada_operacao_audio_view(request: HttpRequest):
    """
    Endpoint para criar/editar uma ENTRADA de operação de áudio
    (1ª ou 2ª) para o operador autenticado.

    - Método: POST
    - Content-Type: application/json
    - Corpo: JSON conforme contrato do service salvar_entrada_operacao_audio.

    Resposta de sucesso (dict retornado pelo service, envelopado):
        {
          "ok": true,
          "registro_id": ...,
          "entrada_id": ...,
          "houve_anormalidade": ...,
          "tipo_evento": "...",
          "seq": 1/2,
          "is_edicao": false/true,
          ...
        }

    Em erro de validação (ServiceValidationError):
        HTTP 400
        {
          "ok": false,
          "errors": { ... }
        }
    """
    try:
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        if not (request.content_type and "application/json" in request.content_type):
            return JsonResponse(
                {
                    "ok": False,
                    "errors": {
                        "geral": "Content-Type deve ser 'application/json' para este endpoint."
                    },
                },
                status=400,
            )

        body = parse_json_body(request) or {}

        # Usuário autenticado
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        if not user_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        try:
            result = salvar_entrada_operacao_audio(payload=body, user_id=str(user_id))
        except ServiceValidationError as e:
            errors = (e.extra or {}).get("errors", {})
            if errors:
                payload_erro = {"ok": False, "errors": errors}
            else:
                payload_erro = {
                    "ok": False,
                    "code": e.code,
                    "message": e.message,
                }
            return JsonResponse(payload_erro, status=400)

        # result é um dict; usamos a flag is_edicao para definir o status HTTP
        is_edicao = bool(result.get("is_edicao"))
        status_code = 200 if is_edicao else 201

        payload_ok = {"ok": True}
        payload_ok.update(result)
        return JsonResponse(payload_ok, status=status_code)

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
@jwt_required
def finalizar_sessao_operacao_audio_view(request: HttpRequest):
    """
    Endpoint para finalizar/encerrar a sessão de operação de áudio de uma sala.

    - Método: POST
    - Content-Type: application/json
    - Corpo esperado (mínimo):
        { "sala_id": 123 }

    A lógica de negócio (inclusive localizar a sessão aberta da sala)
    fica em finalizar_sessao_operacao_audio na camada de serviço.

    Resposta de sucesso (exemplo sugerido):
        {
          "ok": true,
          "registro_id": ...,
          "sala_id": ...,
          "status": "finalizado"
        }
    """
    try:
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        if not (request.content_type and "application/json" in request.content_type):
            return JsonResponse(
                {
                    "ok": False,
                    "errors": {
                        "geral": "Content-Type deve ser 'application/json' para este endpoint."
                    },
                },
                status=400,
            )

        body = parse_json_body(request) or {}
        sala_id_raw = (str(body.get("sala_id") or "").strip())

        if not sala_id_raw:
            return JsonResponse(
                {"ok": False, "errors": {"sala_id": "Campo 'sala_id' é obrigatório."}},
                status=400,
            )

        try:
            sala_id = int(sala_id_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "errors": {"sala_id": "Local inválido."}},
                status=400,
            )

        # Usuário autenticado
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        if not user_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        try:
            # Service decide como localizar e encerrar a sessão da sala.
            result = finalizar_sessao_operacao_audio(sala_id=sala_id, user_id=str(user_id))
        except ServiceValidationError as e:
            errors = (e.extra or {}).get("errors", {})
            if errors:
                payload_erro = {"ok": False, "errors": errors}
            else:
                payload_erro = {
                    "ok": False,
                    "code": e.code,
                    "message": e.message,
                }
            return JsonResponse(payload_erro, status=400)

        payload_ok = {"ok": True}
        if isinstance(result, dict):
            payload_ok.update(result)

        return JsonResponse(payload_ok, status=200)

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
@jwt_required
def lookup_registro_operacao_view(request: HttpRequest):
    """
    Retorna os dados básicos de um registro de operação de áudio para
    pré-preenchimento da tela de anormalidade.

    Uso típico:
      GET /forms/lookup/registro-operacao?id=123&entrada_id=456
    """
    try:
        if request.method != "GET":
            return json_error(405, {"error": "method_not_allowed"})

        rid_raw = request.GET.get("id") or request.GET.get("registro_id")
        if not rid_raw:
            return JsonResponse(
                {"ok": False, "errors": {"id": "Parâmetro 'id' é obrigatório."}},
                status=400,
            )

        try:
            registro_id = int(rid_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "errors": {"id": "ID inválido."}},
                status=400,
            )

        entrada_id: Optional[int] = None
        entrada_raw = request.GET.get("entrada_id") or request.GET.get("entrada")
        if entrada_raw:
            try:
                entrada_id = int(entrada_raw)
            except (TypeError, ValueError):
                return JsonResponse(
                    {"ok": False, "errors": {"entrada_id": "entrada_id inválido."}},
                    status=400,
                )

        row = db.get_registro_operacao_audio_for_anormalidade(
            registro_id=registro_id,
            entrada_id=entrada_id,
        )
        if not row:
            return JsonResponse(
                {
                    "ok": False,
                    "error": "not_found",
                    "detail": "Registro não encontrado.",
                },
                status=404,
            )

        return JsonResponse({"ok": True, "data": row}, status=200)

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
@jwt_required
def registro_operacao_audio_view(request: HttpRequest):
    """
    Endpoint original de cadastro do formulário "Registro de Operação de Áudio".

    Continua recebendo dados via formulário (POST/multipart ou x-www-form-urlencoded),
    mas delega toda a regra de negócio ao service registrar_operacao_audio.

    Ele grava em:
      - operacao.registro_operacao_audio
      - operacao.registro_operacao_operador
    """
    try:
        if request.method != "POST":
            return json_error(405, {"error": "method_not_allowed"})

        # 1) Leitura dos campos básicos
        data_operacao = _read_field(request, "data_operacao")
        horario_pauta = _read_field(request, "horario_pauta")
        hora_inicio = _read_field(request, "hora_inicio")
        hora_fim = _read_field(request, "hora_fim")
        sala_id = _read_field(request, "sala_id")
        nome_evento = _read_field(request, "nome_evento")
        observacoes = _read_field(request, "observacoes")
        houve_anormalidade_raw = _read_field(request, "houve_anormalidade") or "nao"

        # Campos extras
        usb_01 = _read_field(request, "usb_01")
        usb_02 = _read_field(request, "usb_02")

        # 2) Leitura dos operadores (mantém o contrato do formulário)
        op1 = _read_field(request, "operador_1")
        op2 = _read_field(request, "operador_2")
        op3 = _read_field(request, "operador_3")

        operadores = []
        if op1:
            operadores.append(op1)
        if op2:
            operadores.append(op2)
        if op3:
            operadores.append(op3)

        # 3) Usuário autenticado (para criado_por / atualizado_por)
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        if not user_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        # 4) Monta payload para o service
        payload = {
            "data_operacao": data_operacao,
            "horario_pauta": horario_pauta,
            "hora_inicio": hora_inicio,
            "hora_fim": hora_fim,
            "sala_id": sala_id,
            "nome_evento": nome_evento,
            "observacoes": observacoes,
            "usb_01": usb_01,
            "usb_02": usb_02,
            "houve_anormalidade": houve_anormalidade_raw,
            "operadores": operadores,
        }

        # 5) Chama o service (regra de negócio + DB)
        try:
            result: RegistroOperacaoAudioResult = registrar_operacao_audio(
                payload=payload,
                user_id=str(user_id),
            )
        except ServiceValidationError as e:
            errors = (e.extra or {}).get("errors", {})
            return JsonResponse({"ok": False, "errors": errors}, status=400)

        # 6) Resposta de sucesso (mesmo formato de antes)
        return JsonResponse(
            {
                "ok": True,
                "registro_id": result.registro_id,
                "houve_anormalidade": result.houve_anormalidade,
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
@jwt_required
def entrada_operacao_editar_view(request: HttpRequest):
    """
    PUT /webhook/operacao/audio/editar-entrada
    Edita uma entrada de operador existente, com verificação de ownership.
    """
    try:
        if request.method != "PUT":
            return json_error(405, {"error": "method_not_allowed"})

        body = parse_json_body(request)
        entrada_id_raw = body.get("entrada_id")
        if not entrada_id_raw:
            return JsonResponse(
                {"ok": False, "error": "entrada_id obrigatório"}, status=400
            )

        try:
            entrada_id = int(entrada_id_raw)
        except (TypeError, ValueError):
            return JsonResponse(
                {"ok": False, "error": "entrada_id inválido"}, status=400
            )

        # Usuário autenticado
        auth_user = getattr(request, "auth_user", None)
        user_id = None
        if isinstance(auth_user, dict):
            user_id = auth_user.get("id")

        if not user_id:
            return JsonResponse(
                {"ok": False, "error": "unauthorized", "detail": "missing_user"},
                status=401,
            )

        # Verificação de ownership: só quem criou a entrada pode editar
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(
                "SELECT operador_id FROM operacao.registro_operacao_operador WHERE id = %s::bigint",
                [entrada_id],
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
            result = editar_entrada_operacao(
                entrada_id=entrada_id,
                payload=body,
                user_id=str(user_id),
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
            "entrada_id": result.entrada_id,
            "registro_id": result.registro_id,
            "houve_anormalidade_nova": result.houve_anormalidade_nova,
        })

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"ok": False, "error": f"internal_error: {e.__class__.__name__}: {e}"},
            status=500,
        )
