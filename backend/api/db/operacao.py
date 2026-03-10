# senado_nusp_django/api/db/operacao.py
import json
from django.db import connection
from typing import Any, Dict, List, Optional

from .auth import fetchone_dict

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
        row = cur.fetchone()
        if not row:
            return None
        return {
            "id": row[0],
            "data": row[1],
            "sala_id": row[2],
            "sala_nome": row[3],
            "checklist_do_dia_id": row[4],
            "checklist_do_dia_ok": row[5],
        }

def insert_registro_operacao_audio(
    data_operacao: str,
    nome_evento: Optional[str],
    sala_id: str,
    horario_pauta: Optional[str],
    hora_inicio: Optional[str],
    hora_fim: Optional[str],
    tipo_evento: Optional[str] = None,
    houve_anormalidade: Optional[bool] = None,
    observacoes: Optional[str] = None,
    usb_01: Optional[str] = None,
    usb_02: Optional[str] = None,
    criado_por: Optional[str] = None,
    atualizado_por: Optional[str] = None,
    checklist_do_dia_id: Optional[int] = None,
    checklist_do_dia_ok: Optional[bool] = None,
) -> int:
    """
    Cria a SESSÃO de operação de áudio (registro da sala).

    Importante:
      - Os campos de evento (nome_evento, horários, tipo_evento, observações,
        USBs, houve_anormalidade) agora pertencem à tabela
        operacao.registro_operacao_operador.
      - Esta função aceita esses parâmetros apenas por compatibilidade, mas
        grava somente os dados da sessão (data/sala + controle em_aberto).
    """

    # Descobre, se existir, o checklist do dia para esta sala + data
    checklist_do_dia_id: Optional[int] = None
    checklist_do_dia_ok: Optional[bool] = None

    try:
        sala_int = int(sala_id) if sala_id is not None and str(sala_id).strip() != "" else None
    except (TypeError, ValueError):
        sala_int = None

    if data_operacao and sala_int is not None:
        # Pega o checklist mais recente (maior id) para a mesma data e sala
        # e calcula se ele está "ok" (nenhuma resposta com status = 'Falha').
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
                row = cur.fetchone()
            if row:
                checklist_do_dia_id = int(row[0])
                checklist_do_dia_ok = bool(row[1])
        except Exception:
            # Qualquer erro aqui (ex.: tabela inexistente) não deve impedir o insert;
            # mantemos os campos como None.
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


def update_registro_operacao_audio(
    registro_id: int,
    data_operacao: str,
    nome_evento: str,
    horario_pauta: Optional[str],
    hora_inicio: str,
    hora_fim: Optional[str],
    houve_anormalidade: bool,
    observacoes: Optional[str],
    usb_01: Optional[str] = None,
    usb_02: Optional[str] = None,
    atualizado_por: Optional[str] = None,
) -> None:
    """
    Atualiza o cabeçalho de um registro de operação de áudio (registro da sala).

    Esta função não altera sala_id nem tipo_evento; apenas campos de identificação
    e resumo da sessão.

    Strings de data/hora devem estar nos formatos aceitos pelo Postgres
    (YYYY-MM-DD e HH:MM).
    """
    sql = """
    UPDATE operacao.registro_operacao_audio
       SET data = %s::date,
           nome_evento = NULLIF(BTRIM(%s::text), '')::text,
           horario_pauta = %s::time,
           horario_inicio = %s::time,
           horario_termino = %s::time,
           houve_anormalidade = %s::boolean,
           observacoes = NULLIF(BTRIM(%s::text), '')::text,
           usb_01 = NULLIF(BTRIM(%s::text), '')::text,
           usb_02 = NULLIF(BTRIM(%s::text), '')::text,
           atualizado_por = %s::uuid
     WHERE id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                data_operacao,
                nome_evento,
                horario_pauta,
                hora_inicio,
                hora_fim,
                houve_anormalidade,
                observacoes or "",
                usb_01 or "",
                usb_02 or "",
                atualizado_por,
                registro_id,
            ],
        )

        
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
        rows = cur.fetchall()

    result: List[Dict[str, Any]] = []
    for row in rows:
        result.append(
            {
                "id": row[0],
                "registro_id": row[1],
                "operador_id": row[2],
                "operador_nome": row[3],
                "ordem": row[4],
                "seq": row[5],
                "nome_evento": row[6],
                "horario_pauta": row[7],
                "horario_inicio": row[8],
                "horario_termino": row[9],
                "tipo_evento": row[10],
                "usb_01": row[11],
                "usb_02": row[12],
                "observacoes": row[13],
                "houve_anormalidade": row[14],
                "anormalidade_id": row[15],
                "comissao_id": row[16],
                "responsavel_evento": row[17],
                "hora_entrada": row[18],
                "hora_saida": row[19],
            }
        )
    return result

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
    houve_anormalidade: Optional[bool],  # ignorado, mantido por compatibilidade
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

    Observação importante:
      - A coluna houve_anormalidade agora é controlada pelo trigger
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
                nome_evento or "",
                horario_pauta,
                horario_inicio,
                horario_termino,
                tipo_evento,
                seq,
                # houve_anormalidade fica sempre FALSE no SQL
                observacoes or "",
                usb_01 or "",
                usb_02 or "",
                comissao_id,
                responsavel_evento or "",
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
    houve_anormalidade: Optional[bool],  # ignorado
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

    Observação:
      - Não atualizamos mais houve_anormalidade aqui (controlado por trigger).
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
                nome_evento or "",
                horario_pauta,
                horario_inicio,
                horario_termino,
                tipo_evento,
                # houve_anormalidade é ignorado
                observacoes or "",
                usb_01 or "",
                usb_02 or "",
                comissao_id,
                responsavel_evento or "",
                hora_entrada,
                hora_saida,
                atualizado_por,
                entrada_id,
            ],
        )


def set_houve_anormalidade_entrada(
    entrada_id: int,
    houve_anormalidade: bool,
    atualizado_por: Optional[str] = None,
) -> None:
    """
    Atualiza apenas o flag 'houve_anormalidade' de uma entrada do operador.
    """
    sql = """
        UPDATE operacao.registro_operacao_operador
           SET houve_anormalidade = %s::boolean,
               atualizado_por     = %s::uuid
         WHERE id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [houve_anormalidade, atualizado_por, entrada_id])

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
        cols = [c[0] for c in cur.description]
        row = cur.fetchone()
        snap = dict(zip(cols, row)) if row else {}
        for k, v in snap.items():
            if hasattr(v, 'isoformat'):
                snap[k] = v.isoformat()
            elif v is not None:
                snap[k] = str(v) if not isinstance(v, (bool, int)) else v
    return snap


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
        cur.execute(sql, [
            campos.get("nome_evento") or "",
            campos.get("responsavel_evento") or "",
            campos.get("horario_pauta"),
            campos.get("horario_inicio"),
            campos.get("horario_termino"),
            campos.get("usb_01") or "",
            campos.get("usb_02") or "",
            campos.get("observacoes") or "",
            campos.get("comissao_id"),
            campos.get("tipo_evento", "operacao"),
            campos.get("hora_entrada"),
            campos.get("hora_saida"),
            # IS DISTINCT FROM comparisons:
            campos.get("nome_evento") or "",
            campos.get("responsavel_evento") or "",
            campos.get("horario_pauta"),
            campos.get("horario_inicio"),
            campos.get("horario_termino"),
            campos.get("usb_01") or "",
            campos.get("usb_02") or "",
            campos.get("observacoes") or "",
            campos.get("comissao_id"),
            campos.get("hora_entrada"),
            campos.get("hora_saida"),
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
