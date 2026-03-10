"""
Job para limpar item_tipo órfãos (não usados por nenhuma sala e sem histórico).
Executar diariamente via cron ou scheduler.

Uso manual:
    python manage.py shell -c \
        "from api.jobs.cleanup_orphan_items import cleanup_orphan_item_tipos; print(cleanup_orphan_item_tipos())"
"""

from django.db import connection, transaction
import logging

logger = logging.getLogger(__name__)


def cleanup_orphan_item_tipos() -> int:
    """
    Remove item_tipo que:
    - Não tem referências em checklist_sala_config
    - Não tem referências em checklist_resposta (histórico)

    Returns:
        Número de registros deletados
    """
    sql = """
        DELETE FROM forms.checklist_item_tipo
        WHERE id NOT IN (
            SELECT DISTINCT item_tipo_id FROM forms.checklist_sala_config
        )
        AND id NOT IN (
            SELECT DISTINCT item_tipo_id FROM forms.checklist_resposta
        )
        RETURNING id;
    """

    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute(sql)
            deleted_ids = [row[0] for row in cur.fetchall()]
            count = len(deleted_ids)

            if count > 0:
                logger.info(
                    "Cleanup: removidos %d item_tipo órfãos: %s",
                    count, deleted_ids,
                )

            return count
