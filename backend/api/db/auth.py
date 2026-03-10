from typing import Optional, Dict, Any
from django.db import connection
import secrets

def fetchone_dict(cur) -> Optional[Dict[str, Any]]:
    row = cur.fetchone()
    if not row:
        return None
    desc = [c[0] for c in cur.description]
    return dict(zip(desc, row))

def get_user_for_login(usuario: str) -> Optional[Dict[str, Any]]:
    # União de administrador e operador, como no n8n
    sql = '''
    SELECT * FROM (
      SELECT
        'administrador'::text AS perfil,
        a.id::text, a.nome_completo::text, a.username::text, a.email::text,
        a.password_hash::text AS password_hash
      FROM pessoa.administrador a
      WHERE (a.username = %s OR a.email = %s)
      UNION ALL
      SELECT
        'operador'::text AS perfil,
        o.id::text, o.nome_completo::text, o.username::text, o.email::text,
        o.password_hash::text AS password_hash
      FROM pessoa.operador o
      WHERE (o.username = %s OR o.email = %s)
    ) u
    LIMIT 1;
    '''
    with connection.cursor() as cur:
        cur.execute(sql, [usuario, usuario, usuario, usuario])
        row = fetchone_dict(cur)
        if not row:
            return None
        # Normaliza chaves
        return {
            "perfil": row["perfil"],
            "id": row["id"],
            "nome_completo": row["nome_completo"],
            "username": row["username"],
            "email": row["email"],
            "password_hash": row["password_hash"],
        }
    
def create_session(user_id: str) -> int:
    """
    Cria uma sessão em pessoa.auth_sessions com um refresh_token_hash aleatório.
    Isso evita colisões na UNIQUE 'uq_auth_sessions_rth'.
    """
    sql = '''
    INSERT INTO pessoa.auth_sessions (user_id, refresh_token_hash, created_at, last_activity, revoked)
    VALUES (%s::uuid, %s::text, NOW(), NOW(), false)
    RETURNING id;
    '''
    # 128 bits de entropia, 32 caracteres hex – praticamente impossível colidir
    refresh_token_hash = secrets.token_hex(16)

    with connection.cursor() as cur:
        cur.execute(sql, [user_id, refresh_token_hash])
        sid = cur.fetchone()[0]

    return int(sid)

def revoke_session(sid: int, user_id: str) -> int:
    sql = "UPDATE pessoa.auth_sessions SET revoked = true WHERE id = %s::bigint AND user_id = %s::uuid AND revoked = false;"
    with connection.cursor() as cur:
        cur.execute(sql, [sid, user_id])
        return cur.rowcount