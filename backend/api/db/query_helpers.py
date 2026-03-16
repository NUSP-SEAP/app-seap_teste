"""
Helpers genéricos para queries de dashboard com paginação, filtros e ordenação.

Extraído de admin_dashboard.py (Etapa 4 da refatoração).
"""
import logging
from datetime import date
from typing import Any, Dict, List, Optional, Set, Tuple

from django.db import connection

from .utils import fetchall_dicts

logger = logging.getLogger(__name__)


def _parse_bool(v: Any) -> Optional[bool]:
    if isinstance(v, bool):
        return v
    if v is None:
        return None
    s = str(v).strip().lower()
    if s in ("true", "1", "sim", "yes", "y", "t"):
        return True
    if s in ("false", "0", "nao", "não", "no", "n", "f"):
        return False
    return None


def build_filter_sort(
    search: str = "",
    sort: str = "",
    direction: str = "asc",
    valid_cols: Optional[Dict[str, str]] = None,
    search_cols: Optional[List[str]] = None,
    default_sort: str = "",
) -> Tuple[str, List[Any], str]:
    """
    Gera cláusulas WHERE (busca textual) e ORDER BY seguras.

    Retorna (where_clause, params, order_clause).
    """
    valid_cols = valid_cols or {}
    search_cols = search_cols or []

    where_parts: List[str] = []
    params: List[Any] = []

    if search:
        term = f"%{str(search).strip()}%"
        or_group: List[str] = []
        for col in search_cols:
            or_group.append(f"{col} ILIKE %s")
            params.append(term)
        if or_group:
            where_parts.append(f"({' OR '.join(or_group)})")

    where_clause = "WHERE " + " AND ".join(where_parts) if where_parts else ""

    col_sql = valid_cols.get(sort or "", default_sort)
    dir_sql = "DESC" if (direction and str(direction).lower() == "desc") else "ASC"
    order_clause = f"ORDER BY {col_sql} {dir_sql}"

    return where_clause, params, order_clause


def _normalize_ranges(periodo: Optional[Dict[str, Any]]) -> List[Tuple[date, date]]:
    """
    Converte o dict 'periodo' em uma lista normalizada de (data_inicial, data_final),
    mesclando intervalos sobrepostos.
    """
    if not periodo:
        return []

    ranges: List[Tuple[date, date]] = []
    for r in periodo.get("ranges", []):
        start_str = r.get("start")
        end_str = r.get("end")
        if not start_str or not end_str:
            continue
        try:
            d_start = date.fromisoformat(str(start_str))
            d_end = date.fromisoformat(str(end_str))
            if d_end < d_start:
                d_start, d_end = d_end, d_start
            ranges.append((d_start, d_end))
        except (ValueError, TypeError):
            logger.debug("Intervalo de período ignorado: start=%s, end=%s", start_str, end_str)
            continue

    if not ranges:
        return []

    # Mescla intervalos sobrepostos/contíguos
    ranges.sort(key=lambda x: x[0])
    merged: List[Tuple[date, date]] = []
    cur_start, cur_end = ranges[0]
    for start, end in ranges[1:]:
        if start <= cur_end:
            if end > cur_end:
                cur_end = end
        else:
            merged.append((cur_start, cur_end))
            cur_start, cur_end = start, end
    merged.append((cur_start, cur_end))
    return merged


def append_date_range_filter(
    where_clause: str,
    params: List[Any],
    date_col: str,
    periodo: Optional[Dict[str, Any]] = None,
) -> Tuple[str, List[Any]]:
    """Acrescenta ao WHERE existente um filtro por faixas de datas."""
    if not date_col:
        return where_clause, params

    ranges = _normalize_ranges(periodo)
    if not ranges:
        return where_clause, params

    parts: List[str] = []
    for start, end in ranges:
        parts.append(f"{date_col} BETWEEN %s AND %s")
        params.append(start)
        params.append(end)

    condition = "(" + " OR ".join(parts) + ")"

    if where_clause:
        where_clause = f"{where_clause} AND {condition}"
    else:
        where_clause = f"WHERE {condition}"

    return where_clause, params


def append_column_filters(
    where_clause: str,
    params: List[Any],
    filters: Optional[Dict[str, Any]],
    mapping: Dict[str, str],
    types: Optional[Dict[str, str]] = None,
    exclude_keys: Optional[Set[str]] = None,
) -> Tuple[str, List[Any]]:
    """
    Acrescenta filtros por coluna ao WHERE existente.

    filters esperado:
      {
        "coluna": { "text": "abc", "values": ["x","y"], "range": {"from":"YYYY-MM-DD","to":"YYYY-MM-DD"} },
        ...
      }
    """
    if not filters or not isinstance(filters, dict):
        return where_clause, params

    parts: List[str] = []
    types = types or {}

    for key, spec in filters.items():
        if exclude_keys and key in exclude_keys:
            continue
        if key not in mapping:
            continue
        if not isinstance(spec, dict):
            continue

        col_sql = mapping[key]
        col_type = (types.get(key) or "text").lower()

        # 1) text (ILIKE)
        text = (spec.get("text") or "").strip()
        if text:
            if col_type == "date":
                parts.append(f"TO_CHAR({col_sql}, 'DD/MM/YYYY') ILIKE %s")
            else:
                parts.append(f"CAST({col_sql} AS TEXT) ILIKE %s")
            params.append(f"%{text}%")

        # 2) values (IN)
        values = spec.get("values")
        if isinstance(values, list) and len(values) > 0:
            conv: List[Any] = []

            if col_type == "bool":
                for v in values:
                    b = _parse_bool(v)
                    if b is not None:
                        conv.append(b)
            elif col_type == "date":
                for v in values:
                    try:
                        conv.append(date.fromisoformat(str(v)))
                    except (ValueError, TypeError):
                        continue
            elif col_type == "number":
                for v in values:
                    try:
                        conv.append(float(v))
                    except (ValueError, TypeError):
                        continue
            else:
                for v in values:
                    s = str(v).strip()
                    if s:
                        conv.append(s)

            if conv:
                placeholders = ", ".join(["%s"] * len(conv))
                parts.append(f"{col_sql} IN ({placeholders})")
                params.extend(conv)

        # 3) range (somente date)
        rng = spec.get("range")
        if col_type == "date" and isinstance(rng, dict):
            from_s = (rng.get("from") or "").strip()
            to_s = (rng.get("to") or "").strip()
            d_from = None
            d_to = None

            if from_s:
                try:
                    d_from = date.fromisoformat(from_s)
                except (ValueError, TypeError):
                    d_from = None
            if to_s:
                try:
                    d_to = date.fromisoformat(to_s)
                except (ValueError, TypeError):
                    d_to = None

            if d_from and d_to:
                if d_to < d_from:
                    d_from, d_to = d_to, d_from
                parts.append(f"{col_sql} BETWEEN %s AND %s")
                params.extend([d_from, d_to])
            elif d_from:
                parts.append(f"{col_sql} >= %s")
                params.append(d_from)
            elif d_to:
                parts.append(f"{col_sql} <= %s")
                params.append(d_to)

    if not parts:
        return where_clause, params

    condition = " AND ".join([f"({p})" for p in parts])

    if where_clause:
        where_clause = f"{where_clause} AND {condition}"
    else:
        where_clause = f"WHERE {condition}"

    return where_clause, params


def fetch_distinct_map(
    joins_sql: str,
    base_where: str,
    base_params: List[Any],
    filters: Optional[Dict[str, Any]],
    col_map: Dict[str, str],
    col_types: Dict[str, str],
) -> Dict[str, List[Dict[str, str]]]:
    """
    Retorna, para cada coluna (key do TableFilter), a lista DISTINCT de valores
    no banco, respeitando busca/período e TODOS os outros filtros de coluna,
    mas ignorando o filtro da própria coluna (comportamento tipo Excel/faceted).
    """
    distinct: Dict[str, List[Dict[str, str]]] = {}

    for key, expr in col_map.items():
        where_k, params_k = append_column_filters(
            base_where,
            list(base_params),
            filters,
            col_map,
            col_types,
            exclude_keys={key},
        )

        sql = f"SELECT DISTINCT ({expr}) AS v {joins_sql} {where_k} ORDER BY v ASC;"
        with connection.cursor() as cur:
            cur.execute(sql, params_k)
            vals = [r[0] for r in cur.fetchall()]

        out_list: List[Dict[str, str]] = []
        seen: set = set()
        ctype = col_types.get(key, "text")

        for v in vals:
            if v is None:
                continue

            if ctype == "bool":
                b = v if isinstance(v, bool) else _parse_bool(str(v))
                if b is None:
                    continue
                value = "true" if b else "false"
                label = "Sim" if b else "Não"
            elif ctype == "date":
                value = v.isoformat() if hasattr(v, "isoformat") else str(v)
                label = value
            else:
                value = str(v)
                label = value

            if value in seen:
                continue
            seen.add(value)
            out_list.append({"value": value, "label": label})

        distinct[key] = out_list

    return distinct
