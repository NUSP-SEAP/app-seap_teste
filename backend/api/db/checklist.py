import json
from django.db import connection
from typing import Optional, Dict, Any, List

def checklist_item_tipo_map() -> Dict[str, int]:
    """
    Retorna um dicionário: { nome_do_item: id } usando forms.checklist_item_tipo.
    """
    sql = """
    SELECT nome::text, id::smallint
      FROM forms.checklist_item_tipo
     ORDER BY nome ASC, id ASC;
    """
    with connection.cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
        return { (r[0] or "").strip(): int(r[1]) for r in rows }

def insert_checklist(
    data_operacao: str,
    sala_id: int,
    turno: str,
    hora_inicio_testes: str,
    hora_termino_testes: str,
    observacoes: Optional[str] = None,
    usb_01: Optional[str] = None,
    usb_02: Optional[str] = None,
    criado_por: Optional[str] = None,
    atualizado_por: Optional[str] = None,
) -> int:
    """
    Insere o cabeçalho do checklist em forms.checklist e retorna o id (bigint).

    Agora grava também:
      - usb_01, usb_02 (text)
      - criado_por, atualizado_por (uuid)
    """
    sql = """
    INSERT INTO forms.checklist (
        data_operacao,
        sala_id,
        turno,
        hora_inicio_testes,
        hora_termino_testes,
        observacoes,
        usb_01,
        usb_02,
        criado_por,
        atualizado_por
    )
    VALUES (
        %s::date,
        %s::smallint,
        %s::text,
        %s::time,
        %s::time,
        NULLIF(BTRIM(%s::text), ''),
        NULLIF(BTRIM(%s::text), ''),
        NULLIF(BTRIM(%s::text), ''),
        %s::uuid,
        %s::uuid
    )
    RETURNING id;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [
            data_operacao,
            sala_id,
            turno,
            hora_inicio_testes,
            hora_termino_testes,
            observacoes or "",
            usb_01 or "",
            usb_02 or "",
            criado_por,
            atualizado_por,
        ])
        (new_id,) = cur.fetchone()
        return int(new_id)


def insert_checklist_respostas(
    checklist_id: int,
    itens: List[Dict[str, Any]],
    criado_por: Optional[str] = None,
    atualizado_por: Optional[str] = None,
) -> int:
    """
    Insere as respostas em forms.checklist_resposta.

    Param:
      - checklist_id: id do cabeçalho já inserido
      - itens: lista de objetos { item_tipo_id, status, descricao_falha, valor_texto }
      - criado_por / atualizado_por: autoria (uuid) – opcional

    Observações:
      - 'status' deve ser 'Ok' ou 'Falha' (há CHECK no banco).
      - Se o item for do tipo texto e tiver 'valor_texto', status é gravado como 'Ok'.
    """
    # Carrega mapa para fallback (caso venha apenas o nome)
    tipos_map = checklist_item_tipo_map()
    
    rows: List[tuple] = []
    for it in (itens or []):
        # 1. Tenta resolver o ID do item
        tipo_id = it.get("item_tipo_id")
        if not tipo_id:
            # Fallback: tenta pelo nome
            nome = (it.get("nome") or "").strip()
            tipo_id = tipos_map.get(nome)
        
        if not tipo_id:
            # Ignora itens não identificados
            continue

        # 2. Leitura dos campos
        status = (it.get("status") or "").strip()
        desc = (it.get("descricao_falha") or "").strip()
        valor_texto = (it.get("valor_texto") or "").strip()

        # 3. Regra para itens de texto:
        # Se tem texto preenchido e não veio status explícito, assume 'Ok'
        if not status and valor_texto:
            status = "Ok"

        if not status:
            continue

        rows.append((
            checklist_id,
            int(tipo_id),
            status,
            desc,
            valor_texto,
            criado_por,
            atualizado_por,
        ))

    if not rows:
        return 0

    with connection.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO forms.checklist_resposta (
                checklist_id,
                item_tipo_id,
                status,
                descricao_falha,
                valor_texto,
                criado_por,
                atualizado_por
            )
            VALUES (
                %s::bigint,
                %s::smallint,
                %s::text,
                NULLIF(BTRIM(%s::text), ''),
                NULLIF(BTRIM(%s::text), ''),
                %s::uuid,
                %s::uuid
            );
            """,
            rows
        )
        return cur.rowcount

def list_checklist_item_tipo() -> List[Dict[str, Any]]:
    """
    Retorna a lista de todos os tipos de item do catálogo.
    """
    sql = """
    SELECT id, nome, tipo_widget
      FROM forms.checklist_item_tipo
     ORDER BY nome ASC, id ASC;
    """
    with connection.cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()

    return [
        {"id": row[0], "nome": row[1], "tipo_widget": row[2]}
        for row in rows
    ]

def list_checklist_itens_por_sala(sala_id: int) -> List[Dict[str, Any]]:
    """
    Retorna os itens ativos configurados para uma sala,
    incluindo o tipo do widget (radio ou text).
    """
    sql = """
    SELECT t.id, t.nome::text, c.ordem, t.tipo_widget
      FROM forms.checklist_sala_config c
      JOIN forms.checklist_item_tipo t ON c.item_tipo_id = t.id
     WHERE c.sala_id = %s
       AND c.ativo = true
     ORDER BY c.ordem ASC, t.id ASC;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [sala_id])
        rows = cur.fetchall()

    return [
        {"id": row[0], "nome": row[1], "ordem": row[2], "tipo_widget": row[3]}
        for row in rows
    ]


# ──────────────────────────────────────────────
#  Funções de edição de checklist
# ──────────────────────────────────────────────

def get_checklist_snapshot(checklist_id: int) -> Dict[str, Any]:
    """
    Captura o estado atual completo de um checklist (header + respostas)
    para armazenamento no histórico antes de uma edição.
    """
    with connection.cursor() as cur:
        cur.execute("""
            SELECT data_operacao, sala_id, turno, hora_inicio_testes,
                   hora_termino_testes, observacoes, usb_01, usb_02
              FROM forms.checklist
             WHERE id = %s::bigint
        """, [checklist_id])
        cols = [c[0] for c in cur.description]
        row = cur.fetchone()
        header = dict(zip(cols, row)) if row else {}
        for k, v in header.items():
            if hasattr(v, 'isoformat'):
                header[k] = v.isoformat()
            elif v is not None:
                header[k] = str(v)

    with connection.cursor() as cur:
        cur.execute("""
            SELECT id AS resposta_id, item_tipo_id, status,
                   descricao_falha, valor_texto
              FROM forms.checklist_resposta
             WHERE checklist_id = %s::bigint
        """, [checklist_id])
        cols = [c[0] for c in cur.description]
        itens = [dict(zip(cols, r)) for r in cur.fetchall()]

    return {"header": header, "itens": itens}


def insert_checklist_historico(
    checklist_id: int,
    snapshot: Dict[str, Any],
    editado_por: Optional[str] = None,
) -> None:
    """
    Insere um registro no histórico de edições com o snapshot anterior.
    """
    sql = """
        INSERT INTO forms.checklist_historico (checklist_id, snapshot, editado_por)
        VALUES (%s::bigint, %s::jsonb, %s::uuid)
    """
    with connection.cursor() as cur:
        cur.execute(sql, [
            checklist_id,
            json.dumps(snapshot, default=str),
            editado_por,
        ])


def update_checklist(
    checklist_id: int,
    data_operacao: str,
    sala_id: int,
    observacoes: Optional[str] = None,
    atualizado_por: Optional[str] = None,
) -> None:
    """
    Atualiza o cabeçalho do checklist e marca como editado.
    observacoes_editado só é marcado TRUE se o valor realmente mudou.
    """
    sql = """
        UPDATE forms.checklist
           SET data_operacao       = %s::date,
               sala_id            = %s::smallint,
               observacoes        = NULLIF(BTRIM(%s::text), ''),
               editado            = TRUE,
               observacoes_editado = observacoes_editado OR (
                   COALESCE(observacoes, '') IS DISTINCT FROM COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               atualizado_por     = %s::uuid,
               atualizado_em      = now()
         WHERE id = %s::bigint
    """
    with connection.cursor() as cur:
        cur.execute(sql, [
            data_operacao,
            sala_id,
            observacoes or "",
            observacoes or "",  # para comparação
            atualizado_por,
            checklist_id,
        ])


def update_checklist_respostas(
    checklist_id: int,
    itens: List[Dict[str, Any]],
    atualizado_por: Optional[str] = None,
) -> int:
    """
    Atualiza as respostas de um checklist existente.
    Marca cada resposta como editada SOMENTE se os valores realmente mudaram
    (usa IS DISTINCT FROM para comparação segura incluindo NULLs).
    """
    sql = """
        UPDATE forms.checklist_resposta
           SET status          = %s::text,
               descricao_falha = NULLIF(BTRIM(%s::text), ''),
               valor_texto     = NULLIF(BTRIM(%s::text), ''),
               editado         = editado OR (
                   status IS DISTINCT FROM %s::text
                   OR descricao_falha IS DISTINCT FROM NULLIF(BTRIM(%s::text), '')
                   OR valor_texto IS DISTINCT FROM NULLIF(BTRIM(%s::text), '')
               ),
               atualizado_por  = %s::uuid,
               atualizado_em   = now()
         WHERE checklist_id = %s::bigint
           AND item_tipo_id = %s::smallint
    """
    rows = []
    for it in (itens or []):
        item_tipo_id = it.get("item_tipo_id")
        status = (it.get("status") or "").strip()
        desc = (it.get("descricao_falha") or "").strip()
        valor = (it.get("valor_texto") or "").strip()

        # Regra para itens de texto: se tem texto e sem status, assume 'Ok'
        if not status and valor:
            status = "Ok"

        if not item_tipo_id or not status:
            continue

        # Valores passados 2x: para SET e para comparação IS DISTINCT FROM
        rows.append((
            status, desc, valor,       # SET
            status, desc, valor,       # comparação
            atualizado_por,
            checklist_id,
            int(item_tipo_id),
        ))

    if not rows:
        return 0

    with connection.cursor() as cur:
        cur.executemany(sql, rows)
        return cur.rowcount