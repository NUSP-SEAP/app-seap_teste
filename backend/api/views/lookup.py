from django.http import HttpRequest, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET

from .. import db


@csrf_exempt
@require_GET
def lookup_operadores(request: HttpRequest):
    rows = db.lookup_operadores()
    return JsonResponse({"ok": True, "data": rows})


@csrf_exempt
@require_GET
def lookup_salas(request: HttpRequest):
    rows = db.lookup_salas()
    return JsonResponse({"ok": True, "data": rows})


@csrf_exempt
@require_GET
def comissoes_lookup_view(request: HttpRequest):
    rows = db.lookup_comissoes()
    return JsonResponse({"ok": True, "data": rows})
