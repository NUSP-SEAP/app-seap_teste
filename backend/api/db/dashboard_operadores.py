"""Dashboard de operadores — listagem para admin."""
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection

from .query_helpers import (
    build_filter_sort,
    append_column_filters,
    fetch_distinct_map,
)
from .utils import fetchall_dicts


def list_operadores_dashboard(
    limit: int,
    offset: int,
    search: str = "",
    sort: str = "nome",
    direction: str = "asc",
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:

    valid_cols = {
        "nome": "nome_completo",
        "email": "email",
        "status_local": "status_local",
        "hora_entrada": "hora_entrada",
        "hora_saida": "hora_saida",
    }
    search_cols = ["nome_completo", "email"]

    where, params, order_by = build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="nome_completo",
    )

    col_map = {
        "nome": "nome_completo",
        "email": "email",
        "status_local": "'--'",
        "hora_entrada": "'--'",
        "hora_saida": "'--'",
    }
    col_types = {
        "nome": "text",
        "email": "text",
        "status_local": "text",
        "hora_entrada": "text",
        "hora_saida": "text",
    }

    joins = "FROM pessoa.operador"

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
            id,
            nome_completo,
            email,
            '--' AS status_local,
            '--' AS hora_entrada,
            '--' AS hora_saida
        {joins}
        {where}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    with connection.cursor() as cur:
        cur.execute(sql_count, params)
        total = cur.fetchone()[0]

        rows: List[Dict[str, Any]] = []
        if total and total > 0:
            cur.execute(sql_list, params + [limit, offset])
            rows = fetchall_dicts(cur)

    return rows, total, distinct
