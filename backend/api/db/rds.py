from __future__ import annotations

from datetime import date
from typing import Any, Dict, List

from django.db import connection

from .admin_dashboard import fetch_all_dict


def list_rds_anos() -> List[int]:
    with connection.cursor() as cur:
        cur.execute(
            """
            SELECT DISTINCT EXTRACT(YEAR FROM data)::int AS ano
            FROM operacao.registro_operacao_audio
            ORDER BY ano ASC
            """
        )
        rows = fetch_all_dict(cur)
        return [int(r["ano"]) for r in rows if r.get("ano") is not None]


def list_rds_meses(ano: int) -> List[int]:
    with connection.cursor() as cur:
        cur.execute(
            """
            SELECT DISTINCT EXTRACT(MONTH FROM data)::int AS mes
            FROM operacao.registro_operacao_audio
            WHERE EXTRACT(YEAR FROM data)::int = %s
            ORDER BY mes ASC
            """,
            [ano],
        )
        rows = fetch_all_dict(cur)
        return [int(r["mes"]) for r in rows if r.get("mes") is not None]


def fetch_rds_rows(ano: int, mes: int) -> List[Dict[str, Any]]:
    start = date(ano, mes, 1)
    end = date(ano + 1, 1, 1) if mes == 12 else date(ano, mes + 1, 1)

    with connection.cursor() as cur:
        cur.execute(
            """
            SELECT
                ra.id               AS registro_id,
                ra.data             AS data,
                ra.em_aberto        AS em_aberto,
                s.nome              AS sala_nome,

                rop.id              AS entrada_id,
                rop.ordem           AS ordem,
                rop.seq             AS seq,
                rop.nome_evento     AS nome_evento,
                rop.horario_pauta   AS horario_pauta,
                rop.horario_inicio  AS horario_inicio,
                rop.horario_termino AS horario_termino,

                op.nome_exibicao    AS operador_nome_exibicao,

                c.nome              AS comissao_nome

            FROM operacao.registro_operacao_audio ra
            JOIN cadastro.sala s
              ON s.id = ra.sala_id
            JOIN operacao.registro_operacao_operador rop
              ON rop.registro_id = ra.id
            JOIN pessoa.operador op
              ON op.id = rop.operador_id
            LEFT JOIN cadastro.comissao c
              ON c.id = rop.comissao_id

            WHERE ra.data >= %s
              AND ra.data < %s

            ORDER BY
                ra.data ASC,
                rop.horario_pauta NULLS LAST,
                rop.horario_inicio NULLS LAST,
                s.nome ASC,
                ra.id ASC,
                rop.ordem ASC,
                rop.seq ASC,
                rop.id ASC
            """,
            [start, end],
        )
        return fetch_all_dict(cur)