"""Dashboard do operador (home) — Meus Checklists e Minhas Operações."""
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection

from .query_helpers import (
    build_filter_sort,
    append_column_filters,
    fetch_distinct_map,
)
from .utils import fetchall_dicts


def list_meus_checklists(
    user_id: str,
    limit: int,
    offset: int,
    sort: str = "data",
    direction: str = "desc",
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:
    """
    Lista checklists criados pelo operador logado (user_id),
    com contagens de itens OK e Falha.
    """
    valid_cols = {
        "sala": "s.nome",
        "data": "c.data_operacao",
        "qtde_ok": "qtde_ok",
        "qtde_falha": "qtde_falha",
    }

    where, params, order_by = build_filter_sort(
        search="",
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=[],
        default_sort="c.data_operacao",
    )

    # Filtro fixo: apenas checklists do operador logado
    if where:
        where = f"{where} AND c.criado_por = %s::uuid"
    else:
        where = "WHERE c.criado_por = %s::uuid"
    params.append(user_id)

    qtde_ok_expr = """
        (SELECT COUNT(*) FROM forms.checklist_resposta r
         JOIN forms.checklist_item_tipo t ON t.id = r.item_tipo_id
         WHERE r.checklist_id = c.id AND r.status = 'Ok' AND t.tipo_widget != 'text')
    """
    qtde_falha_expr = """
        (SELECT COUNT(*) FROM forms.checklist_resposta r
         JOIN forms.checklist_item_tipo t ON t.id = r.item_tipo_id
         WHERE r.checklist_id = c.id AND r.status = 'Falha' AND t.tipo_widget != 'text')
    """

    col_map = {
        "sala": "s.nome",
        "data": "c.data_operacao",
        "qtde_ok": qtde_ok_expr,
        "qtde_falha": qtde_falha_expr,
    }
    col_types = {
        "sala": "text",
        "data": "date",
        "qtde_ok": "number",
        "qtde_falha": "number",
    }

    joins = """
        FROM forms.checklist c
        JOIN cadastro.sala s ON s.id = c.sala_id
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

    sql_list = f"""
        SELECT
            c.id,
            s.nome AS sala_nome,
            c.data_operacao,
            {qtde_ok_expr} AS qtde_ok,
            {qtde_falha_expr} AS qtde_falha
        {joins}
        {where}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    with connection.cursor() as cur:
        cur.execute(sql_count, params)
        total = cur.fetchone()[0] or 0

        headers: List[Dict[str, Any]] = []
        if total > 0:
            cur.execute(sql_list, params + [limit, offset])
            headers = fetchall_dicts(cur)

    result: List[Dict[str, Any]] = []
    for h in headers:
        result.append({
            "id": h.get("id"),
            "sala_nome": h.get("sala_nome") or "",
            "data": h.get("data_operacao"),
            "qtde_ok": int(h.get("qtde_ok") or 0),
            "qtde_falha": int(h.get("qtde_falha") or 0),
        })

    return result, int(total), distinct


def list_minhas_operacoes(
    user_id: str,
    limit: int,
    offset: int,
    sort: str = "data",
    direction: str = "desc",
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:
    """
    Lista entradas de operação de áudio do operador logado (user_id),
    em formato plano (uma linha por entrada).
    """
    valid_cols = {
        "sala": "s.nome",
        "data": "r.data",
        "inicio_operacao": "e.hora_entrada",
        "fim_operacao": "e.hora_saida",
        "anormalidade": "e.houve_anormalidade",
    }

    where, params, order_by = build_filter_sort(
        search="",
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=[],
        default_sort="r.data",
    )

    # Filtro fixo: apenas entradas do operador logado
    if where:
        where = f"{where} AND e.operador_id = %s::uuid"
    else:
        where = "WHERE e.operador_id = %s::uuid"
    params.append(user_id)

    joins = """
        FROM operacao.registro_operacao_operador e
        JOIN operacao.registro_operacao_audio r ON r.id = e.registro_id
        JOIN cadastro.sala s ON s.id = r.sala_id
        LEFT JOIN operacao.registro_anormalidade a ON a.entrada_id = e.id
    """

    col_map = {
        "sala": "s.nome",
        "data": "r.data",
        "inicio_operacao": "e.hora_entrada",
        "fim_operacao": "e.hora_saida",
        "anormalidade": "e.houve_anormalidade",
    }
    col_types = {
        "sala": "text",
        "data": "date",
        "inicio_operacao": "text",
        "fim_operacao": "text",
        "anormalidade": "bool",
    }

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

    sql_list = f"""
        SELECT
            e.id AS entrada_id,
            r.data,
            s.nome AS sala_nome,
            e.hora_entrada,
            e.hora_saida,
            e.houve_anormalidade,
            a.id AS anormalidade_id
        {joins}
        {where}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    with connection.cursor() as cur:
        cur.execute(sql_count, params)
        total = cur.fetchone()[0] or 0

        headers: List[Dict[str, Any]] = []
        if total > 0:
            cur.execute(sql_list, params + [limit, offset])
            headers = fetchall_dicts(cur)

    result: List[Dict[str, Any]] = []
    for h in headers:
        result.append({
            "id": h.get("entrada_id"),
            "sala": h.get("sala_nome") or "",
            "data": h.get("data"),
            "inicio_operacao": h.get("hora_entrada"),
            "fim_operacao": h.get("hora_saida"),
            "anormalidade": bool(h.get("houve_anormalidade")),
            "anormalidade_id": h.get("anormalidade_id"),
        })

    return result, int(total), distinct
