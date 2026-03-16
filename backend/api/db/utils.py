"""
Utilitários de banco de dados — converte resultados de cursor em dicts.

Substitui as implementações duplicadas em db/auth.py, db/admin_dashboard.py, etc.
"""

from typing import Optional

from django.db import connection


def fetchone_dict(cursor):
    """Converte cursor.fetchone() em dict usando cursor.description."""
    row = cursor.fetchone()
    if not row:
        return None
    cols = [col.name for col in cursor.description]
    return dict(zip(cols, row))


def fetchall_dicts(cursor):
    """Converte cursor.fetchall() em lista de dicts."""
    cols = [col.name for col in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]


# Whitelist de combinações schema.tabela → coluna permitidas para ownership check.
# Protege contra SQL injection por interpolação de string.
_OWNER_QUERIES = {
    ("forms.checklist", "criado_por"),
    ("operacao.registro_operacao_operador", "operador_id"),
    ("operacao.registro_anormalidade", "criado_por"),
}


def get_owner_id(table: str, column: str, record_id: int) -> Optional[str]:
    """Retorna o valor da coluna de ownership de um registro, ou None se não encontrado.

    Usa whitelist para evitar SQL injection por interpolação de nomes de tabela/coluna.
    """
    if (table, column) not in _OWNER_QUERIES:
        raise ValueError(f"Combinação não permitida: {table}.{column}")

    sql = f"SELECT {column} FROM {table} WHERE id = %s::bigint"
    with connection.cursor() as cur:
        cur.execute(sql, [record_id])
        row = cur.fetchone()
    return str(row[0]) if row else None
