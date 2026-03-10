from __future__ import annotations

from typing import Callable, Optional

from django.http import HttpRequest, HttpResponse, JsonResponse


PDF_MIME = "application/pdf"
DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"


def get_report_format(request: HttpRequest) -> str:
    """
    Lê ?format=pdf|docx (aceita também ".pdf" e ".docx").
    Default: pdf
    """
    raw = (request.GET.get("format") or "").strip().lower()
    if not raw:
        return "pdf"
    if raw.startswith("."):
        raw = raw[1:]
    if raw in ("pdf", "docx"):
        return raw
    return "invalid"


def respond(
    request: HttpRequest,
    *,
    filename_base: str,
    pdf_builder: Callable[[], bytes],
    docx_builder: Optional[Callable[[], bytes]] = None,
    pdf_inline: bool = True,
) -> HttpResponse:
    """
    Decide o formato baseado em ?format= e devolve HttpResponse com headers corretos.

    - PDF: inline por padrão (abre no browser)
    - DOCX: attachment (download)
    """
    fmt = get_report_format(request)
    if fmt == "invalid":
        return JsonResponse({"ok": False, "error": "invalid_format"}, status=400)

    if fmt == "docx":
        if docx_builder is None:
            return JsonResponse({"ok": False, "error": "format_not_supported"}, status=400)
        data = docx_builder()
        resp = HttpResponse(data, content_type=DOCX_MIME)
        resp["Content-Disposition"] = f'attachment; filename="{filename_base}.docx"'
        return resp

    # default pdf
    data = pdf_builder()
    resp = HttpResponse(data, content_type=PDF_MIME)
    dispo = "inline" if pdf_inline else "attachment"
    resp["Content-Disposition"] = f'{dispo}; filename="{filename_base}.pdf"'
    return resp