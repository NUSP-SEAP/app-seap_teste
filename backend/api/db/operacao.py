# senado_nusp_django/api/db/operacao.py
import json
from django.db import connection
from typing import Any, Dict, List, Optional

from .utils import fetchone_dict, fetchall_dicts

def get_sessao_aberta_por_sala(sala_id: int) -> Optional[Dict[str, Any]]:
    """
    Busca a sessão ABERTA (em_aberto = true) para a sala informada.

    Retorna:
      {
        "id": ...,
        "data": date,
        "sala_id": int,
        "sala_nome": str | None,
        "checklist_do_dia_id": int | None,
        "checklist_do_dia_ok": bool | None,
      }
      ou None se não houver sessão aberta.
    """
    sql = """
    SELECT
        r.id,
        r.data,
        r.sala_id,
        s.nome AS sala_nome,
        r.checklist_do_dia_id,
        r.checklist_do_dia_ok
    FROM operacao.registro_operacao_audio r
    JOIN cadastro.sala s ON s.id = r.sala_id
    WHERE r.sala_id = %s::smallint
      AND r.em_aberto = TRUE
    ORDER BY r.id DESC
    LIMIT 1;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [sala_id])
        return fetchone_dict(cur)

def insert_registro_operacao_audio(
    data_operacao: str,
    sala_id: str,
    criado_por: Optional[str] = None,
) -> int:
    """
    Cria a SESSÃO de operação de áudio (registro da sala).

    Descobre automaticamente o checklist do dia para a sala + data,
    gravando checklist_do_dia_id e checklist_do_dia_ok.
    """
    checklist_do_dia_id: Optional[int] = None
    checklist_do_dia_ok: Optional[bool] = None

    try:
        sala_int = int(sala_id) if sala_id is not None and str(sala_id).strip() != "" else None
    except (TypeError, ValueError):
        sala_int = None

    if data_operacao and sala_int is not None:
        sql_check = """
        SELECT c.id,
               NOT EXISTS (
                   SELECT 1
                     FROM forms.checklist_resposta r
                    WHERE r.checklist_id = c.id
                      AND r.status = 'Falha'
               ) AS ok
          FROM forms.checklist c
         WHERE c.data_operacao = %s::date
           AND c.sala_id = %s::smallint
         ORDER BY c.id DESC
         LIMIT 1;
        """
        try:
            with connection.cursor() as cur:
                cur.execute(sql_check, [data_operacao, sala_int])
                row = fetchone_dict(cur)
            if row:
                checklist_do_dia_id = int(row["id"])
                checklist_do_dia_ok = bool(row["ok"])
        except Exception:
            checklist_do_dia_id = None
            checklist_do_dia_ok = None

    sql = """
    INSERT INTO operacao.registro_operacao_audio (
        data,
        sala_id,
        em_aberto,
        checklist_do_dia_id,
        checklist_do_dia_ok,
        criado_por
    )
    VALUES (
        %s::date,
        %s::smallint,
        TRUE,
        %s::bigint,
        %s::boolean,
        %s::uuid
    )
    RETURNING id;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                data_operacao,
                sala_id,
                checklist_do_dia_id,
                checklist_do_dia_ok,
                criado_por,
            ],
        )
        (new_id,) = cur.fetchone()
        return int(new_id)


def listar_entradas_da_sessao(registro_id: int) -> List[Dict[str, Any]]:
    """
    Lista todas as entradas (operadores) de uma sessão.

    Cada item contém:
      - id, registro_id, operador_id, operador_nome, ordem, seq
      - nome_evento, horario_pauta, horario_inicio, horario_termino, tipo_evento
      - usb_01, usb_02, observacoes, houve_anormalidade
      - anormalidade_id (quando existir registro_anormalidade ligado à entrada)
      - hora_entrada, hora_saida (horários da operação do operador)
    """
    sql = """
    SELECT
        e.id,
        e.registro_id,
        e.operador_id,
        o.nome_completo AS operador_nome,
        e.ordem,
        e.seq,
        e.nome_evento,
        e.horario_pauta,
        e.horario_inicio,
        e.horario_termino,
        e.tipo_evento,
        e.usb_01,
        e.usb_02,
        e.observacoes,
        (a.id IS NOT NULL) AS houve_anormalidade,
        a.id AS anormalidade_id,
        e.comissao_id,
        e.responsavel_evento,
        e.hora_entrada,
        e.hora_saida
    FROM operacao.registro_operacao_operador e
    JOIN pessoa.operador o ON o.id = e.operador_id
    LEFT JOIN operacao.registro_anormalidade a
           ON a.entrada_id = e.id
    WHERE e.registro_id = %s::bigint
    ORDER BY e.ordem ASC, e.id ASC;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [registro_id])
        return fetchall_dicts(cur)

def insert_registro_operacao_operador(
    registro_id: int,
    operador_id: str,
    ordem: int,
    hora_entrada: Optional[str],
    hora_saida: Optional[str],
    nome_evento: Optional[str],
    horario_pauta: Optional[str],
    horario_inicio: Optional[str],
    horario_termino: Optional[str],
    tipo_evento: str,
    seq: int,
    observacoes: Optional[str],
    usb_01: Optional[str],
    usb_02: Optional[str],
    comissao_id: Optional[int],
    responsavel_evento: Optional[str],
    criado_por: Optional[str],
    atualizado_por: Optional[str],
) -> int:
    """
    Insere uma ENTRADA de operador na sessão de operação de áudio.

    houve_anormalidade é controlada pelo trigger
    operacao.sync_houve_anormalidade (tabela operacao.registro_anormalidade).
    """
    sql = """
    INSERT INTO operacao.registro_operacao_operador (
        registro_id,
        operador_id,
        ordem,
        hora_entrada,
        hora_saida,
        nome_evento,
        horario_pauta,
        horario_inicio,
        horario_termino,
        tipo_evento,
        seq,
        houve_anormalidade,
        observacoes,
        usb_01,
        usb_02,
        comissao_id,
        responsavel_evento,
        criado_por,
        atualizado_por
    )
    VALUES (
        %s::bigint,
        %s::uuid,
        %s::smallint,
        %s::time,
        %s::time,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::time,
        %s::time,
        %s::time,
        %s::text,
        %s::smallint,
        FALSE,
        NULLIF(BTRIM(%s::text), '')::text,
        NULLIF(BTRIM(%s::text), '')::text,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::bigint,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::uuid,
        %s::uuid
    )
    RETURNING id;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                registro_id,
                operador_id,
                ordem,
                hora_entrada,
                hora_saida,
                nome_evento,
                horario_pauta,
                horario_inicio,
                horario_termino,
                tipo_evento,
                seq,
                observacoes,
                usb_01,
                usb_02,
                comissao_id,
                responsavel_evento,
                criado_por,
                atualizado_por,
            ],
        )
        (new_id,) = cur.fetchone()
        return int(new_id)


def update_registro_operacao_operador(
    entrada_id: int,
    nome_evento: Optional[str],
    horario_pauta: Optional[str],
    horario_inicio: Optional[str],
    horario_termino: Optional[str],
    tipo_evento: str,
    observacoes: Optional[str],
    usb_01: Optional[str],
    usb_02: Optional[str],
    comissao_id: Optional[int],
    responsavel_evento: Optional[str],
    hora_entrada: Optional[str] = None,
    hora_saida: Optional[str] = None,
    atualizado_por: Optional[str] = None,
) -> None:
    """
    Atualiza uma entrada de operador em operacao.registro_operacao_operador.

    houve_anormalidade é controlada por trigger, não atualizada aqui.
    """
    sql = """
    UPDATE operacao.registro_operacao_operador
       SET nome_evento        = NULLIF(BTRIM(%s::text), '')::text,
           horario_pauta      = %s::time,
           horario_inicio     = %s::time,
           horario_termino    = %s::time,
           tipo_evento        = %s::text,
           observacoes        = NULLIF(BTRIM(%s::text), '')::text,
           usb_01             = NULLIF(BTRIM(%s::text), '')::text,
           usb_02             = NULLIF(BTRIM(%s::text), '')::text,
           comissao_id        = %s::bigint,
           responsavel_evento = NULLIF(BTRIM(%s::text), '')::text,
           hora_entrada       = %s::time,
           hora_saida         = %s::time,
           atualizado_por     = %s::uuid,
           atualizado_em      = now()
     WHERE id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                nome_evento,
                horario_pauta,
                horario_inicio,
                horario_termino,
                tipo_evento,
                observacoes,
                usb_01,
                usb_02,
                comissao_id,
                responsavel_evento,
                hora_entrada,
                hora_saida,
                atualizado_por,
                entrada_id,
            ],
        )


def finalizar_sessao_operacao_audio(
    registro_id: int,
    fechado_por: Optional[str],
) -> None:
    """
    Marca uma sessão de operação de áudio como encerrada.

    - em_aberto = false
    - fechado_em = NOW()
    - fechado_por = usuário que disparou a finalização.
    """
    sql = """
    UPDATE operacao.registro_operacao_audio
       SET em_aberto   = false,
           fechado_em  = NOW(),
           fechado_por = %s::uuid
     WHERE id = %s::bigint
       AND em_aberto = true;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [fechado_por, registro_id])


def get_entrada_operacao_snapshot(entrada_id: int) -> Dict[str, Any]:
    """
    Captura o estado atual completo de uma entrada de operador
    para armazenamento no histórico antes de uma edição.

    Retorna dict com tipos nativos do PostgreSQL; o chamador
    serializa com json.dumps(snapshot, default=str).
    """
    with connection.cursor() as cur:
        cur.execute("""
            SELECT e.nome_evento, e.responsavel_evento, e.horario_pauta,
                   e.horario_inicio, e.horario_termino, e.tipo_evento,
                   e.usb_01, e.usb_02, e.observacoes, e.comissao_id,
                   e.houve_anormalidade, r.sala_id,
                   e.hora_entrada, e.hora_saida
              FROM operacao.registro_operacao_operador e
              JOIN operacao.registro_operacao_audio r ON r.id = e.registro_id
             WHERE e.id = %s::bigint
        """, [entrada_id])
        return fetchone_dict(cur) or {}


def insert_entrada_operacao_historico(
    entrada_id: int,
    snapshot: Dict[str, Any],
    editado_por: Optional[str] = None,
) -> None:
    """
    Insere um registro no histórico de edições com o snapshot anterior.
    """
    sql = """
        INSERT INTO operacao.registro_operacao_operador_historico
            (entrada_id, snapshot, editado_por)
        VALUES (%s::bigint, %s::jsonb, %s::uuid)
    """
    with connection.cursor() as cur:
        cur.execute(sql, [
            entrada_id,
            json.dumps(snapshot, default=str),
            editado_por,
        ])


def update_entrada_operacao_detalhe(
    entrada_id: int,
    campos: Dict[str, Any],
    atualizado_por: Optional[str] = None,
) -> None:
    """
    Atualiza os campos editáveis de uma entrada de operador e marca como editada.
    observacoes_editado só é marcado TRUE se o valor realmente mudou (IS DISTINCT FROM).
    NÃO atualiza houve_anormalidade (controlado por trigger).
    """
    sql = """
        UPDATE operacao.registro_operacao_operador
           SET nome_evento        = NULLIF(BTRIM(%s::text), '')::text,
               responsavel_evento = NULLIF(BTRIM(%s::text), '')::text,
               horario_pauta      = %s::time,
               horario_inicio     = %s::time,
               horario_termino    = %s::time,
               usb_01             = NULLIF(BTRIM(%s::text), '')::text,
               usb_02             = NULLIF(BTRIM(%s::text), '')::text,
               observacoes        = NULLIF(BTRIM(%s::text), '')::text,
               comissao_id        = %s::bigint,
               tipo_evento        = %s::text,
               hora_entrada       = %s::time,
               hora_saida         = %s::time,
               editado            = TRUE,
               nome_evento_editado = nome_evento_editado OR (
                   COALESCE(nome_evento, '') IS DISTINCT FROM
                   COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               responsavel_evento_editado = responsavel_evento_editado OR (
                   COALESCE(responsavel_evento, '') IS DISTINCT FROM
                   COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               horario_pauta_editado = horario_pauta_editado OR (
                   horario_pauta IS DISTINCT FROM %s::time
               ),
               horario_inicio_editado = horario_inicio_editado OR (
                   horario_inicio IS DISTINCT FROM %s::time
               ),
               horario_termino_editado = horario_termino_editado OR (
                   horario_termino IS DISTINCT FROM %s::time
               ),
               usb_01_editado = usb_01_editado OR (
                   COALESCE(usb_01, '') IS DISTINCT FROM
                   COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               usb_02_editado = usb_02_editado OR (
                   COALESCE(usb_02, '') IS DISTINCT FROM
                   COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               observacoes_editado = observacoes_editado OR (
                   COALESCE(observacoes, '') IS DISTINCT FROM
                   COALESCE(NULLIF(BTRIM(%s::text), ''), '')
               ),
               comissao_editado = comissao_editado OR (
                   comissao_id IS DISTINCT FROM %s::bigint
               ),
               hora_entrada_editado = hora_entrada_editado OR (
                   hora_entrada IS DISTINCT FROM %s::time
               ),
               hora_saida_editado = hora_saida_editado OR (
                   hora_saida IS DISTINCT FROM %s::time
               ),
               atualizado_por     = %s::uuid,
               atualizado_em      = now()
         WHERE id = %s::bigint
    """
    with connection.cursor() as cur:
        ne = campos.get("nome_evento")
        re = campos.get("responsavel_evento")
        hp = campos.get("horario_pauta")
        hi = campos.get("horario_inicio")
        ht = campos.get("horario_termino")
        u1 = campos.get("usb_01")
        u2 = campos.get("usb_02")
        ob = campos.get("observacoes")
        ci = campos.get("comissao_id")
        te = campos.get("tipo_evento", "operacao")
        he = campos.get("hora_entrada")
        hs = campos.get("hora_saida")
        cur.execute(sql, [
            ne, re, hp, hi, ht, u1, u2, ob, ci, te, he, hs,
            # IS DISTINCT FROM comparisons (mesmos valores):
            ne, re, hp, hi, ht, u1, u2, ob, ci, he, hs,
            atualizado_por,
            entrada_id,
        ])


def update_sala_registro_operacao_audio(
    entrada_id: int,
    novo_sala_id: int,
) -> None:
    """
    Atualiza o sala_id no registro_operacao_audio associado à entrada.
    Também marca sala_editado = TRUE na entrada do operador.
    Só deve ser chamada quando total_entradas = 1.
    """
    with connection.cursor() as cur:
        # Marca sala_editado na entrada do operador (ANTES de alterar a sala)
        cur.execute("""
            UPDATE operacao.registro_operacao_operador e
               SET sala_editado = sala_editado OR (
                   (SELECT r.sala_id FROM operacao.registro_operacao_audio r
                     WHERE r.id = e.registro_id)
                   IS DISTINCT FROM %s::smallint
               )
             WHERE e.id = %s::bigint
        """, [novo_sala_id, entrada_id])

        # Atualiza sala_id no registro_operacao_audio
        cur.execute("""
            UPDATE operacao.registro_operacao_audio
               SET sala_id = %s::smallint
             WHERE id = (
                SELECT registro_id
                  FROM operacao.registro_operacao_operador
                 WHERE id = %s::bigint
             )
        """, [novo_sala_id, entrada_id])


def count_entradas_por_sessao(entrada_id: int) -> int:
    """
    Conta quantas entradas de operador existem na mesma sessão
    (registro_operacao_audio) da entrada informada.
    """
    with connection.cursor() as cur:
        cur.execute("""
            SELECT COUNT(*)
              FROM operacao.registro_operacao_operador
             WHERE registro_id = (
                SELECT registro_id
                  FROM operacao.registro_operacao_operador
                 WHERE id = %s::bigint
             )
        """, [entrada_id])
        row = cur.fetchone()
        return int(row[0]) if row else 0


def get_registro_id_by_entrada(entrada_id: int) -> Optional[int]:
    """
    Retorna o registro_id (sessão) de uma entrada de operador.
    """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT registro_id FROM operacao.registro_operacao_operador WHERE id = %s::bigint",
            [entrada_id],
        )
        row = cur.fetchone()
        return int(row[0]) if row else None


def get_operador_id_by_entrada(entrada_id: int) -> Optional[str]:
    """
    Retorna o operador_id de uma entrada de operador (para verificação de ownership).
    """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT operador_id FROM operacao.registro_operacao_operador WHERE id = %s::bigint",
            [entrada_id],
        )
        row = cur.fetchone()
        return str(row[0]) if row else None
