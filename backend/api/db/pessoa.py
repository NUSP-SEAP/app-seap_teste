from typing import Dict

from django.db import connection


# ========= OPERADOR =========

def exists_operador_email(email: str) -> bool:
    sql = """
        SELECT EXISTS(
            SELECT 1
              FROM pessoa.operador
             WHERE lower(email) = lower(%s)
        );
    """
    with connection.cursor() as cur:
        cur.execute(sql, [email])
        return bool(cur.fetchone()[0])


def exists_operador_username(username: str) -> bool:
    sql = """
        SELECT EXISTS(
            SELECT 1
              FROM pessoa.operador
             WHERE lower(username) = lower(%s)
        );
    """
    with connection.cursor() as cur:
        cur.execute(sql, [username])
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
            nome_completo,
            nome_exibicao,
            email,
            username,
            password_hash,
            foto_url
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
            id::text,
            nome_completo::text,
            nome_exibicao::text,
            email::text,
            username::text,
            COALESCE(foto_url, '')::text;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [nome_completo, nome_exibicao, email, username, password_hash, foto_url or ""])
        r = cur.fetchone()
        return {
            "id": r[0],
            "nome_completo": r[1],
            "nome_exibicao": r[2],
            "email": r[3],
            "username": r[4],
            "foto_url": r[5],
        }

def get_foto_url_by_id(user_id: str, role: str) -> str:
    """Retorna a foto_url do usuário (operador ou administrador). Vazia se não encontrar."""
    if role == "operador":
        sql = "SELECT COALESCE(foto_url, '')::text FROM pessoa.operador WHERE id = %s::uuid;"
    else:
        return ""
    with connection.cursor() as cur:
        cur.execute(sql, [user_id])
        row = cur.fetchone()
        return row[0] if row else ""


# ========= ADMINISTRADOR =========

def exists_admin_email(email: str) -> bool:
    sql = """
        SELECT EXISTS(
            SELECT 1
              FROM pessoa.administrador
             WHERE lower(email) = lower(%s)
        );
    """
    with connection.cursor() as cur:
        cur.execute(sql, [email])
        return bool(cur.fetchone()[0])


def exists_admin_username(username: str) -> bool:
    sql = """
        SELECT EXISTS(
            SELECT 1
              FROM pessoa.administrador
             WHERE lower(username) = lower(%s)
        );
    """
    with connection.cursor() as cur:
        cur.execute(sql, [username])
        return bool(cur.fetchone()[0])


def insert_administrador(
    nome_completo: str,
    email: str,
    username: str,
    password_hash: str,
) -> Dict[str, str]:
    sql = """
        INSERT INTO pessoa.administrador (
            nome_completo,
            email,
            username,
            password_hash
        )
        VALUES (
            %s::text,
            lower(%s::text),
            lower(%s::text),
            %s::text
        )
        RETURNING
            id::text,
            nome_completo::text,
            email::text,
            username::text;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [nome_completo, email, username, password_hash])
        r = cur.fetchone()
        return {
            "id": r[0],
            "nome_completo": r[1],
            "email": r[2],
            "username": r[3],
        }
