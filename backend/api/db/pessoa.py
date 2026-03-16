from typing import Dict, Optional

from django.db import connection

from .utils import fetchone_dict

# Tabelas validas para exists_user (whitelist para evitar SQL injection)
_VALID_TABLES = {"pessoa.operador", "pessoa.administrador"}
_VALID_FIELDS = {"email", "username"}


def exists_user(table: str, field: str, value: str) -> bool:
    """Verifica se ja existe um usuario com o campo/valor na tabela especificada."""
    if table not in _VALID_TABLES:
        raise ValueError(f"Tabela invalida: {table}")
    if field not in _VALID_FIELDS:
        raise ValueError(f"Campo invalido: {field}")
    sql = f"SELECT EXISTS(SELECT 1 FROM {table} WHERE lower({field}) = lower(%s));"
    with connection.cursor() as cur:
        cur.execute(sql, [value])
        return bool(cur.fetchone()[0])



def insert_operador(
    nome_completo: str,
    nome_exibicao: str,
    email: str,
    username: str,
    password_hash: str,
    foto_url: str,
) -> Dict[str, str]:
    sql = """
        INSERT INTO pessoa.operador (
            nome_completo, nome_exibicao, email, username, password_hash, foto_url
        )
        VALUES (
            %s::text,
            BTRIM(%s::text),
            lower(%s::text),
            lower(%s::text),
            %s::text,
            NULLIF(BTRIM(%s::text), '')
        )
        RETURNING
            id::text, nome_completo::text, nome_exibicao::text,
            email::text, username::text, COALESCE(foto_url, '')::text AS foto_url;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [nome_completo, nome_exibicao, email, username, password_hash, foto_url or ""])
        return fetchone_dict(cur)


def get_foto_url_by_id(user_id: str, role: str) -> str:
    """Retorna a foto_url do usuario (operador ou administrador). Vazia se nao encontrar."""
    if role == "operador":
        sql = "SELECT COALESCE(foto_url, '')::text AS foto_url FROM pessoa.operador WHERE id = %s::uuid;"
    else:
        return ""
    with connection.cursor() as cur:
        cur.execute(sql, [user_id])
        row = cur.fetchone()
        return row[0] if row else ""


def insert_administrador(
    nome_completo: str,
    email: str,
    username: str,
    password_hash: str,
) -> Dict[str, str]:
    sql = """
        INSERT INTO pessoa.administrador (
            nome_completo, email, username, password_hash
        )
        VALUES (
            %s::text,
            lower(%s::text),
            lower(%s::text),
            %s::text
        )
        RETURNING
            id::text, nome_completo::text, email::text, username::text;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [nome_completo, email, username, password_hash])
        return fetchone_dict(cur)
