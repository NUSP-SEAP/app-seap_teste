from typing import Any, Dict, List, Optional, Tuple, Set
from datetime import date
from django.db import connection


def fetch_all_dict(cur):
    rows = cur.fetchall()
    if not rows: return []
    desc = [c[0] for c in cur.description]
    return [dict(zip(desc, row)) for row in rows]

# --- HELPER: Filtro e Ordenação ---
def _build_filter_sort(
    search_term: str = "",
    order_by: str = "",
    order_dir: str = "asc",
    valid_cols: Optional[Dict[str, str]] = None,
    search_cols: Optional[List[str]] = None,
    default_sort: str = "",
    # aliases usados nas chamadas novas:
    search: Optional[str] = None,
    sort: Optional[str] = None,
    direction: Optional[str] = None,
) -> Tuple[str, List[Any], str]:
    """
    Gera cláusulas WHERE e ORDER BY seguras.

    Compatível com ambos os padrões de chamada:
      - _build_filter_sort(search, sort, direction, valid_cols, search_cols, default_sort="...")
      - _build_filter_sort(search=..., sort=..., direction=..., valid_cols=..., search_cols=..., default_sort=...)
    """

    # Normaliza aliases novos → nomes antigos
    if search is not None:
        search_term = search
    if sort is not None:
        order_by = sort
    if direction is not None:
        order_dir = direction

    valid_cols = valid_cols or {}
    search_cols = search_cols or []

    # 1. Filtro (Busca)
    where_parts: List[str] = []
    params: List[Any] = []

    if search_term:
        term = f"%{str(search_term).strip()}%"
        or_group: List[str] = []
        for col in search_cols:
            or_group.append(f"{col} ILIKE %s")
            params.append(term)

        if or_group:
            where_parts.append(f"({' OR '.join(or_group)})")

    where_clause = "WHERE " + " AND ".join(where_parts) if where_parts else ""

    # 2. Ordenação
    col_sql = valid_cols.get(order_by or "", default_sort)
    dir_sql = "DESC" if (order_dir and str(order_dir).lower() == "desc") else "ASC"
    order_clause = f"ORDER BY {col_sql} {dir_sql}"

    return where_clause, params, order_clause


# --- HELPER: Filtro de Período por faixas de datas ---

def _normalize_ranges(periodo: Optional[Dict[str, Any]]) -> List[Tuple[date, date]]:
    """
    Converte o dict 'periodo' em uma lista normalizada de (data_inicial, data_final).

    Espera um formato:
        {
            "ranges": [
                {"start": "2023-01-01", "end": "2023-03-31"},
                ...
            ]
        }
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
            y1, m1, d1 = map(int, start_str.split("-"))
            y2, m2, d2 = map(int, end_str.split("-"))
            d_start = date(y1, m1, d1)
            d_end = date(y2, m2, d2)
            if d_end < d_start:
                d_start, d_end = d_end, d_start
            ranges.append((d_start, d_end))
        except Exception:
            # Ignora intervalos inválidos
            continue

    if not ranges:
        return []

    # Opcional: mescla intervalos sobrepostos/contíguos para reduzir ORs no SQL
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


def _append_date_range_filter(
    where_clause: str,
    params: List[Any],
    date_col: Any,
    periodo: Optional[Dict[str, Any]] = None,
) -> Tuple[str, List[Any]]:
    """
    Acrescenta ao WHERE existente um filtro por faixas de datas.

    Aceita as duas formas de chamada (compat):
      - _append_date_range_filter(where, params, "a.data", periodo)
      - _append_date_range_filter(where, params, periodo, "a.data")
    """
    # Compat: se vier invertido (periodo, date_col)
    if isinstance(date_col, dict) or date_col is None:
        periodo, date_col = date_col, periodo

    if not isinstance(date_col, str) or not date_col:
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


def _append_column_filters(
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

    mapping:
      { "coluna": "sql_expr" }

    types:
      { "coluna": "text|date|bool|number" }
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

        # 1) text (ILIKE) - type aware
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
                    except Exception:
                        continue

            elif col_type == "number":
                for v in values:
                    try:
                        conv.append(float(v))
                    except Exception:
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
                except Exception:
                    d_from = None

            if to_s:
                try:
                    d_to = date.fromisoformat(to_s)
                except Exception:
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

def _fetch_distinct_map(
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
        # aplica filtros de coluna, exceto o da própria coluna
        where_k, params_k = _append_column_filters(
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
        seen = set()
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

# --- 1. OPERADORES (Dinâmico) ---
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

    where, params, order_by = _build_filter_sort(
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

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = _append_column_filters(
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
            rows = fetch_all_dict(cur)

    return rows, total, distinct

# --- 2. CHECKLISTS (Dinâmico) ---
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

    where, params, order_by = _build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="c.data_operacao",
    )

    where, params = _append_date_range_filter(where, params, "c.data_operacao", periodo)


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

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = _append_column_filters(
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
            headers = fetch_all_dict(cur)

    if total == 0 or not headers:
        return [], int(total), distinct

    ids = [h["id"] for h in headers if h.get("id") is not None]
    if not ids:
        return [], int(total), distinct

    items_by_chk: Dict[int, List[Dict[str, Any]]] = {int(cid): [] for cid in ids}
    ids_str = ",".join([str(int(x)) for x in ids])

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
        WHERE r.checklist_id IN ({ids_str})
        ORDER BY r.checklist_id ASC, COALESCE(sc.ordem, 9999) ASC, t.id ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql_items)
        item_rows = fetch_all_dict(cur)

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

def _tipo_display_from_sala_comissao(sala_nome: str, comissao_nome: Optional[str]) -> str:
    """
    Calcula o campo "Tipo" das operações, seguindo as regras do front:
      1) Se a sala for Auditório / Plenário -> retorna esse texto
      2) Senão, usa a sigla da comissão (antes do " - "), quando houver
      3) Caso contrário, "-"
    """
    sala_lower = (sala_nome or "").strip().lower()

    if "auditório" in sala_lower or "auditorio" in sala_lower:
        return "Auditório"
    if "plenário" in sala_lower or "plenario" in sala_lower:
        return "Plenário"

    if comissao_nome:
        left, _, _ = str(comissao_nome).partition(" - ")
        left = (left or "").strip()
        return left if left else str(comissao_nome).strip()

    return "-"


# --- 3. OPERAÇÕES DE ÁUDIO (Dinâmico) ---
def list_operacoes_dashboard(
    limit: int,
    offset: int,
    search: str = "",
    sort: str = "data",
    direction: str = "desc",
    periodo: Optional[Dict[str, Any]] = None,
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:
    """
    Lista SESSÕES (registro_operacao_audio) com sublinhas (entradas).
    Inclui meta.distinct para o TableFilter (estilo Excel) e aceita ?filters=...
    """
    autor_expr = "COALESCE(op.nome_completo, 'Sistema')"
    verificacao_expr = "CASE WHEN r.checklist_do_dia_id IS NOT NULL THEN 'Realizado' ELSE 'Não Realizado' END"
    em_aberto_expr = "CASE WHEN r.em_aberto THEN 'Sim' ELSE 'Não' END"

    valid_cols = {
        "data": "r.data",
        "sala": "s.nome",
        "autor": autor_expr,
        "em_aberto": em_aberto_expr,
        "verificacao": verificacao_expr,
    }
    search_cols = [
        "s.nome",
        autor_expr,
        "TO_CHAR(r.data, 'DD/MM/YYYY')",
    ]

    where, params, order_by = _build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="r.data",
    )

    # filtro opcional por período em r.data
    where, params = _append_date_range_filter(where, params, "r.data", periodo)

    joins = """
        FROM operacao.registro_operacao_audio r
        JOIN cadastro.sala s ON s.id = r.sala_id
        LEFT JOIN pessoa.operador op ON op.id = r.criado_por
    """

    col_map = {
        "sala": "s.nome",
        "data": "r.data",
        "autor": autor_expr,
        "verificacao": verificacao_expr,
        "em_aberto": em_aberto_expr,
    }
    col_types = {
        "sala": "text",
        "data": "date",
        "autor": "text",
        "verificacao": "text",
        "em_aberto": "text",
    }

    base_where = where
    base_params = list(params)

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where_f, params_f = _append_column_filters(
        base_where,
        list(base_params),
        filters,
        col_map,
        col_types,
    )

    sql_count = f"SELECT COUNT(*) {joins} {where_f};"

    sql_sessao = f"""
        SELECT
            r.id,
            r.sala_id,
            s.nome AS sala_nome,
            r.data,
            r.criado_por,
            {autor_expr} AS autor_nome,
            {verificacao_expr} AS verificacao,
            {em_aberto_expr} AS em_aberto_txt
        {joins}
        {where_f}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    with connection.cursor() as cur:
        cur.execute(sql_count, params_f)
        total_row = cur.fetchone()
        total = int(total_row[0]) if total_row else 0

        if total == 0:
            return [], 0, distinct

        cur.execute(sql_sessao, params_f + [limit, offset])
        sessoes = fetch_all_dict(cur)

    if not sessoes:
        return [], total, distinct

    ids = [s["id"] for s in sessoes if s.get("id") is not None]
    if not ids:
        return [], total, distinct

    placeholders = ", ".join(["%s"] * len(ids))

    sql_entradas = f"""
        SELECT
            e.id,
            e.registro_id,
            e.ordem,
            e.operador_id,
            op.nome_completo AS operador_nome,
            e.tipo_evento,
            e.nome_evento,
            e.horario_pauta,
            e.horario_inicio,
            e.horario_termino,
            e.houve_anormalidade,
            c.nome AS comissao_nome
        FROM operacao.registro_operacao_operador e
        JOIN pessoa.operador op ON op.id = e.operador_id
        LEFT JOIN cadastro.comissao c ON c.id = e.comissao_id
        WHERE e.registro_id IN ({placeholders})
        ORDER BY e.registro_id ASC, e.ordem ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql_entradas, ids)
        entradas = fetch_all_dict(cur)

    sala_map = {s["id"]: (s.get("sala_nome") or "") for s in sessoes}

    entradas_map: Dict[Any, List[Dict[str, Any]]] = {}
    for e in entradas:
        rid = e.get("registro_id")
        sala_nome = sala_map.get(rid, "")
        tipo_display = _tipo_display_from_sala_comissao(sala_nome, e.get("comissao_nome"))

        entradas_map.setdefault(rid, []).append({
            "id": e.get("id"),
            "ordem": e.get("ordem"),
            "operador": e.get("operador_nome") or "",
            "tipo": tipo_display,
            "evento": e.get("nome_evento"),
            "pauta": e.get("horario_pauta"),
            "inicio": e.get("horario_inicio"),
            "fim": e.get("horario_termino"),
            "anormalidade": bool(e.get("houve_anormalidade")),
        })

    result: List[Dict[str, Any]] = []
    for s in sessoes:
        result.append({
            "id": s.get("id"),
            "sala": s.get("sala_nome"),
            "data": s.get("data"),
            "autor": s.get("autor_nome") or "Sistema",
            "verificacao": s.get("verificacao") or "Não Realizado",
            "em_aberto": s.get("em_aberto_txt") or "Não",
            "entradas": entradas_map.get(s.get("id"), []),
        })

    return result, total, distinct


def list_operacoes_entradas_dashboard(
    limit: int,
    offset: int,
    search: str = "",
    sort: str = "data",
    direction: str = "desc",
    periodo: Optional[Dict[str, Any]] = None,
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:
    """
    Lista ENTRADAS (registro_operacao_operador) em formato plano (uma linha por entrada),
    com paginação por entrada.

    Inclui meta.distinct para o TableFilter e aceita ?filters=...
    """
    tipo_expr = """
        CASE
            WHEN LOWER(s.nome) LIKE '%%auditório%%' OR LOWER(s.nome) LIKE '%%auditorio%%' THEN 'Auditório'
            WHEN LOWER(s.nome) LIKE '%%plenário%%'  OR LOWER(s.nome) LIKE '%%plenario%%'  THEN 'Plenário'
            WHEN c.nome IS NOT NULL AND c.nome <> '' THEN SPLIT_PART(c.nome, ' - ', 1)
            ELSE '-'
        END
    """

    valid_cols = {
        "data": "r.data",
        "sala": "s.nome",
        "operador": "op.nome_completo",
        "tipo": tipo_expr,
        "evento": "e.nome_evento",
        "anormalidade": "e.houve_anormalidade",
    }
    search_cols = [
        "s.nome",
        "op.nome_completo",
        "e.nome_evento",
        "TO_CHAR(r.data, 'DD/MM/YYYY')",
    ]

    where, params, order_by = _build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="r.data",
    )

    where, params = _append_date_range_filter(where, params, "r.data", periodo)

    joins = """
        FROM operacao.registro_operacao_operador e
        JOIN operacao.registro_operacao_audio r ON r.id = e.registro_id
        JOIN cadastro.sala s ON s.id = r.sala_id
        JOIN pessoa.operador op ON op.id = e.operador_id
        LEFT JOIN cadastro.comissao c ON c.id = e.comissao_id
    """

    col_map = {
        "sala": "s.nome",
        "data": "r.data",
        "operador": "op.nome_completo",
        "tipo": tipo_expr,
        "evento": "e.nome_evento",
        "anormalidade": "e.houve_anormalidade",
    }
    col_types = {
        "sala": "text",
        "data": "date",
        "operador": "text",
        "tipo": "text",
        "evento": "text",
        "anormalidade": "bool",
    }

    base_where = where
    base_params = list(params)

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where_f, params_f = _append_column_filters(
        base_where,
        list(base_params),
        filters,
        col_map,
        col_types,
    )

    sql_count = f"SELECT COUNT(*) {joins} {where_f};"

    sql_list = f"""
        SELECT
            e.id AS entrada_id,
            r.data AS data,
            s.nome AS sala_nome,
            op.nome_completo AS operador_nome,
            {tipo_expr} AS tipo_display,
            e.nome_evento,
            e.horario_pauta,
            e.horario_inicio,
            e.horario_termino,
            e.houve_anormalidade
        {joins}
        {where_f}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    with connection.cursor() as cur:
        cur.execute(sql_count, params_f)
        total_row = cur.fetchone()
        total = int(total_row[0]) if total_row else 0

        if total == 0:
            return [], 0, distinct

        cur.execute(sql_list, params_f + [limit, offset])
        rows = fetch_all_dict(cur)

    result: List[Dict[str, Any]] = []
    for row in rows:
        result.append({
            "id": row.get("entrada_id"),
            "sala": row.get("sala_nome"),
            "data": row.get("data"),
            "operador": row.get("operador_nome"),
            "tipo": row.get("tipo_display") or "-",
            "evento": row.get("nome_evento"),
            "pauta": row.get("horario_pauta"),
            "inicio": row.get("horario_inicio"),
            "fim": row.get("horario_termino"),
            "anormalidade": bool(row.get("houve_anormalidade")),
        })

    return result, total, distinct


# --- 4. DETALHES UNITÁRIOS ---

from . import operacao # Para manter imports se necessário
def get_entrada_operacao_detalhe(entrada_id: int) -> Optional[Dict[str, Any]]:
    sql = """
        SELECT
            e.id AS entrada_id,
            e.registro_id,
            r.sala_id,
            s.nome AS sala_nome,
            r.data AS data_operacao,
            e.horario_pauta,
            e.horario_inicio  AS hora_inicio,
            e.horario_termino AS hora_fim,
            e.nome_evento,
            e.tipo_evento,
            e.usb_01,
            e.usb_02,
            e.observacoes,
            e.houve_anormalidade,
            e.seq,
            e.comissao_id,
            c.nome AS comissao_nome,
            e.responsavel_evento,
            op.nome_completo AS operador_nome,
            e.editado,
            e.observacoes_editado,
            e.nome_evento_editado,
            e.responsavel_evento_editado,
            e.horario_pauta_editado,
            e.horario_inicio_editado,
            e.horario_termino_editado,
            e.usb_01_editado,
            e.usb_02_editado,
            e.comissao_editado,
            e.sala_editado,
            e.hora_entrada,
            e.hora_saida,
            e.hora_entrada_editado,
            e.hora_saida_editado,
            e.ordem,
            e.operador_id,
            (SELECT COUNT(*) FROM operacao.registro_operacao_operador e2
             WHERE e2.registro_id = e.registro_id) AS total_entradas
        FROM operacao.registro_operacao_operador e
        JOIN operacao.registro_operacao_audio r ON r.id = e.registro_id
        JOIN cadastro.sala s ON s.id = r.sala_id
        JOIN pessoa.operador op ON op.id = e.operador_id
        LEFT JOIN cadastro.comissao c ON c.id = e.comissao_id
        WHERE e.id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [entrada_id])
        row = fetch_all_dict(cur)
        return row[0] if row else None

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
        rows = fetch_all_dict(cur)
        if not rows: return None
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
        items = fetch_all_dict(cur)
        
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
        "itens": items
    }

def get_anormalidade_detalhe(anom_id: int) -> Optional[Dict[str, Any]]:
    sql = """
        SELECT
            a.id,
            a.data,
            a.sala_id,
            s.nome AS sala_nome,
            a.nome_evento,
            a.hora_inicio_anormalidade,
            a.descricao_anormalidade,
            a.houve_prejuizo,
            a.descricao_prejuizo,
            a.houve_reclamacao,
            a.autores_conteudo_reclamacao,
            a.acionou_manutencao,
            a.hora_acionamento_manutencao,
            a.resolvida_pelo_operador,
            a.procedimentos_adotados,
            a.data_solucao,
            a.hora_solucao,
            a.responsavel_evento,
            a.criado_por,
            op.nome_completo AS registrado_por,
            adm.observacao_supervisor,
            adm.observacao_chefe
        FROM operacao.registro_anormalidade a
        JOIN cadastro.sala s ON s.id = a.sala_id
        LEFT JOIN pessoa.operador op ON op.id = a.criado_por
        LEFT JOIN operacao.registro_anormalidade_admin AS adm
               ON adm.registro_anormalidade_id = a.id
        WHERE a.id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [anom_id])
        rows = fetch_all_dict(cur)
        return rows[0] if rows else None

def set_anormalidade_observacao_supervisor(anom_id: int, texto: str, user_id: str) -> None:
    """
    Atualiza o campo observacao_supervisor para a anormalidade indicada.

    Regras:
      - Só permite preencher uma única vez por registro.
      - Se já houver valor não vazio, lança ValueError.
      - Se a linha ainda não existir, este usuário será o "criador".
      - Se a linha já existir (criada pelo outro papel), este usuário será o "atualizador".
    """
    if not user_id:
        raise ValueError("user_id obrigatório para registrar observação do supervisor.")

    sql = """
        INSERT INTO operacao.registro_anormalidade_admin (
            registro_anormalidade_id,
            observacao_supervisor,
            criado_por,
            criado_em
        )
        VALUES (%s::bigint, %s::text, %s::uuid, NOW())
        ON CONFLICT (registro_anormalidade_id) DO UPDATE
        SET
            observacao_supervisor = EXCLUDED.observacao_supervisor,
            -- Se ainda não havia criador (caso estranho), este passa a ser o criador
            criado_por = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE operacao.registro_anormalidade_admin.criado_por
            END,
            criado_em = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NULL
                    THEN EXCLUDED.criado_em
                ELSE operacao.registro_anormalidade_admin.criado_em
            END,
            -- Se já havia criador e ainda não havia atualizado_por, este passa a ser o atualizador
            atualizado_por = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NOT NULL
                     AND operacao.registro_anormalidade_admin.atualizado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE operacao.registro_anormalidade_admin.atualizado_por
            END,
            atualizado_em = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NOT NULL
                     AND operacao.registro_anormalidade_admin.atualizado_por IS NULL
                    THEN NOW()
                ELSE operacao.registro_anormalidade_admin.atualizado_em
            END
        WHERE operacao.registro_anormalidade_admin.observacao_supervisor IS NULL
           OR operacao.registro_anormalidade_admin.observacao_supervisor = '';
    """
    with connection.cursor() as cur:
        cur.execute(sql, [anom_id, texto, user_id])
        if cur.rowcount == 0:
            # Nenhuma linha inserida/atualizada => já havia observação preenchida
            raise ValueError("Observação do supervisor já foi preenchida para este registro.")


# --- 6. CHECKLISTS DO OPERADOR (Meus Checklists) ---
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
    Sem busca textual e sem filtro de período.
    """
    valid_cols = {
        "sala": "s.nome",
        "data": "c.data_operacao",
        "qtde_ok": "qtde_ok",
        "qtde_falha": "qtde_falha",
    }

    # Sem search: passamos vazio
    where, params, order_by = _build_filter_sort(
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

    # Subqueries para contagem OK/Falha (exclui itens de texto livre)
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

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = _append_column_filters(
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
            headers = fetch_all_dict(cur)

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


# --- 7. OPERAÇÕES DE ÁUDIO DO OPERADOR (Minhas Operações) ---
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
    Colunas: Sala, Data, Início Operação, Fim Operação, Anormalidade?
    """
    valid_cols = {
        "sala": "s.nome",
        "data": "r.data",
        "inicio_operacao": "e.hora_entrada",
        "fim_operacao": "e.hora_saida",
        "anormalidade": "e.houve_anormalidade",
    }

    where, params, order_by = _build_filter_sort(
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

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = _append_column_filters(
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
            headers = fetch_all_dict(cur)

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


def set_anormalidade_observacao_chefe(anom_id: int, texto: str, user_id: str) -> None:
    """
    Atualiza o campo observacao_chefe para a anormalidade indicada.

    Regras:
      - Só permite preencher uma única vez por registro.
      - Se já houver valor não vazio, lança ValueError.
      - Se a linha ainda não existir, este usuário será o "criador".
      - Se a linha já existir (criada pelo outro papel), este usuário será o "atualizador".
    """
    if not user_id:
        raise ValueError("user_id obrigatório para registrar observação do chefe de serviço.")

    sql = """
        INSERT INTO operacao.registro_anormalidade_admin (
            registro_anormalidade_id,
            observacao_chefe,
            criado_por,
            criado_em
        )
        VALUES (%s::bigint, %s::text, %s::uuid, NOW())
        ON CONFLICT (registro_anormalidade_id) DO UPDATE
        SET
            observacao_chefe = EXCLUDED.observacao_chefe,
            criado_por = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE operacao.registro_anormalidade_admin.criado_por
            END,
            criado_em = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NULL
                    THEN EXCLUDED.criado_em
                ELSE operacao.registro_anormalidade_admin.criado_em
            END,
            atualizado_por = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NOT NULL
                     AND operacao.registro_anormalidade_admin.atualizado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE operacao.registro_anormalidade_admin.atualizado_por
            END,
            atualizado_em = CASE
                WHEN operacao.registro_anormalidade_admin.criado_por IS NOT NULL
                     AND operacao.registro_anormalidade_admin.atualizado_por IS NULL
                    THEN NOW()
                ELSE operacao.registro_anormalidade_admin.atualizado_em
            END
        WHERE operacao.registro_anormalidade_admin.observacao_chefe IS NULL
           OR operacao.registro_anormalidade_admin.observacao_chefe = '';
    """
    with connection.cursor() as cur:
        cur.execute(sql, [anom_id, texto, user_id])
        if cur.rowcount == 0:
            raise ValueError("Observação do chefe de serviço já foi preenchida para este registro.")

# --- 5. ANORMALIDADES (Dinâmico - Master/Detail) ---

def list_salas_com_anormalidades(search: str = "") -> List[Dict[str, Any]]:
    """
    Lista apenas salas que POSSUEM anormalidades.

    Se 'search' for informado, filtra salas que possuem anormalidades
    correspondentes à busca (nome da sala, descrição, evento, responsável, operador).
    """
    where_parts: List[str] = []
    params: List[Any] = []

    if search:
        term = f"%{search.strip()}%"
        # Busca nas colunas da Anormalidade ou da Sala
        where_parts.append("""
            (
                s.nome ILIKE %s OR 
                a.descricao_anormalidade ILIKE %s OR 
                a.nome_evento ILIKE %s OR
                a.responsavel_evento ILIKE %s OR
                op.nome_completo ILIKE %s
            )
        """)
        # Parâmetros repetidos para cada ILIKE no grupo OR
        params.extend([term] * 5)

    where_clause = "WHERE " + " AND ".join(where_parts) if where_parts else ""

    sql = f"""
        SELECT DISTINCT
            s.id,
            s.nome
        FROM cadastro.sala s
        JOIN operacao.registro_anormalidade a ON a.sala_id = s.id
        LEFT JOIN pessoa.operador op ON op.id = a.criado_por
        {where_clause}
        ORDER BY
            COALESCE(s.ordem, 9999),
            s.nome ASC,
            s.id ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql, params)
        return fetch_all_dict(cur)


def list_anormalidades_por_sala(
    limit: int,
    offset: int,
    search: str = "",
    sort: str = "data",
    direction: str = "desc",
    periodo: Optional[Dict[str, Any]] = None,
    sala_id: Optional[int] = None,
    filters: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], int, Dict[str, Any]]:

    valid_cols = {
        "data": "a.data",
        "sala": "s.nome",
        "registrado_por": "op.nome_completo",
        "descricao": "a.descricao_anormalidade",
        "solucionada": "a.resolvida_pelo_operador",
        "houve_prejuizo": "a.houve_prejuizo",
        "houve_reclamacao": "a.houve_reclamacao",
    }
    search_cols = [
        "s.nome",
        "COALESCE(op.nome_completo, 'Sistema')",
        "a.descricao_anormalidade",
        "TO_CHAR(a.data, 'DD/MM/YYYY')",
    ]

    where, params, order_by = _build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="a.data",
    )

    where, params = _append_date_range_filter(where, params, "a.data", periodo)


    if sala_id is not None:
        where = where + (" AND " if where else "WHERE ") + "a.sala_id = %s::smallint"
        params.append(int(sala_id))

    col_map = {
        "data": "a.data",
        "sala": "s.nome",
        "registrado_por": "COALESCE(op.nome_completo, 'Sistema')",
        "descricao": "a.descricao_anormalidade",
        "solucionada": "a.resolvida_pelo_operador",
        "houve_prejuizo": "a.houve_prejuizo",
        "houve_reclamacao": "a.houve_reclamacao",
    }
    col_types = {
        "data": "date",
        "sala": "text",
        "registrado_por": "text",
        "descricao": "text",
        "solucionada": "bool",
        "houve_prejuizo": "bool",
        "houve_reclamacao": "bool",
    }

    joins = """
        FROM operacao.registro_anormalidade a
        JOIN cadastro.sala s ON s.id = a.sala_id
        LEFT JOIN pessoa.operador op ON op.id = a.criado_por
    """

    base_where = where
    base_params = list(params)

    distinct = _fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where, params = _append_column_filters(
        base_where,
        list(base_params),
        filters,
        col_map,
        col_types,
    )

    sql_count = f"SELECT COUNT(*) {joins} {where};"

    sql_list = f"""
        SELECT
            a.id,
            a.data,
            s.nome AS sala,
            COALESCE(op.nome_completo, 'Sistema') AS registrado_por,
            a.descricao_anormalidade AS descricao,
            a.data_solucao,
            a.resolvida_pelo_operador,
            a.houve_prejuizo,
            a.houve_reclamacao
        {joins}
        {where}
        {order_by}
        LIMIT %s OFFSET %s;
    """

    rows: List[Dict[str, Any]] = []
    with connection.cursor() as cur:
        cur.execute(sql_count, params)
        total = cur.fetchone()[0] or 0

        if total > 0:
            cur.execute(sql_list, params + [limit, offset])
            rows = fetch_all_dict(cur)

    result: List[Dict[str, Any]] = []
    for r in rows:
        result.append(
            {
                "id": r["id"],
                "data": r["data"],
                "sala": r["sala"],
                "registrado_por": r.get("registrado_por") or "Sistema",
                "descricao": r.get("descricao") or "",
                "solucionada": bool(r.get("resolvida_pelo_operador")),
                "houve_prejuizo": bool(r.get("houve_prejuizo")),
                "houve_reclamacao": bool(r.get("houve_reclamacao")),
            }
        )

    return result, int(total), distinct