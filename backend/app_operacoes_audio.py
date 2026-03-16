import os

import pandas as pd
from sqlalchemy import create_engine
import streamlit as st

# -------------------------------------------------
# Configuração básica da página
# -------------------------------------------------
st.set_page_config(
    page_title="Operações de Áudio (Sessões + Entradas)",
    layout="wide",
)

st.markdown(
    """
    <style>
        /* Fundo branco da app */
        .stApp {
            background-color: #FFFFFF;
        }

        /* Remove boa parte do espaçamento interno padrão */
        .block-container {
            padding-top: 0.65rem;
            padding-bottom: 0.25rem;
            padding-left: 0.50rem;
            padding-right: 0.50rem;
        }

        /* (Opcional) esconde menu e rodapé do Streamlit */
        #MainMenu { visibility: hidden; }
        footer { visibility: hidden; }
        header { visibility: hidden; }
    </style>
    """,
    unsafe_allow_html=True,
)

# -------------------------------------------------
# Conexão com o banco (n8n_data)
# -------------------------------------------------
# Sugestão: defina DATABASE_URL no .env ou no secrets.toml do Streamlit
# Exemplo de valor:
#   postgresql+psycopg2://n8n_user:SUA_SENHA@127.0.0.1:5432/n8n_data
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError(
        "Variável de ambiente DATABASE_URL não definida. "
        "Exemplo: postgresql+psycopg2://n8n_user:SENHA@127.0.0.1:5432/n8n_data"
    )

engine = create_engine(DATABASE_URL)


# -------------------------------------------------
# Carrega Sessões + Entradas do banco
# (baseado em admin_dashboard.list_operacoes_dashboard)
# -------------------------------------------------
@st.cache_data(show_spinner=True)
def carregar_sessoes_e_entradas():
    # Sessões: operacao.registro_operacao_audio + sala + autor
    sql_sessoes = """
        SELECT
            r.id,
            r.data,
            s.nome AS sala,
            op.nome_completo AS autor,
            r.checklist_do_dia_id,
            r.em_aberto
        FROM operacao.registro_operacao_audio r
        JOIN cadastro.sala s ON s.id = r.sala_id
        LEFT JOIN pessoa.operador op ON op.id = r.criado_por
        ORDER BY r.data DESC, s.nome ASC;
    """

    # Entradas: operacao.registro_operacao_operador + operador + comissão
    sql_entradas = """
        SELECT
            e.id,
            e.registro_id,
            e.ordem,
            e.operador_id,
            op.nome_completo AS operador,
            e.tipo_evento,
            c.nome AS comissao_nome,
            e.nome_evento,
            e.horario_pauta,
            e.horario_inicio,
            e.horario_termino,
            e.houve_anormalidade
        FROM operacao.registro_operacao_operador e
        JOIN pessoa.operador op ON op.id = e.operador_id
        LEFT JOIN cadastro.comissao c ON c.id = e.comissao_id
        ORDER BY e.registro_id, e.ordem;
    """

    with engine.connect() as conn:
        df_sessoes = pd.read_sql(sql_sessoes, conn)
        df_entradas = pd.read_sql(sql_entradas, conn)

    # -----------------------
    # Ajustes nas Sessões
    # -----------------------
    # Data em datetime + formato BR para busca/exibição
    df_sessoes["data"] = pd.to_datetime(df_sessoes["data"]).dt.date
    df_sessoes["data_br"] = pd.to_datetime(df_sessoes["data"]).dt.strftime(
        "%d/%m/%Y"
    )

    # Checklist realizado / não realizado
    df_sessoes["verificacao"] = df_sessoes["checklist_do_dia_id"].notna().map(
        {True: "Realizada", False: "Não Realizada"}
    )

    # Em aberto (Sim/Não)
    df_sessoes["em_aberto_str"] = df_sessoes["em_aberto"].map(
        {True: "Sim", False: "Não"}
    )

    # -----------------------
    # Ajustes nas Entradas
    # -----------------------
    # Juntar nome da sala da sessão, para aplicar a mesma lógica do dashboard
    df_sessoes_sala = df_sessoes[["id", "sala"]].rename(columns={"id": "sessao_id"})
    df_entradas = df_entradas.merge(
        df_sessoes_sala,
        left_on="registro_id",
        right_on="sessao_id",
        how="left",
    )

    def calcula_tipo_display(row):
        sala = (row["sala"] or "").lower()
        comissao = row["comissao_nome"]

        # Regra 1: se nome da sala contém Auditório
        if "auditório" in sala or "auditorio" in sala:
            return "Auditório"

        # Regra 2: se nome da sala contém Plenário
        if "plenário" in sala or "plenario" in sala:
            return "Plenário"

        # Regra 3: se não for caso especial, usar sigla da comissão
        if comissao:
            return comissao.split(" - ")[0].strip()

        return "-"

    df_entradas["tipo_display"] = df_entradas.apply(calcula_tipo_display, axis=1)
    df_entradas["tem_anormalidade"] = df_entradas["houve_anormalidade"].astype(bool)

    return df_sessoes, df_entradas


# -------------------------------------------------
# UI – Filtros (equivalente ao stateOps: search)
# -------------------------------------------------
# Carrega sessões e entradas (mesma função de antes, só vamos usar as sessões aqui)
df_sessoes, df_entradas = carregar_sessoes_e_entradas()

# Seleciona e renomeia as colunas que queremos exibir na tabela
cols_sessoes = (
    df_sessoes[
        [
            "id",
            "data_br",
            "sala",
            "autor",
            "verificacao",
            "em_aberto_str",
        ]
    ]
    .rename(
        columns={
            "id": "Sessão ID",
            "data_br": "Data",
            "sala": "Local",
            "autor": "Autor",
            "verificacao": "Verificação do Local",
            "em_aberto_str": "Sessão em aberto?",
        }
    )
)

# Exibe somente a tabela, ocupando toda a largura do container
st.dataframe(
    cols_sessoes,
    use_container_width=True,
    height=560,  # ajuste fino: 520px pra preencher quase todo o iframe
)
