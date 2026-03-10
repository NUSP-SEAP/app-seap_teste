from typing import Optional, Dict, Any
from django.db import connection


def insert_registro_anormalidade(
    registro_id: int,
    data: str,
    sala_id: int,
    nome_evento: str,
    hora_inicio_anormalidade: str,
    descricao_anormalidade: str,
    houve_prejuizo: bool,
    descricao_prejuizo: Optional[str],
    houve_reclamacao: bool,
    autores_conteudo_reclamacao: Optional[str],
    acionou_manutencao: bool,
    hora_acionamento_manutencao: Optional[str],
    resolvida_pelo_operador: bool,
    procedimentos_adotados: Optional[str],
    data_solucao: Optional[str],
    hora_solucao: Optional[str],
    responsavel_evento: str,
    criado_por: Optional[str] = None,
    atualizado_por: Optional[str] = None,
    entrada_id: Optional[int] = None,
) -> int:
    """
    Insere um registro de anormalidade na tabela operacao.registro_anormalidade.

    - data / hora_inicio_anormalidade / hora_acionamento_manutencao / hora_solucao:
      strings já validadas no formato esperado (YYYY-MM-DD e HH:MM).
    - data_solucao e hora_solucao podem ser NULL.
    - entrada_id é opcional (pode ser NULL).
    - criado_por / atualizado_por: UUID do usuário autenticado.
    """
    sql = """
    INSERT INTO operacao.registro_anormalidade (
        registro_id,
        data,
        sala_id,
        nome_evento,
        hora_inicio_anormalidade,
        descricao_anormalidade,
        houve_prejuizo,
        descricao_prejuizo,
        houve_reclamacao,
        autores_conteudo_reclamacao,
        acionou_manutencao,
        hora_acionamento_manutencao,
        resolvida_pelo_operador,
        procedimentos_adotados,
        data_solucao,
        hora_solucao,
        responsavel_evento,
        criado_por,
        atualizado_por,
        entrada_id
    )
    VALUES (
        %s::bigint,
        %s::date,
        %s::smallint,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::time,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::boolean,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::boolean,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::boolean,
        %s::time,
        %s::boolean,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::date,
        %s::time,
        NULLIF(BTRIM(%s::text), '')::text,
        %s::uuid,
        %s::uuid,
        %s::bigint
    )
    RETURNING id;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                registro_id,
                data,
                sala_id,
                nome_evento,
                hora_inicio_anormalidade,
                descricao_anormalidade,
                houve_prejuizo,
                descricao_prejuizo or "",
                houve_reclamacao,
                autores_conteudo_reclamacao or "",
                acionou_manutencao,
                hora_acionamento_manutencao,
                resolvida_pelo_operador,
                procedimentos_adotados or "",
                data_solucao,
                hora_solucao,
                responsavel_evento,
                criado_por,
                atualizado_por,
                entrada_id,
            ],
        )
        (new_id,) = cur.fetchone()
        return int(new_id)


def get_registro_operacao_audio_for_anormalidade(
    registro_id: int,
    entrada_id: Optional[int] = None,
) -> Optional[dict]:
    """
    Retorna dados básicos para pré-preencher a RAOA.

    Campos retornados:
      - id          (int)  -> id da sessão (registro_operacao_audio)
      - data        (str)  -> YYYY-MM-DD
      - sala_id     (int)
      - nome_evento (str)  -> vindo da ENTRADA, se disponível
    """

    if entrada_id is not None:
        # Usa a entrada específica para pegar o nome do evento
        sql = """
        SELECT
            r.id::bigint,
            r.data::text,
            r.sala_id::smallint,
            e.nome_evento::text
        FROM operacao.registro_operacao_audio AS r
        JOIN operacao.registro_operacao_operador AS e
          ON e.registro_id = r.id
         AND e.id = %s::bigint
        WHERE r.id = %s::bigint;
        """
        params = [entrada_id, registro_id]
    else:
        # Fallback: usa o nome_evento da primeira entrada da sessão (se houver)
        sql = """
        SELECT
            r.id::bigint,
            r.data::text,
            r.sala_id::smallint,
            (
                SELECT e.nome_evento::text
                FROM operacao.registro_operacao_operador AS e
                WHERE e.registro_id = r.id
                ORDER BY e.ordem ASC, e.id ASC
                LIMIT 1
            ) AS nome_evento
        FROM operacao.registro_operacao_audio AS r
        WHERE r.id = %s::bigint;
        """
        params = [registro_id]

    with connection.cursor() as cur:
        cur.execute(sql, params)
        row = cur.fetchone()
        if not row:
            return None

        return {
            "id": int(row[0]),
            "data": row[1],
            "sala_id": int(row[2]),
            "nome_evento": row[3],
        }


def get_registro_anormalidade_por_entrada(entrada_id: int) -> Optional[Dict[str, Any]]:
    """
    Busca o registro de anormalidade vinculado a uma ENTRADA
    (operacao.registro_anormalidade.entrada_id).

    Retorna None se não existir.
    """
    sql = """
        SELECT
            id,
            registro_id,
            entrada_id,
            data,
            sala_id,
            nome_evento,
            hora_inicio_anormalidade,
            descricao_anormalidade,
            houve_prejuizo,
            descricao_prejuizo,
            houve_reclamacao,
            autores_conteudo_reclamacao,
            acionou_manutencao,
            hora_acionamento_manutencao,
            resolvida_pelo_operador,
            procedimentos_adotados,
            data_solucao,
            hora_solucao,
            responsavel_evento
        FROM operacao.registro_anormalidade
        WHERE entrada_id = %s::bigint
        ORDER BY id DESC
        LIMIT 1;
    """
    with connection.cursor() as cur:
        cur.execute(sql, [entrada_id])
        row = cur.fetchone()
        if not row:
            return None

        data_solucao = row[16]
        hora_solucao = row[17]
        # Se tiver data ou hora de solução, consideramos "solucionada"
        anormalidade_solucionada = bool(data_solucao or hora_solucao)

        return {
            "id": int(row[0]),
            "registro_id": int(row[1]),
            "entrada_id": int(row[2]),
            "data": row[3],
            "sala_id": int(row[4]),
            "nome_evento": row[5],
            "hora_inicio_anormalidade": row[6],
            "descricao_anormalidade": row[7],
            "houve_prejuizo": bool(row[8]),
            "descricao_prejuizo": row[9],
            "houve_reclamacao": bool(row[10]),
            "autores_conteudo_reclamacao": row[11],
            "acionou_manutencao": bool(row[12]),
            "hora_acionamento_manutencao": row[13],
            "resolvida_pelo_operador": bool(row[14]),
            "procedimentos_adotados": row[15],
            "data_solucao": data_solucao,
            "hora_solucao": hora_solucao,
            "responsavel_evento": row[18],
            # Campo derivado, usado apenas para preencher o rádio no front-end
            "anormalidade_solucionada": anormalidade_solucionada,
        }


def update_registro_anormalidade(
    anom_id: int,
    data: str,
    sala_id: int,
    nome_evento: str,
    hora_inicio_anormalidade: str,
    descricao_anormalidade: str,
    houve_prejuizo: bool,
    descricao_prejuizo: Optional[str],
    houve_reclamacao: bool,
    autores_conteudo_reclamacao: Optional[str],
    acionou_manutencao: bool,
    hora_acionamento_manutencao: Optional[str],
    resolvida_pelo_operador: bool,
    procedimentos_adotados: Optional[str],
    data_solucao: Optional[str],
    hora_solucao: Optional[str],
    responsavel_evento: str,
    atualizado_por: Optional[str] = None,
) -> int:
    """
    Atualiza um registro de anormalidade existente.
    """
    sql = """
        UPDATE operacao.registro_anormalidade
           SET data = %s::date,
               sala_id = %s::smallint,
               nome_evento = NULLIF(BTRIM(%s::text), '')::text,
               hora_inicio_anormalidade = %s::time,
               descricao_anormalidade = NULLIF(BTRIM(%s::text), '')::text,
               houve_prejuizo = %s::boolean,
               descricao_prejuizo = NULLIF(BTRIM(%s::text), '')::text,
               houve_reclamacao = %s::boolean,
               autores_conteudo_reclamacao = NULLIF(BTRIM(%s::text), '')::text,
               acionou_manutencao = %s::boolean,
               hora_acionamento_manutencao = %s::time,
               resolvida_pelo_operador = %s::boolean,
               procedimentos_adotados = NULLIF(BTRIM(%s::text), '')::text,
               data_solucao = %s::date,
               hora_solucao = %s::time,
               responsavel_evento = NULLIF(BTRIM(%s::text), '')::text,
               atualizado_em = now(),
               atualizado_por = %s::uuid
         WHERE id = %s::bigint;
    """
    with connection.cursor() as cur:
        cur.execute(
            sql,
            [
                data,
                sala_id,
                nome_evento,
                hora_inicio_anormalidade,
                descricao_anormalidade,
                houve_prejuizo,
                descricao_prejuizo or "",
                houve_reclamacao,
                autores_conteudo_reclamacao or "",
                acionou_manutencao,
                hora_acionamento_manutencao,
                resolvida_pelo_operador,
                procedimentos_adotados or "",
                data_solucao,
                hora_solucao,
                responsavel_evento,
                atualizado_por,
                anom_id,
            ],
        )
    return anom_id
