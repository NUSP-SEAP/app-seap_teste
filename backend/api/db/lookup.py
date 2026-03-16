from django.db import connection

from .utils import fetchall_dicts


def lookup_operadores():
    sql = (
        "SELECT id::text AS id, nome_completo::text AS nome_completo "
        "FROM pessoa.operador "
        "ORDER BY nome_completo ASC;"
    )
    with connection.cursor() as cur:
        cur.execute(sql)
        return fetchall_dicts(cur)


def lookup_salas():
    sql = (
        "SELECT id::text AS id, nome::text AS nome "
        "FROM cadastro.sala "
        "WHERE ativo = true "
        "ORDER BY COALESCE(ordem, 9999), nome ASC, id ASC;"
    )
    with connection.cursor() as cur:
        cur.execute(sql)
        return fetchall_dicts(cur)


def lookup_comissoes():
    """Retorna comissoes ativas ordenadas por ordem e nome."""
    sql = """
        SELECT c.id, c.nome
        FROM cadastro.comissao c
        WHERE c.ativo IS TRUE
        ORDER BY COALESCE(c.ordem, 9999), c.nome;
    """
    with connection.cursor() as cur:
        cur.execute(sql)
        return fetchall_dicts(cur)