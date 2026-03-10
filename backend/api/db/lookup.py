from django.db import connection

def lookup_operadores():
    sql = (
        "SELECT id::text AS id, nome_completo::text AS nome_completo "
        "FROM pessoa.operador "
        "ORDER BY nome_completo ASC;"
    )
    with connection.cursor() as cur:
        cur.execute(sql)
        return [{"id": r[0], "nome_completo": r[1]} for r in cur.fetchall()]


def lookup_salas():
    sql = (
        "SELECT id::text AS id, nome::text AS nome "
        "FROM cadastro.sala "
        "WHERE ativo = true "
        "ORDER BY COALESCE(ordem, 9999), nome ASC, id ASC;"
    )
    with connection.cursor() as cur:
        cur.execute(sql)
        return [{"id": r[0], "nome": r[1]} for r in cur.fetchall()]