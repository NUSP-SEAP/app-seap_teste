from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status

from ..utils import json_error
from .. import db

from api.db import cadastro_comissao

@csrf_exempt
def lookup_operadores(request: HttpRequest):
    # GET /forms/lookup/operadores
    if request.method not in ["GET"]:
        return json_error(405, {"error": "method_not_allowed"})
    rows = db.lookup_operadores()
    return JsonResponse({"data": rows})

@csrf_exempt
def lookup_salas(request: HttpRequest):
    # GET /forms/lookup/salas
    if request.method not in ["GET"]:
        return json_error(405, {"error": "method_not_allowed"})
    rows = db.lookup_salas()
    return JsonResponse({"data": rows})

@csrf_exempt
def comissoes_lookup_view(request: HttpRequest):
    # GET /forms/lookup/comissoes
    if request.method not in ["GET"]:
        return json_error(405, {"error": "method_not_allowed"})
    rows = cadastro_comissao.listar_comissoes_ativas()
    return JsonResponse({"data": rows})

# @api_view(["GET"])
# def comissoes_lookup_view(request: HttpRequest):
#     try:
#         rows = cadastro_comissao.listar_comissoes_ativas()
#     except Exception:
#         return Response(
#             {"ok": False, "message": "Erro ao buscar comissões."},
#             status=status.HTTP_500_INTERNAL_SERVER_ERROR,
#         )

#     return Response({"ok": True, "data": rows}, status=status.HTTP_200_OK)