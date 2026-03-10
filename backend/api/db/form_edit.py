from typing import List, Dict, Any, Tuple, Optional

from django.db import connection, transaction


# Configuração das entidades suportadas na tela de edição de formulários.
# A chave é o valor que virá na URL: /admin/form-edit/<entidade>/...
ENTITY_CONFIG: Dict[str, Dict[str, Any]] = {
    "salas": {
        "table": "cadastro.sala",
        # Para salas vamos criar a coluna `ordem smallint` permitindo NULL.
        "ord_allows_null": True,
        "inactive_ord": None,  # inativas ficam com ordem = NULL no banco
        "id_cast": "::smallint",
        "has_audit_user": False,
    },
    "comissoes": {
        "table": "cadastro.comissao",
        # Aqui `ordem` já existe e permite NULL.
        "ord_allows_null": True,
        "inactive_ord": None,
        "id_cast": "::bigint",
        "has_audit_user": True,  # tem criado_por / atualizado_por (uuid)
    },
}


class EntidadeInvalidaError(ValueError):
    pass


def _get_entity_cfg(entidade: str) -> Dict[str, Any]:
    """
    Valida e devolve a configuração da entidade.
    """
    cfg = ENTITY_CONFIG.get(entidade)
    if not cfg:
        raise EntidadeInvalidaError(f"Entidade inválida: {entidade!r}")
    return cfg


def list_form_edit_items(entidade: str) -> List[Dict[str, Any]]:
    """
    Lista os registros de uma das entidades ('salas', 'comissoes')
    para uso na tela de edição.

    Retorna uma lista de dicts:
        { "id": int, "nome": str, "ordem": Optional[int], "ativo": bool }

    Regras:
      - Itens ativos vêm primeiro, ordenados por ordem ascendente.
      - Itens inativos vêm depois; no payload `ordem` é sempre None.
    """
    cfg = _get_entity_cfg(entidade)
    table = cfg["table"]

    sql = f"""
        SELECT
            id,
            nome::text,
            ordem,
            ativo
        FROM {table}
        ORDER BY
            ativo DESC,
            ordem ASC NULLS LAST,
            nome ASC,
            id ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()

    result: List[Dict[str, Any]] = []
    for row in rows:
        id_val, nome, ordem, ativo = row

        ativo_bool = bool(ativo)
        ordem_payload: Optional[int]
        if ativo_bool:
            ordem_payload = ordem
        else:
            ordem_payload = None

        result.append({
            "id": int(id_val),
            "nome": nome,
            "ordem": ordem_payload,
            "ativo": ativo_bool,
        })

    return result


def save_form_edit_items(
    entidade: str,
    items: List[Dict[str, Any]],
    user_id: Optional[str] = None,
) -> Tuple[int, int]:
    """
    Persiste as alterações feitas na tela de edição de formulários.

    Parâmetros:
        entidade: 'salas' ou 'comissoes'
        items: lista na ORDEM FINAL desejada (primeiro ativos, depois inativos).
            Cada item deve ter:
                - id: int | None (None = novo registro)
                - nome: str (não vazio)
                - ativo: bool

        user_id: uuid do usuário autenticado (para audit trail em comissões).

    Regras aplicadas:
      - `ordem` para itens ATIVOS é reatribuída como 1..N, seguindo a ordem da lista.
      - Para itens INATIVOS:
          * se a coluna permitir NULL → ordem = NULL
          * caso contrário → valor especial (0), conforme ENTITY_CONFIG.
      - Não há DELETE físico; só atualizamos `ativo`/`ordem`/`nome`.
    """
    cfg = _get_entity_cfg(entidade)
    table = cfg["table"]
    ord_allows_null: bool = cfg["ord_allows_null"]
    inactive_ord = cfg["inactive_ord"]
    has_audit_user: bool = cfg["has_audit_user"]

    cleaned: List[Dict[str, Any]] = []
    ordem_counter = 1

    # 1) Validação básica + cálculo de ordem em memória
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f"Item na posição {idx} é inválido (esperado objeto).")

        raw_id = item.get("id")
        nome = (item.get("nome") or "").strip()
        ativo = bool(item.get("ativo"))

        if not nome:
            raise ValueError(f"Nome não pode ser vazio (item na posição {idx}).")

        # Define ordem conforme se está ativo ou não
        if ativo:
            ordem = ordem_counter
            ordem_counter += 1
        else:
            if ord_allows_null:
                ordem = None
            else:
                ordem = inactive_ord

        cleaned.append({
            "id": raw_id,
            "nome": nome,
            "ativo": ativo,
            "ordem": ordem,
        })

    created = 0
    updated = 0

    # 2) Persistência transacional
    with transaction.atomic():
        with connection.cursor() as cur:
            for idx, item in enumerate(cleaned):
                registro_id = item["id"]
                nome = item["nome"]
                ativo = item["ativo"]
                ordem = item["ordem"]

                if registro_id is None:
                    # INSERT
                    if has_audit_user:
                        sql = f"""
                            INSERT INTO {table} (
                                nome,
                                ativo,
                                ordem,
                                criado_por,
                                atualizado_por
                            )
                            VALUES (
                                %s::text,
                                %s::boolean,
                                %s::smallint,
                                %s::uuid,
                                %s::uuid
                            )
                            RETURNING id;
                        """
                        params = [nome, ativo, ordem, user_id, user_id]
                    else:
                        sql = f"""
                            INSERT INTO {table} (
                                nome,
                                ativo,
                                ordem
                            )
                            VALUES (
                                %s::text,
                                %s::boolean,
                                %s::smallint
                            )
                            RETURNING id;
                        """
                        params = [nome, ativo, ordem]

                    cur.execute(sql, params)
                    new_id = cur.fetchone()[0]
                    item["id"] = new_id
                    created += 1
                else:
                    # UPDATE
                    if has_audit_user:
                        sql = f"""
                            UPDATE {table}
                               SET nome = %s::text,
                                   ativo = %s::boolean,
                                   ordem = %s::smallint,
                                   atualizado_por = %s::uuid,
                                   atualizado_em = NOW()
                             WHERE id = %s;
                        """
                        params = [nome, ativo, ordem, user_id, registro_id]
                    else:
                        sql = f"""
                            UPDATE {table}
                               SET nome = %s::text,
                                   ativo = %s::boolean,
                                   ordem = %s::smallint,
                                   atualizado_em = NOW()
                             WHERE id = %s;
                        """
                        params = [nome, ativo, ordem, registro_id]

                    cur.execute(sql, params)
                    if cur.rowcount == 0:
                        raise ValueError(
                            f"Registro com id {registro_id} não encontrado (posição {idx})."
                        )
                    updated += cur.rowcount

    return created, updated


def list_sala_config_items(sala_id: int) -> List[Dict[str, Any]]:
    """
    Lista os itens de checklist configurados para uma sala específica.

    Retorna uma lista de dicts:
        {
            "id": int,               # ID na tabela checklist_sala_config
            "item_tipo_id": int,     # ID do item tipo
            "nome": str,             # Nome do item (vem do catálogo item_tipo)
            "tipo_widget": str,      # Tipo do widget (radio ou text)
            "ordem": int,
            "ativo": bool
        }

    Regras:
      - Retorna TODOS os itens (ativos e inativos)
      - Itens ativos ordenados por ordem ASC
      - Itens inativos ao final, ordenados por nome
    """
    sql = """
        SELECT
            csc.id,
            csc.item_tipo_id,
            cit.nome::text,
            cit.tipo_widget::text,
            csc.ordem,
            csc.ativo
        FROM forms.checklist_sala_config csc
        INNER JOIN forms.checklist_item_tipo cit ON csc.item_tipo_id = cit.id
        WHERE csc.sala_id = %s::smallint
        ORDER BY
            csc.ativo DESC,
            csc.ordem ASC NULLS LAST,
            cit.nome ASC;
    """

    with connection.cursor() as cur:
        cur.execute(sql, [sala_id])
        rows = cur.fetchall()

    return [
        {
            "id": int(row[0]),
            "item_tipo_id": int(row[1]),
            "nome": row[2],
            "tipo_widget": row[3] or "radio",
            "ordem": int(row[4]) if row[4] is not None else None,
            "ativo": bool(row[5]),
        }
        for row in rows
    ]


def find_or_create_item_tipo(nome: str, tipo_widget: str) -> int:
    """
    Busca item_tipo por (nome, tipo_widget). Se não existe, cria.

    Returns:
        item_tipo_id (int)
    """
    nome = nome.strip()
    if not nome:
        raise ValueError("Nome não pode ser vazio")

    if tipo_widget not in ("radio", "text"):
        raise ValueError("tipo_widget deve ser 'radio' ou 'text'")

    with connection.cursor() as cur:
        sql_find = """
            SELECT id FROM forms.checklist_item_tipo
            WHERE nome = %s::text AND tipo_widget = %s::text;
        """
        cur.execute(sql_find, [nome, tipo_widget])
        row = cur.fetchone()

        if row:
            return int(row[0])

        sql_insert = """
            INSERT INTO forms.checklist_item_tipo (nome, tipo_widget)
            VALUES (%s::text, %s::text)
            RETURNING id;
        """
        cur.execute(sql_insert, [nome, tipo_widget])
        return int(cur.fetchone()[0])


def save_sala_config_items(
    sala_id: int,
    items: List[Dict[str, Any]],
) -> Tuple[int, int]:
    """
    Salva a configuração de itens de checklist para uma sala específica.

    Parâmetros:
        sala_id: ID da sala
        items: lista de itens ATIVOS na ordem desejada.
            Cada item deve ter:
                - nome: str (obrigatório)
                - tipo_widget: str ('radio' ou 'text')
                - ativo: bool

    Lógica:
      1. Desativa todos os itens da sala (ativo = FALSE, ordem = 0)
      2. Para cada item ativo:
         a. find_or_create_item_tipo(nome, tipo_widget) → item_tipo_id
         b. Se já existe config (sala_id + item_tipo_id), faz UPDATE
         c. Se não existe, faz INSERT

    Retorna: (created, updated)
    """
    if not isinstance(sala_id, int) or sala_id <= 0:
        raise ValueError("sala_id inválido")

    if not isinstance(items, list):
        raise ValueError("items deve ser uma lista")

    ordem_counter = 1
    cleaned: List[Dict[str, Any]] = []

    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f"Item na posição {idx} é inválido (esperado objeto).")

        nome = (item.get("nome") or "").strip()
        tipo_widget = item.get("tipo_widget", "radio")
        ativo = bool(item.get("ativo", True))

        if not nome or not ativo:
            continue

        if tipo_widget not in ("radio", "text"):
            tipo_widget = "radio"

        cleaned.append({
            "nome": nome,
            "tipo_widget": tipo_widget,
            "ordem": ordem_counter,
        })
        ordem_counter += 1

    created = 0
    updated = 0

    with transaction.atomic():
        with connection.cursor() as cur:
            # 1. Desativa todos os itens existentes desta sala
            cur.execute("""
                UPDATE forms.checklist_sala_config
                   SET ativo = FALSE, ordem = 0
                 WHERE sala_id = %s::smallint;
            """, [sala_id])

            # 2. Para cada item ativo, find-or-create e upsert
            for item in cleaned:
                item_tipo_id = find_or_create_item_tipo(
                    item["nome"], item["tipo_widget"]
                )

                # Verifica se config já existe para esta sala + item_tipo
                cur.execute("""
                    SELECT id FROM forms.checklist_sala_config
                     WHERE sala_id = %s::smallint
                       AND item_tipo_id = %s::smallint;
                """, [sala_id, item_tipo_id])
                row_check = cur.fetchone()

                if row_check:
                    cur.execute("""
                        UPDATE forms.checklist_sala_config
                           SET ativo = TRUE, ordem = %s::smallint
                         WHERE id = %s;
                    """, [item["ordem"], row_check[0]])
                    updated += 1
                else:
                    cur.execute("""
                        INSERT INTO forms.checklist_sala_config
                            (sala_id, item_tipo_id, ordem, ativo)
                        VALUES
                            (%s::smallint, %s::smallint, %s::smallint, TRUE);
                    """, [sala_id, item_tipo_id, item["ordem"]])
                    created += 1

    return created, updated


def apply_sala_config_to_all(
    source_sala_id: int,
    items: List[Dict[str, Any]],
) -> int:
    """
    Aplica a configuração de itens de uma sala a TODAS as outras salas ATIVAS.

    Parâmetros:
        source_sala_id: ID da sala de origem (referência)
        items: lista de itens ativos na ordem desejada (mesmo formato de save_sala_config_items)

    Retorna:
        Número de salas que foram atualizadas
    """
    if not isinstance(source_sala_id, int) or source_sala_id <= 0:
        raise ValueError("source_sala_id inválido")

    # 1. Busca todas as salas ativas EXCETO a de origem
    sql_salas = """
        SELECT id FROM cadastro.sala
         WHERE ativo = TRUE
           AND id != %s::smallint
        ORDER BY id;
    """

    with connection.cursor() as cur:
        cur.execute(sql_salas, [source_sala_id])
        salas = cur.fetchall()

    salas_ids = [row[0] for row in salas]

    if not salas_ids:
        return 0

    # 2. Para cada sala, aplica a mesma configuração
    count = 0
    for sala_id in salas_ids:
        try:
            save_sala_config_items(sala_id, items)
            count += 1
        except Exception as e:
            # Log do erro, mas continua processando as demais salas
            print(f"Erro ao aplicar config na sala {sala_id}: {e}")

    return count


