"""
Utilitários compartilhados entre os services.

Funções auxiliares de limpeza, conversão e formatação
que estavam duplicadas em checklist_service, anormalidade_service,
operacao_service e nos services de relatório.
"""

from datetime import date, datetime, time
from typing import Any, Optional


def clean_str(body: dict, key: str) -> str:
    """(body.get(key) or '').strip() — substitui ~60 ocorrências em 3 services."""
    return (str(body.get(key, "") or "")).strip()


def parse_bool(value: Any) -> Optional[bool]:
    """
    Converte string → bool.
    Unifica _as_bool (anormalidade_service) e _parse_bool (admin_dashboard).
    """
    if isinstance(value, bool):
        return value
    if value is None:
        return None
    s = str(value).strip().lower()
    if s in ("true", "1", "sim", "yes", "y", "t"):
        return True
    if s in ("false", "0", "nao", "não", "no", "n", "f"):
        return False
    return None


def fmt_date(v: Any) -> str:
    """
    Formata data para exibição (DD/MM/YYYY).
    Duplicada entre report_docx, report_pdf e operacao_service.
    """
    if v is None or v == "":
        return "--"
    if isinstance(v, (datetime, date)):
        try:
            return v.strftime("%d/%m/%Y")
        except Exception:
            return str(v)
    return str(v)


def fmt_time(v: Any) -> str:
    """
    Formata hora para exibição (HH:MM).
    Duplicada entre report_docx, report_pdf e operacao_service.
    """
    if v is None or v == "":
        return "--"
    if isinstance(v, time):
        try:
            return v.strftime("%H:%M")
        except Exception:
            return str(v)
    s = str(v)
    if ":" in s and len(s) >= 5:
        return s[:5]
    return s
