"""Dashboard de checklists — listagem e detalhe para admin."""
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection

from .query_helpers import (
    build_filter_sort,
    append_date_range_filter,
    append_column_filters,
    fetch_distinct_map,
)
from .utils import fetchall_dicts


def list_checklists_dashboard(
    limit: int,
    offset: int,
    search: str = "",
    sort: str = "data",
    direction: str = "desc",
    periodo: Optional[Dict[str, Any]] = None,
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:

    valid_cols = {
        "sala": "s.nome",
        "data": "c.data_operacao",
        "operador": "COALESCE(o.nome_completo, 'Sistema')",
        "inicio": "inicio",
        "termino": "termino",
        "duracao": "duracao",
    }
    search_cols = [
        "s.nome",
        "COALESCE(o.nome_completo, 'Sistema')",
        "TO_CHAR(c.data_operacao, 'DD/MM/YYYY')",
    ]

    where, params, order_by = build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="c.data_operacao",
    )

    where, params = append_date_range_filter(where, params, "c.data_operacao", periodo)

    status_expr = """
        CASE
            WHEN EXISTS (
                SELECT 1 FROM forms.checklist_resposta r
                WHERE r.checklist_id = c.id AND r.status = 'Falha'
            ) THEN 'Falha'
            WHEN EXISTS (
                SELECT 1 FROM forms.checklist_resposta r
                WHERE r.checklist_id = c.id
            ) THEN 'Ok'
            ELSE '--'
        END
    """

    duracao_txt_expr = """
        COALESCE(
            (EXTRACT(HOUR FROM (c.hora_termino_testes - c.hora_inicio_testes))::int)::text
            || ':' || LPAD((EXTRACT(MINUTE FROM (c.hora_termino_testes - c.hora_inicio_testes))::int)::text, 2, '0')
            || ':' || LPAD((EXTRACT(SECOND FROM (c.hora_termino_testes - c.hora_inicio_testes))::int)::text, 2, '0'),
            '--'
        )
    """

    col_map = {
        "sala": "s.nome",
        "data": "c.data_operacao",
        "operador": "COALESCE(o.nome_completo, 'Sistema')",
        "inicio": "COALESCE(TO_CHAR(c.hora_inicio_testes, 'HH24:MI'), '--')",
        "termino": "COALESCE(TO_CHAR(c.hora_termino_testes, 'HH24:MI'), '--')",
        "duracao": duracao_txt_expr,
        "status": status_expr,
    }
    col_types = {
        "sala": "text",
        "data": "date",
        "operador": "text",
        "inicio": "text",
        "termino": "text",
        "duracao": "text",
        "status": "text",
    }

    joins = """
        FROM forms.checklist c
        JOIN cadastro.sala s ON s.id = c.sala_id
        LEFT JOIN pessoa.operador o ON o.id = c.criado_por
    """

    base_where = where
    base_params = list(params)

    distinct = fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = append_column_filters(
        base_where,
        list(base_params),
        filters,
        col_map,
        col_types,
    )

    sql_count = f"SELECT COUNT(*) {joins} {where};"

    sql_header = f"""
        SELECT
            c.id,
            s.nome AS sala_nome,
            c.data_operacao,
            COALESCE(o.nome_completo, 'Sistema') AS operador,
            COALESCE(TO_CHAR(c.hora_inicio_testes, 'HH24:MI'), '--') AS inicio,
            COALESCE(TO_CHAR(c.hora_termino_testes, 'HH24:MI'), '--') AS termino,
            (c.hora_termino_testes - c.hora_inicio_testes) AS duracao
        {joins}
        {where}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    headers: List[Dict[str, Any]] = []
    with connection.cursor() as cur:
        cur.execute(sql_count, params)
        total = cur.fetchone()[0] or 0

        if total > 0:
            cur.execute(sql_header, params + [limit, offset])
            headers = fetchall_dicts(cur)

    if total == 0 or not headers:
        return [], int(total), distinct

    ids = [h["id"] for h in headers if h.get("id") is not None]
    if not ids:
        return [], int(total), distinct

    items_by_chk: Dict[int, List[Dict[str, Any]]] = {int(cid): [] for cid in ids}
    placeholders_ids = ", ".join(["%s"] * len(ids))

    sql_items = f"""
        SELECT
            r.checklist_id,
            t.nome AS item_nome,
            r.status,
            COALESCE(r.descricao_falha, '') AS falha,
            t.tipo_widget,
            COALESCE(r.valor_texto, '') AS valor_texto
        FROM forms.checklist_resposta r
        JOIN forms.checklist_item_tipo t ON t.id = r.item_tipo_id
        JOIN forms.checklist c ON c.id = r.checklist_id
        LEFT JOIN forms.checklist_sala_config sc
            ON sc.sala_id = c.sala_id AND sc.item_tipo_id = r.item_tipo_id
        WHERE r.checklist_id IN ({placeholders_ids})
        ORDER BY r.checklist_id ASC, COALESCE(sc.ordem, 9999) ASC, t.id ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql_items, [int(x) for x in ids])
        item_rows = fetchall_dicts(cur)

    for it in item_rows:
        cid = it.get("checklist_id")
        if cid is None:
            continue
        cid_int = int(cid)
        if cid_int in items_by_chk:
            items_by_chk[cid_int].append(
                {
                    "item": it.get("item_nome") or "",
                    "status": it.get("status") or "--",
                    "falha": it.get("falha") or "",
                    "tipo_widget": it.get("tipo_widget") or "radio",
                    "valor_texto": it.get("valor_texto") or "",
                }
            )

    result: List[Dict[str, Any]] = []
    for h in headers:
        cid = int(h.get("id"))
        dur = h.get("duracao")
        dur_str = str(dur) if dur else "--"

        result.append(
            {
                "id": cid,
                "sala_nome": h.get("sala_nome") or "",
                "data": h.get("data_operacao"),
                "operador": h.get("operador") or "",
                "inicio": h.get("inicio") or "--",
                "termino": h.get("termino") or "--",
                "duracao": dur_str,
                "itens": items_by_chk.get(cid, []),
            }
        )

    return result, int(total), distinct


def get_checklist_detalhe(checklist_id: int) -> Optional[Dict[str, Any]]:
    sql_header = """
        SELECT
            c.id, c.sala_id, s.nome AS sala_nome, c.data_operacao,
            c.hora_inicio_testes, c.hora_termino_testes, c.turno,
            c.observacoes, c.usb_01, c.usb_02, c.editado, c.observacoes_editado,
            (c.hora_termino_testes - c.hora_inicio_testes) AS duracao,
            c.criado_por,
            o.nome_completo AS operador_nome
        FROM forms.checklist c
        JOIN cadastro.sala s ON s.id = c.sala_id
        LEFT JOIN pessoa.operador o ON o.id = c.criado_por
        WHERE c.id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(sql_header, [checklist_id])
        rows = fetchall_dicts(cur)
        if not rows:
            return None
        header = rows[0]

    sql_items = """
        SELECT r.id, r.item_tipo_id, t.nome AS item_nome, r.status, r.descricao_falha,
               t.tipo_widget, r.valor_texto, r.editado
        FROM forms.checklist_resposta r
        JOIN forms.checklist_item_tipo t ON t.id = r.item_tipo_id
        JOIN forms.checklist c ON c.id = r.checklist_id
        LEFT JOIN forms.checklist_sala_config sc
            ON sc.sala_id = c.sala_id AND sc.item_tipo_id = r.item_tipo_id
        WHERE r.checklist_id = %s::bigint
        ORDER BY COALESCE(sc.ordem, 9999) ASC, t.id ASC;
    """
    with connection.cursor() as cur:
        cur.execute(sql_items, [checklist_id])
        items = fetchall_dicts(cur)

    duracao_str = str(header["duracao"]) if header["duracao"] else "--"
    return {
        "id": header["id"],
        "sala_id": header["sala_id"],
        "sala_nome": header["sala_nome"],
        "data_operacao": header["data_operacao"],
        "turno": header["turno"],
        "hora_inicio": header["hora_inicio_testes"],
        "hora_termino": header["hora_termino_testes"],
        "duracao": duracao_str,
        "operador_nome": header["operador_nome"],
        "observacoes": header["observacoes"],
        "usb_01": header["usb_01"],
        "usb_02": header["usb_02"],
        "editado": header.get("editado", False),
        "observacoes_editado": header.get("observacoes_editado", False),
        "itens": items,
    }
