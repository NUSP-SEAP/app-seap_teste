"""Dashboard de operações de áudio — listagem e detalhe para admin."""
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection

from .query_helpers import (
    build_filter_sort,
    append_date_range_filter,
    append_column_filters,
    fetch_distinct_map,
)
from .utils import fetchall_dicts, fetchone_dict


def _tipo_display_from_sala_comissao(sala_nome: str, comissao_nome: Optional[str]) -> str:
    """
    Calcula o campo "Tipo" das operações:
      1) Sala Auditório/Plenário → retorna esse texto
      2) Senão, sigla da comissão (antes do " - ")
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

    where, params, order_by = build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="r.data",
    )

    where, params = append_date_range_filter(where, params, "r.data", periodo)

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

    distinct = fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where_f, params_f = append_column_filters(
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
        sessoes = fetchall_dicts(cur)

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
        entradas = fetchall_dicts(cur)

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

    where, params, order_by = build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="r.data",
    )

    where, params = append_date_range_filter(where, params, "r.data", periodo)

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

    distinct = fetch_distinct_map(
        joins_sql=joins,
        base_where=base_where,
        base_params=base_params,
        filters=filters,
        col_map=col_map,
        col_types=col_types,
    )

    where_f, params_f = append_column_filters(
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
        rows = fetchall_dicts(cur)

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
        return fetchone_dict(cur)
