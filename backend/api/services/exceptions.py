"""
Exceções compartilhadas entre os services.

Centraliza ServiceValidationError que estava duplicada em
checklist_service.py, anormalidade_service.py e operacao_service.py.
"""

from typing import Any, Dict, Optional


class ServiceValidationError(Exception):
    """
    Erro de validação de regra de negócio.
    As views capturam isso e devolvem HTTP 400 com o payload apropriado.
    """

    def __init__(
        self,
        code: str,
        message: str,
        extra: Optional[Dict[str, Any]] = None,
        errors: Optional[Dict[str, str]] = None,
    ):
        super().__init__(message)
        self.code = code
        self.message = message
        self.extra = extra or {}
        self.errors = errors
