import os

from django.apps import AppConfig
from django.conf import settings


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        # Garante que o diretório de uploads exista
        files_dir = getattr(settings, "FILES_DIR", None)
        if files_dir:
            os.makedirs(files_dir, exist_ok=True)
