from typing import Optional, Dict, Any
from django.conf import settings
from django.db import connection
import secrets

from .utils import fetchone_dict


def get_user_for_login(usuario: str) -> Optional[Dict[str, Any]]:
    """Busca usuario (admin ou operador) por username ou email para login."""
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
        return fetchone_dict(cur)


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


def session_touch_ok(sid: int, sub: str) -> bool:
    """Atualiza last_activity se a sessao nao estiver revogada e dentro do tempo limite."""
    with connection.cursor() as cur:
        cur.execute(
            '''
            WITH upd AS (
                UPDATE pessoa.auth_sessions
                   SET last_activity = NOW()
                 WHERE id = %s::bigint
                   AND user_id = %s::uuid
                   AND revoked = false
                   AND NOW() - last_activity <= (%s || ' seconds')::interval
                 RETURNING id
            )
            SELECT id FROM upd;
            ''',
            [sid, sub, settings.SESSION_TOUCH_MAX_AGE_SECONDS],
        )
        row = cur.fetchone()
        return bool(row and row[0])