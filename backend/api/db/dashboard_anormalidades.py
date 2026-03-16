"""Dashboard de anormalidades — listagem, detalhe e observações para admin."""
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection

from .query_helpers import (
    build_filter_sort,
    append_date_range_filter,
    append_column_filters,
    fetch_distinct_map,
)
from .utils import fetchall_dicts


def list_salas_com_anormalidades(search: str = "") -> List[Dict[str, Any]]:
    """
    Lista apenas salas que POSSUEM anormalidades.
    Se 'search' for informado, filtra por nome da sala, descrição, evento, responsável ou operador.
    """
    where_parts: List[str] = []
    params: List[Any] = []

    if search:
        term = f"%{search.strip()}%"
        where_parts.append("""
            (
                s.nome ILIKE %s OR
                a.descricao_anormalidade ILIKE %s OR
                a.nome_evento ILIKE %s OR
                a.responsavel_evento ILIKE %s OR
                op.nome_completo ILIKE %s
            )
        """)
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
        return fetchall_dicts(cur)


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

    where, params, order_by = build_filter_sort(
        search=search,
        sort=sort,
        direction=direction,
        valid_cols=valid_cols,
        search_cols=search_cols,
        default_sort="a.data",
    )

    where, params = append_date_range_filter(where, params, "a.data", periodo)

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
            rows = fetchall_dicts(cur)

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
        rows = fetchall_dicts(cur)
        return rows[0] if rows else None


def _set_anormalidade_observacao(anom_id: int, campo: str, texto: str, user_id: str) -> None:
    """
    Atualiza um campo de observação (observacao_supervisor ou observacao_chefe)
    para a anormalidade indicada.

    Regras:
      - Só permite preencher uma única vez por registro.
      - Se já houver valor não vazio, lança ValueError.
      - Se a linha ainda não existir, este usuário será o "criador".
      - Se a linha já existir (criada pelo outro papel), este usuário será o "atualizador".
    """
    if campo not in ("observacao_supervisor", "observacao_chefe"):
        raise ValueError(f"Campo inválido: {campo}")

    if not user_id:
        raise ValueError("user_id obrigatório para registrar observação.")

    tbl = "operacao.registro_anormalidade_admin"

    sql = f"""
        INSERT INTO {tbl} (
            registro_anormalidade_id,
            {campo},
            criado_por,
            criado_em
        )
        VALUES (%s::bigint, %s::text, %s::uuid, NOW())
        ON CONFLICT (registro_anormalidade_id) DO UPDATE
        SET
            {campo} = EXCLUDED.{campo},
            criado_por = CASE
                WHEN {tbl}.criado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE {tbl}.criado_por
            END,
            criado_em = CASE
                WHEN {tbl}.criado_por IS NULL
                    THEN EXCLUDED.criado_em
                ELSE {tbl}.criado_em
            END,
            atualizado_por = CASE
                WHEN {tbl}.criado_por IS NOT NULL
                     AND {tbl}.atualizado_por IS NULL
                    THEN EXCLUDED.criado_por
                ELSE {tbl}.atualizado_por
            END,
            atualizado_em = CASE
                WHEN {tbl}.criado_por IS NOT NULL
                     AND {tbl}.atualizado_por IS NULL
                    THEN NOW()
                ELSE {tbl}.atualizado_em
            END
        WHERE {tbl}.{campo} IS NULL
           OR {tbl}.{campo} = '';
    """
    with connection.cursor() as cur:
        cur.execute(sql, [anom_id, texto, user_id])
        if cur.rowcount == 0:
            label = "supervisor" if campo == "observacao_supervisor" else "chefe de serviço"
            raise ValueError(f"Observação do {label} já foi preenchida para este registro.")


def set_anormalidade_observacao_supervisor(anom_id: int, texto: str, user_id: str) -> None:
    """Atualiza observacao_supervisor para a anormalidade indicada."""
    _set_anormalidade_observacao(anom_id, "observacao_supervisor", texto, user_id)


def set_anormalidade_observacao_chefe(anom_id: int, texto: str, user_id: str) -> None:
    """Atualiza observacao_chefe para a anormalidade indicada."""
    _set_anormalidade_observacao(anom_id, "observacao_chefe", texto, user_id)
