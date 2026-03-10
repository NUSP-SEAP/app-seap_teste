import json
from django.http import JsonResponse

def json_error(status: int, data: dict):
    resp = JsonResponse(data)
    resp.status_code = status
    return resp

def parse_json_body(request):
    try:
        if request.body:
            return json.loads(request.body.decode('utf-8'))
    except Exception:
        pass
    return {}
