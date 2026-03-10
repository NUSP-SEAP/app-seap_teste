from typing import List, Dict, Any
from django.db import connection


def listar_comissoes_ativas() -> List[Dict[str, Any]]:
    sql = """
        SELECT
            c.id,
            c.nome
        FROM cadastro.comissao c
        WHERE c.ativo IS TRUE
        ORDER BY
            COALESCE(c.ordem, 9999),
            c.nome;
    """
    with connection.cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()

    result: List[Dict[str, Any]] = []
    for row in rows:
        result.append(
            {
                "id": row[0],
                "nome": row[1],
            }
        )
    return result