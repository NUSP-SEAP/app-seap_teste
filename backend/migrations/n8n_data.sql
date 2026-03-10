--
-- PostgreSQL database dump
--

\restrict hZVCfJrbRtudf0DaW4cbk1e0XF7nowlr7Os6D7PyyFOZwgUmfumJTcmc2kxMCYS

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: cadastro; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA cadastro;


--
-- Name: forms; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA forms;


--
-- Name: operacao; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA operacao;


--
-- Name: pessoa; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pessoa;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA pessoa;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pessoa;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: cadastro; Owner: -
--

CREATE FUNCTION cadastro.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: forms; Owner: -
--

CREATE FUNCTION forms.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$$;


--
-- Name: update_item_tipo_timestamp(); Type: FUNCTION; Schema: forms; Owner: -
--

CREATE FUNCTION forms.update_item_tipo_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_sala_config_timestamp(); Type: FUNCTION; Schema: forms; Owner: -
--

CREATE FUNCTION forms.update_sala_config_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: operacao; Owner: -
--

CREATE FUNCTION operacao.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$$;


--
-- Name: sync_houve_anormalidade(); Type: FUNCTION; Schema: operacao; Owner: -
--

CREATE FUNCTION operacao.sync_houve_anormalidade() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_entrada_id_new bigint;
  v_entrada_id_old bigint;
BEGIN
  -- Pega os IDs de entrada envolvidos na operação
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_entrada_id_new := NEW.entrada_id;
  END IF;

  IF TG_OP IN ('DELETE', 'UPDATE') THEN
    v_entrada_id_old := OLD.entrada_id;
  END IF;

  -- 1) Sempre recalcula a situação da NOVA entrada (quando houver)
  IF v_entrada_id_new IS NOT NULL THEN
    UPDATE operacao.registro_operacao_operador e
       SET houve_anormalidade = EXISTS (
             SELECT 1
               FROM operacao.registro_anormalidade a
              WHERE a.entrada_id = v_entrada_id_new
           )
     WHERE e.id = v_entrada_id_new;
  END IF;

  -- 2) Em UPDATE, se a entrada mudou, recalcula também a ANTIGA
  IF TG_OP = 'UPDATE'
     AND v_entrada_id_old IS NOT NULL
     AND v_entrada_id_old <> v_entrada_id_new THEN
    UPDATE operacao.registro_operacao_operador e
       SET houve_anormalidade = EXISTS (
             SELECT 1
               FROM operacao.registro_anormalidade a
              WHERE a.entrada_id = v_entrada_id_old
           )
     WHERE e.id = v_entrada_id_old;
  END IF;

  -- 3) Em DELETE puro (sem UPDATE), recalcula a entrada antiga
  IF TG_OP = 'DELETE'
     AND v_entrada_id_old IS NOT NULL THEN
    UPDATE operacao.registro_operacao_operador e
       SET houve_anormalidade = EXISTS (
             SELECT 1
               FROM operacao.registro_anormalidade a
              WHERE a.entrada_id = v_entrada_id_old
           )
     WHERE e.id = v_entrada_id_old;
  END IF;

  -- AFTER trigger: não precisamos devolver linha
  RETURN NULL;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: pessoa; Owner: -
--

CREATE FUNCTION pessoa.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comissao; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.comissao (
    id bigint NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    ordem smallint,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_por uuid
);


--
-- Name: comissao_id_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.comissao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comissao_id_seq; Type: SEQUENCE OWNED BY; Schema: cadastro; Owner: -
--

ALTER SEQUENCE cadastro.comissao_id_seq OWNED BY cadastro.comissao.id;


--
-- Name: sala; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.sala (
    id smallint NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    ordem smallint
);


--
-- Name: TABLE sala; Type: COMMENT; Schema: cadastro; Owner: -
--

COMMENT ON TABLE cadastro.sala IS 'Cadastro de salas/localizações fixas usadas nos formulários e registros.';


--
-- Name: COLUMN sala.nome; Type: COMMENT; Schema: cadastro; Owner: -
--

COMMENT ON COLUMN cadastro.sala.nome IS 'Nome visível da sala (único).';


--
-- Name: COLUMN sala.ativo; Type: COMMENT; Schema: cadastro; Owner: -
--

COMMENT ON COLUMN cadastro.sala.ativo IS 'Controle lógico de disponibilidade.';


--
-- Name: sala_id_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.sala_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sala_id_seq; Type: SEQUENCE OWNED BY; Schema: cadastro; Owner: -
--

ALTER SEQUENCE cadastro.sala_id_seq OWNED BY cadastro.sala.id;


--
-- Name: checklist; Type: TABLE; Schema: forms; Owner: -
--

CREATE TABLE forms.checklist (
    id bigint NOT NULL,
    data_operacao date NOT NULL,
    sala_id smallint NOT NULL,
    turno text NOT NULL,
    hora_inicio_testes time without time zone NOT NULL,
    hora_termino_testes time without time zone NOT NULL,
    observacoes text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    usb_01 text,
    usb_02 text,
    criado_por uuid,
    atualizado_por uuid,
    editado boolean DEFAULT false NOT NULL,
    observacoes_editado boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_checklist_turno CHECK ((turno = ANY (ARRAY['Matutino'::text, 'Vespertino'::text])))
);


--
-- Name: TABLE checklist; Type: COMMENT; Schema: forms; Owner: -
--

COMMENT ON TABLE forms.checklist IS 'Cabeçalho do checklist (uma execução por operação/turno/local).';


--
-- Name: COLUMN checklist.sala_id; Type: COMMENT; Schema: forms; Owner: -
--

COMMENT ON COLUMN forms.checklist.sala_id IS 'FK para cadastro.sala.';


--
-- Name: COLUMN checklist.turno; Type: COMMENT; Schema: forms; Owner: -
--

COMMENT ON COLUMN forms.checklist.turno IS 'Matutino ou Vespertino (CHECK).';


--
-- Name: checklist_historico; Type: TABLE; Schema: forms; Owner: -
--

CREATE TABLE forms.checklist_historico (
    id bigint NOT NULL,
    checklist_id bigint NOT NULL,
    snapshot jsonb NOT NULL,
    editado_por uuid,
    editado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: checklist_historico_id_seq; Type: SEQUENCE; Schema: forms; Owner: -
--

CREATE SEQUENCE forms.checklist_historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_historico_id_seq; Type: SEQUENCE OWNED BY; Schema: forms; Owner: -
--

ALTER SEQUENCE forms.checklist_historico_id_seq OWNED BY forms.checklist_historico.id;


--
-- Name: checklist_id_seq; Type: SEQUENCE; Schema: forms; Owner: -
--

CREATE SEQUENCE forms.checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: forms; Owner: -
--

ALTER SEQUENCE forms.checklist_id_seq OWNED BY forms.checklist.id;


--
-- Name: checklist_item_tipo; Type: TABLE; Schema: forms; Owner: -
--

CREATE TABLE forms.checklist_item_tipo (
    id smallint NOT NULL,
    nome text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    tipo_widget text DEFAULT 'radio'::text NOT NULL,
    CONSTRAINT checklist_item_tipo_tipo_widget_check CHECK ((tipo_widget = ANY (ARRAY['radio'::text, 'text'::text])))
);


--
-- Name: checklist_item_tipo_id_seq; Type: SEQUENCE; Schema: forms; Owner: -
--

CREATE SEQUENCE forms.checklist_item_tipo_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_item_tipo_id_seq; Type: SEQUENCE OWNED BY; Schema: forms; Owner: -
--

ALTER SEQUENCE forms.checklist_item_tipo_id_seq OWNED BY forms.checklist_item_tipo.id;


--
-- Name: checklist_resposta; Type: TABLE; Schema: forms; Owner: -
--

CREATE TABLE forms.checklist_resposta (
    id bigint NOT NULL,
    checklist_id bigint NOT NULL,
    item_tipo_id smallint NOT NULL,
    status text NOT NULL,
    descricao_falha text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid,
    atualizado_por uuid,
    valor_texto text,
    editado boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_cli_resp_desc_quando_falha CHECK (((status <> 'Falha'::text) OR (descricao_falha IS NOT NULL))),
    CONSTRAINT ck_cli_resp_status CHECK ((status = ANY (ARRAY['Ok'::text, 'Falha'::text])))
);


--
-- Name: checklist_resposta_id_seq; Type: SEQUENCE; Schema: forms; Owner: -
--

CREATE SEQUENCE forms.checklist_resposta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_resposta_id_seq; Type: SEQUENCE OWNED BY; Schema: forms; Owner: -
--

ALTER SEQUENCE forms.checklist_resposta_id_seq OWNED BY forms.checklist_resposta.id;


--
-- Name: checklist_sala_config; Type: TABLE; Schema: forms; Owner: -
--

CREATE TABLE forms.checklist_sala_config (
    id integer NOT NULL,
    sala_id smallint NOT NULL,
    item_tipo_id smallint NOT NULL,
    ordem smallint DEFAULT 1 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now(),
    atualizado_em timestamp with time zone DEFAULT now()
);


--
-- Name: checklist_sala_config_id_seq; Type: SEQUENCE; Schema: forms; Owner: -
--

CREATE SEQUENCE forms.checklist_sala_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_sala_config_id_seq; Type: SEQUENCE OWNED BY; Schema: forms; Owner: -
--

ALTER SEQUENCE forms.checklist_sala_config_id_seq OWNED BY forms.checklist_sala_config.id;


--
-- Name: registro_anormalidade; Type: TABLE; Schema: operacao; Owner: -
--

CREATE TABLE operacao.registro_anormalidade (
    id bigint NOT NULL,
    registro_id bigint NOT NULL,
    data date NOT NULL,
    sala_id smallint NOT NULL,
    nome_evento text NOT NULL,
    hora_inicio_anormalidade time without time zone NOT NULL,
    descricao_anormalidade text NOT NULL,
    houve_prejuizo boolean NOT NULL,
    descricao_prejuizo text,
    houve_reclamacao boolean NOT NULL,
    autores_conteudo_reclamacao text,
    acionou_manutencao boolean NOT NULL,
    hora_acionamento_manutencao time without time zone,
    resolvida_pelo_operador boolean NOT NULL,
    procedimentos_adotados text,
    data_solucao date,
    hora_solucao time without time zone,
    responsavel_evento text NOT NULL,
    criado_por uuid NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_por uuid,
    entrada_id bigint,
    CONSTRAINT ck_datas_coerentes CHECK (((data_solucao IS NULL) OR ((data_solucao > data) OR ((data_solucao = data) AND ((hora_solucao IS NULL) OR (hora_solucao >= hora_inicio_anormalidade)))))),
    CONSTRAINT ck_manutencao_hora CHECK (((NOT acionou_manutencao) OR (hora_acionamento_manutencao IS NOT NULL))),
    CONSTRAINT ck_prejuizo_desc CHECK (((NOT houve_prejuizo) OR (descricao_prejuizo IS NOT NULL))),
    CONSTRAINT ck_reclamacao_desc CHECK (((NOT houve_reclamacao) OR (autores_conteudo_reclamacao IS NOT NULL)))
);


--
-- Name: TABLE registro_anormalidade; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON TABLE operacao.registro_anormalidade IS 'Registros de anormalidades ocorridas durante a operação de áudio.';


--
-- Name: COLUMN registro_anormalidade.nome_evento; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade.nome_evento IS 'Cópia do nome do evento do registro pai para manter o histórico.';


--
-- Name: COLUMN registro_anormalidade.responsavel_evento; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade.responsavel_evento IS 'Nome do responsável da comissão/mesa/evento informado no momento do registro.';


--
-- Name: registro_anormalidade_admin; Type: TABLE; Schema: operacao; Owner: -
--

CREATE TABLE operacao.registro_anormalidade_admin (
    registro_anormalidade_id bigint NOT NULL,
    observacao_supervisor text,
    observacao_chefe text,
    criado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_por uuid,
    atualizado_em timestamp with time zone
);


--
-- Name: TABLE registro_anormalidade_admin; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON TABLE operacao.registro_anormalidade_admin IS 'Observações de supervisor e chefe de serviço para os registros de anormalidade.';


--
-- Name: COLUMN registro_anormalidade_admin.registro_anormalidade_id; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.registro_anormalidade_id IS 'FK para operacao.registro_anormalidade.id (1:1 com o registro de anormalidade).';


--
-- Name: COLUMN registro_anormalidade_admin.observacao_supervisor; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.observacao_supervisor IS 'Observações lançadas pelo supervisor autorizado.';


--
-- Name: COLUMN registro_anormalidade_admin.observacao_chefe; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.observacao_chefe IS 'Observações lançadas pelo chefe de serviço (evandrop).';


--
-- Name: COLUMN registro_anormalidade_admin.criado_por; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.criado_por IS 'ID do administrador (pessoa.administrador.id) que criou o registro de observação.';


--
-- Name: COLUMN registro_anormalidade_admin.criado_em; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.criado_em IS 'Data/hora (timezone-aware) em que o registro de observação foi criado.';


--
-- Name: COLUMN registro_anormalidade_admin.atualizado_por; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.atualizado_por IS 'ID do administrador (pessoa.administrador.id) que lançou a segunda observação (atualização).';


--
-- Name: COLUMN registro_anormalidade_admin.atualizado_em; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_anormalidade_admin.atualizado_em IS 'Data/hora em que a segunda observação foi registrada.';


--
-- Name: registro_anormalidade_id_seq; Type: SEQUENCE; Schema: operacao; Owner: -
--

CREATE SEQUENCE operacao.registro_anormalidade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registro_anormalidade_id_seq; Type: SEQUENCE OWNED BY; Schema: operacao; Owner: -
--

ALTER SEQUENCE operacao.registro_anormalidade_id_seq OWNED BY operacao.registro_anormalidade.id;


--
-- Name: registro_operacao_audio; Type: TABLE; Schema: operacao; Owner: -
--

CREATE TABLE operacao.registro_operacao_audio (
    id bigint NOT NULL,
    data date NOT NULL,
    sala_id smallint NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid,
    em_aberto boolean DEFAULT true NOT NULL,
    fechado_em timestamp with time zone,
    fechado_por uuid,
    checklist_do_dia_id bigint,
    checklist_do_dia_ok boolean
);


--
-- Name: TABLE registro_operacao_audio; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON TABLE operacao.registro_operacao_audio IS 'Registro de Operação de Áudio por sessão/evento.';


--
-- Name: COLUMN registro_operacao_audio.sala_id; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_operacao_audio.sala_id IS 'FK para cadastro.sala.';


--
-- Name: registro_operacao_audio_id_seq; Type: SEQUENCE; Schema: operacao; Owner: -
--

CREATE SEQUENCE operacao.registro_operacao_audio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registro_operacao_audio_id_seq; Type: SEQUENCE OWNED BY; Schema: operacao; Owner: -
--

ALTER SEQUENCE operacao.registro_operacao_audio_id_seq OWNED BY operacao.registro_operacao_audio.id;


--
-- Name: registro_operacao_operador; Type: TABLE; Schema: operacao; Owner: -
--

CREATE TABLE operacao.registro_operacao_operador (
    id bigint NOT NULL,
    registro_id bigint NOT NULL,
    operador_id uuid NOT NULL,
    ordem smallint NOT NULL,
    hora_entrada time without time zone,
    hora_saida time without time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid,
    atualizado_por uuid,
    seq smallint DEFAULT 1 NOT NULL,
    usb_01 text,
    usb_02 text,
    observacoes text,
    houve_anormalidade boolean,
    nome_evento text,
    horario_pauta time without time zone,
    horario_inicio time without time zone,
    horario_termino time without time zone,
    tipo_evento text DEFAULT 'operacao'::text NOT NULL,
    comissao_id bigint,
    responsavel_evento text,
    editado boolean DEFAULT false NOT NULL,
    observacoes_editado boolean DEFAULT false NOT NULL,
    nome_evento_editado boolean DEFAULT false NOT NULL,
    responsavel_evento_editado boolean DEFAULT false NOT NULL,
    horario_pauta_editado boolean DEFAULT false NOT NULL,
    horario_inicio_editado boolean DEFAULT false NOT NULL,
    horario_termino_editado boolean DEFAULT false NOT NULL,
    usb_01_editado boolean DEFAULT false NOT NULL,
    usb_02_editado boolean DEFAULT false NOT NULL,
    comissao_editado boolean DEFAULT false NOT NULL,
    sala_editado boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_horas_coerentes CHECK (((hora_saida IS NULL) OR (hora_saida > hora_entrada))),
    CONSTRAINT ck_regopop_ordem_pos CHECK ((ordem >= 1)),
    CONSTRAINT ck_regopop_seq_1_2 CHECK ((seq = ANY (ARRAY[1, 2]))),
    CONSTRAINT ck_regopop_tipo_evento CHECK ((tipo_evento = ANY (ARRAY['operacao'::text, 'cessao'::text, 'outros'::text])))
);


--
-- Name: TABLE registro_operacao_operador; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON TABLE operacao.registro_operacao_operador IS 'Escala de operadores por registro de operação de áudio.';


--
-- Name: COLUMN registro_operacao_operador.ordem; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_operacao_operador.ordem IS 'Ordem de atuação (1, 2, 3...).';


--
-- Name: COLUMN registro_operacao_operador.hora_saida; Type: COMMENT; Schema: operacao; Owner: -
--

COMMENT ON COLUMN operacao.registro_operacao_operador.hora_saida IS 'Fim do turno; pode ser NULL no último operador.';


--
-- Name: registro_operacao_operador_historico; Type: TABLE; Schema: operacao; Owner: -
--

CREATE TABLE operacao.registro_operacao_operador_historico (
    id bigint NOT NULL,
    entrada_id bigint NOT NULL,
    snapshot jsonb NOT NULL,
    editado_por uuid,
    editado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: registro_operacao_operador_historico_id_seq; Type: SEQUENCE; Schema: operacao; Owner: -
--

CREATE SEQUENCE operacao.registro_operacao_operador_historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registro_operacao_operador_historico_id_seq; Type: SEQUENCE OWNED BY; Schema: operacao; Owner: -
--

ALTER SEQUENCE operacao.registro_operacao_operador_historico_id_seq OWNED BY operacao.registro_operacao_operador_historico.id;


--
-- Name: registro_operacao_operador_id_seq; Type: SEQUENCE; Schema: operacao; Owner: -
--

CREATE SEQUENCE operacao.registro_operacao_operador_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: registro_operacao_operador_id_seq; Type: SEQUENCE OWNED BY; Schema: operacao; Owner: -
--

ALTER SEQUENCE operacao.registro_operacao_operador_id_seq OWNED BY operacao.registro_operacao_operador.id;


--
-- Name: administrador; Type: TABLE; Schema: pessoa; Owner: -
--

CREATE TABLE pessoa.administrador (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_completo text NOT NULL,
    email pessoa.citext NOT NULL,
    username pessoa.citext NOT NULL,
    password_hash text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE administrador; Type: COMMENT; Schema: pessoa; Owner: -
--

COMMENT ON TABLE pessoa.administrador IS 'Contas administrativas com acesso diferenciado.';


--
-- Name: COLUMN administrador.password_hash; Type: COMMENT; Schema: pessoa; Owner: -
--

COMMENT ON COLUMN pessoa.administrador.password_hash IS 'Senha armazenada como hash (bcrypt via crypt()).';


--
-- Name: administrador_s; Type: TABLE; Schema: pessoa; Owner: -
--

CREATE TABLE pessoa.administrador_s (
    id bigint NOT NULL,
    nome_completo text NOT NULL,
    email text NOT NULL,
    username text NOT NULL,
    senha text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: administrador_s_id_seq; Type: SEQUENCE; Schema: pessoa; Owner: -
--

CREATE SEQUENCE pessoa.administrador_s_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: administrador_s_id_seq; Type: SEQUENCE OWNED BY; Schema: pessoa; Owner: -
--

ALTER SEQUENCE pessoa.administrador_s_id_seq OWNED BY pessoa.administrador_s.id;


--
-- Name: auth_sessions; Type: TABLE; Schema: pessoa; Owner: -
--

CREATE TABLE pessoa.auth_sessions (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    refresh_token_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_activity timestamp with time zone DEFAULT now() NOT NULL,
    revoked boolean DEFAULT false NOT NULL
);


--
-- Name: auth_sessions_id_seq; Type: SEQUENCE; Schema: pessoa; Owner: -
--

CREATE SEQUENCE pessoa.auth_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: pessoa; Owner: -
--

ALTER SEQUENCE pessoa.auth_sessions_id_seq OWNED BY pessoa.auth_sessions.id;


--
-- Name: operador; Type: TABLE; Schema: pessoa; Owner: -
--

CREATE TABLE pessoa.operador (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_completo text NOT NULL,
    email pessoa.citext NOT NULL,
    username pessoa.citext NOT NULL,
    foto_url text,
    password_hash text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    nome_exibicao text NOT NULL,
    CONSTRAINT operador_nome_exibicao_not_blank CHECK ((length(btrim(nome_exibicao)) > 0))
);


--
-- Name: operador_s; Type: TABLE; Schema: pessoa; Owner: -
--

CREATE TABLE pessoa.operador_s (
    id bigint NOT NULL,
    nome_completo text NOT NULL,
    email text NOT NULL,
    username text NOT NULL,
    senha text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: operador_s_id_seq; Type: SEQUENCE; Schema: pessoa; Owner: -
--

CREATE SEQUENCE pessoa.operador_s_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operador_s_id_seq; Type: SEQUENCE OWNED BY; Schema: pessoa; Owner: -
--

ALTER SEQUENCE pessoa.operador_s_id_seq OWNED BY pessoa.operador_s.id;


--
-- Name: annotation_tag_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.annotation_tag_entity (
    id character varying(16) NOT NULL,
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_identity (
    "userId" uuid,
    "providerId" character varying(64) NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_provider_sync_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_provider_sync_history (
    id integer NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "runMode" text NOT NULL,
    status text NOT NULL,
    "startedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "endedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scanned integer NOT NULL,
    created integer NOT NULL,
    updated integer NOT NULL,
    disabled integer NOT NULL,
    error text
);


--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_provider_sync_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNED BY public.auth_provider_sync_history.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chat_hub_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_hub_messages (
    id uuid NOT NULL,
    "sessionId" uuid NOT NULL,
    "previousMessageId" uuid,
    "revisionOfMessageId" uuid,
    "retryOfMessageId" uuid,
    type character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    content text NOT NULL,
    provider character varying(16),
    model character varying(64),
    "workflowId" character varying(36),
    "executionId" integer,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    status character varying(16) DEFAULT 'success'::character varying NOT NULL
);


--
-- Name: COLUMN chat_hub_messages.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_messages.type IS 'ChatHubMessageType enum: "human", "ai", "system", "tool", "generic"';


--
-- Name: COLUMN chat_hub_messages.provider; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_messages.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_messages.model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_messages.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_messages.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_messages.status IS 'ChatHubMessageStatus enum, eg. "success", "error", "running", "cancelled"';


--
-- Name: chat_hub_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_hub_sessions (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    "ownerId" uuid NOT NULL,
    "lastMessageAt" timestamp(3) with time zone,
    "credentialId" character varying(36),
    provider character varying(16),
    model character varying(64),
    "workflowId" character varying(36),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: COLUMN chat_hub_sessions.provider; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_sessions.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_sessions.model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chat_hub_sessions.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: credentials_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credentials_entity (
    name character varying(128) NOT NULL,
    data text NOT NULL,
    type character varying(128) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL,
    "isManaged" boolean DEFAULT false NOT NULL
);


--
-- Name: data_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_table (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: data_table_column; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_table_column (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(32) NOT NULL,
    index integer NOT NULL,
    "dataTableId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: COLUMN data_table_column.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_table_column.type IS 'Expected: string, number, boolean, or date (not enforced as a constraint)';


--
-- Name: COLUMN data_table_column.index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_table_column.index IS 'Column order, starting from 0 (0 = first column)';


--
-- Name: data_table_user_5EBBvwJHpAKSfA9V; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."data_table_user_5EBBvwJHpAKSfA9V" (
    id integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: data_table_user_5EBBvwJHpAKSfA9V_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."data_table_user_5EBBvwJHpAKSfA9V" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."data_table_user_5EBBvwJHpAKSfA9V_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


--
-- Name: event_destinations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_destinations (
    id uuid NOT NULL,
    destination jsonb NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: execution_annotation_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_annotation_tags (
    "annotationId" integer NOT NULL,
    "tagId" character varying(24) NOT NULL
);


--
-- Name: execution_annotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_annotations (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    vote character varying(6),
    note text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: execution_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.execution_annotations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: execution_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.execution_annotations_id_seq OWNED BY public.execution_annotations.id;


--
-- Name: execution_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_data (
    "executionId" integer NOT NULL,
    "workflowData" json NOT NULL,
    data text NOT NULL
);


--
-- Name: execution_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_entity (
    id integer NOT NULL,
    finished boolean NOT NULL,
    mode character varying NOT NULL,
    "retryOf" character varying,
    "retrySuccessId" character varying,
    "startedAt" timestamp(3) with time zone,
    "stoppedAt" timestamp(3) with time zone,
    "waitTill" timestamp(3) with time zone,
    status character varying NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "deletedAt" timestamp(3) with time zone,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: execution_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.execution_entity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: execution_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.execution_entity_id_seq OWNED BY public.execution_entity.id;


--
-- Name: execution_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.execution_metadata (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.execution_metadata_temp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNED BY public.execution_metadata.id;


--
-- Name: folder; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folder (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "parentFolderId" character varying(36),
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: folder_tag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folder_tag (
    "folderId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


--
-- Name: insights_by_period; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insights_by_period (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "periodUnit" integer NOT NULL,
    "periodStart" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: COLUMN insights_by_period.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.insights_by_period.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: COLUMN insights_by_period."periodUnit"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.insights_by_period."periodUnit" IS '0: hour, 1: day, 2: week';


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.insights_by_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_by_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insights_metadata (
    "metaId" integer NOT NULL,
    "workflowId" character varying(16),
    "projectId" character varying(36),
    "workflowName" character varying(128) NOT NULL,
    "projectName" character varying(255) NOT NULL
);


--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.insights_metadata ALTER COLUMN "metaId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."insights_metadata_metaId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_raw; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insights_raw (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "timestamp" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: COLUMN insights_raw.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.insights_raw.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: insights_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.insights_raw ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: installed_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installed_nodes (
    name character varying(200) NOT NULL,
    type character varying(200) NOT NULL,
    "latestVersion" integer DEFAULT 1 NOT NULL,
    package character varying(241) NOT NULL
);


--
-- Name: installed_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installed_packages (
    "packageName" character varying(214) NOT NULL,
    "installedVersion" character varying(50) NOT NULL,
    "authorName" character varying(70),
    "authorEmail" character varying(70),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: invalid_auth_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invalid_auth_token (
    token character varying(512) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    "timestamp" bigint NOT NULL,
    name character varying NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: processed_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.processed_data (
    "workflowId" character varying(36) NOT NULL,
    context character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    value text NOT NULL
);


--
-- Name: project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project (
    id character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    description character varying(512)
);


--
-- Name: project_relation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_relation (
    "projectId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    role character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text,
    "roleType" text,
    "systemRole" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: COLUMN role.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role.slug IS 'Unique identifier of the role for example: "global:owner"';


--
-- Name: COLUMN role."displayName"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN role.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role.description IS 'Text describing the scope in more detail of users';


--
-- Name: COLUMN role."roleType"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role."roleType" IS 'Type of the role, e.g., global, project, or workflow';


--
-- Name: COLUMN role."systemRole"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role."systemRole" IS 'Indicates if the role is managed by the system and cannot be edited';


--
-- Name: role_scope; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_scope (
    "roleSlug" character varying(128) NOT NULL,
    "scopeSlug" character varying(128) NOT NULL
);


--
-- Name: scope; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scope (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text
);


--
-- Name: COLUMN scope.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scope.slug IS 'Unique identifier of the scope for example: "project:create"';


--
-- Name: COLUMN scope."displayName"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scope."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN scope.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scope.description IS 'Text describing the scope in more detail of users';


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    "loadOnStartup" boolean DEFAULT false NOT NULL
);


--
-- Name: shared_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_credentials (
    "credentialsId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: shared_workflow; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_workflow (
    "workflowId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: tag_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_entity (
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL
);


--
-- Name: test_case_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_case_execution (
    id character varying(36) NOT NULL,
    "testRunId" character varying(36) NOT NULL,
    "executionId" integer,
    status character varying NOT NULL,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    "errorCode" character varying,
    "errorDetails" json,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    inputs json,
    outputs json
);


--
-- Name: test_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_run (
    id character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    status character varying NOT NULL,
    "errorCode" character varying,
    "errorDetails" json,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."user" (
    id uuid DEFAULT uuid_in((OVERLAY(OVERLAY(md5((((random())::text || ':'::text) || (clock_timestamp())::text)) PLACING '4'::text FROM 13) PLACING to_hex((floor(((random() * (((11 - 8) + 1))::double precision) + (8)::double precision)))::integer) FROM 17))::cstring) NOT NULL,
    email character varying(255),
    "firstName" character varying(32),
    "lastName" character varying(32),
    password character varying(255),
    "personalizationAnswers" json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    disabled boolean DEFAULT false NOT NULL,
    "mfaEnabled" boolean DEFAULT false NOT NULL,
    "mfaSecret" text,
    "mfaRecoveryCodes" text,
    "lastActiveAt" date,
    "roleSlug" character varying(128) DEFAULT 'global:member'::character varying NOT NULL
);


--
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_api_keys (
    id character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    label character varying(100) NOT NULL,
    "apiKey" character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    scopes json,
    audience character varying DEFAULT 'public-api'::character varying NOT NULL
);


--
-- Name: variables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variables (
    key character varying(50) NOT NULL,
    type character varying(50) DEFAULT 'string'::character varying NOT NULL,
    value character varying(255),
    id character varying(36) NOT NULL,
    "projectId" character varying(36)
);


--
-- Name: webhook_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_entity (
    "webhookPath" character varying NOT NULL,
    method character varying NOT NULL,
    node character varying NOT NULL,
    "webhookId" character varying,
    "pathLength" integer,
    "workflowId" character varying(36) NOT NULL
);


--
-- Name: workflow_dependency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_dependency (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "workflowVersionId" integer NOT NULL,
    "dependencyType" character varying(32) NOT NULL,
    "dependencyKey" character varying(255) NOT NULL,
    "dependencyInfo" character varying(255),
    "indexVersionId" smallint DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


--
-- Name: COLUMN workflow_dependency."workflowVersionId"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.workflow_dependency."workflowVersionId" IS 'Version of the workflow';


--
-- Name: COLUMN workflow_dependency."dependencyType"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.workflow_dependency."dependencyType" IS 'Type of dependency: "credential", "nodeType", "webhookPath", or "workflowCall"';


--
-- Name: COLUMN workflow_dependency."dependencyKey"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.workflow_dependency."dependencyKey" IS 'ID or name of the dependency';


--
-- Name: COLUMN workflow_dependency."dependencyInfo"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.workflow_dependency."dependencyInfo" IS 'Additional info about the dependency, interpreted based on type';


--
-- Name: COLUMN workflow_dependency."indexVersionId"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.workflow_dependency."indexVersionId" IS 'Version of the index structure';


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.workflow_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_entity (
    name character varying(128) NOT NULL,
    active boolean NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    "staticData" json,
    "pinData" json,
    "versionId" character(36),
    "triggerCount" integer DEFAULT 0 NOT NULL,
    id character varying(36) NOT NULL,
    meta json,
    "parentFolderId" character varying(36) DEFAULT NULL::character varying,
    "isArchived" boolean DEFAULT false NOT NULL
);


--
-- Name: workflow_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_history (
    "versionId" character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    authors character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL
);


--
-- Name: workflow_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_statistics (
    count integer DEFAULT 0,
    "latestEvent" timestamp(3) with time zone,
    name character varying(128) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "rootCount" integer DEFAULT 0
);


--
-- Name: workflows_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflows_tags (
    "workflowId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


--
-- Name: comissao id; Type: DEFAULT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.comissao ALTER COLUMN id SET DEFAULT nextval('cadastro.comissao_id_seq'::regclass);


--
-- Name: sala id; Type: DEFAULT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.sala ALTER COLUMN id SET DEFAULT nextval('cadastro.sala_id_seq'::regclass);


--
-- Name: checklist id; Type: DEFAULT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist ALTER COLUMN id SET DEFAULT nextval('forms.checklist_id_seq'::regclass);


--
-- Name: checklist_historico id; Type: DEFAULT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_historico ALTER COLUMN id SET DEFAULT nextval('forms.checklist_historico_id_seq'::regclass);


--
-- Name: checklist_item_tipo id; Type: DEFAULT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_item_tipo ALTER COLUMN id SET DEFAULT nextval('forms.checklist_item_tipo_id_seq'::regclass);


--
-- Name: checklist_resposta id; Type: DEFAULT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_resposta ALTER COLUMN id SET DEFAULT nextval('forms.checklist_resposta_id_seq'::regclass);


--
-- Name: checklist_sala_config id; Type: DEFAULT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_sala_config ALTER COLUMN id SET DEFAULT nextval('forms.checklist_sala_config_id_seq'::regclass);


--
-- Name: registro_anormalidade id; Type: DEFAULT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade ALTER COLUMN id SET DEFAULT nextval('operacao.registro_anormalidade_id_seq'::regclass);


--
-- Name: registro_operacao_audio id; Type: DEFAULT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_audio ALTER COLUMN id SET DEFAULT nextval('operacao.registro_operacao_audio_id_seq'::regclass);


--
-- Name: registro_operacao_operador id; Type: DEFAULT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador ALTER COLUMN id SET DEFAULT nextval('operacao.registro_operacao_operador_id_seq'::regclass);


--
-- Name: registro_operacao_operador_historico id; Type: DEFAULT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador_historico ALTER COLUMN id SET DEFAULT nextval('operacao.registro_operacao_operador_historico_id_seq'::regclass);


--
-- Name: administrador_s id; Type: DEFAULT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador_s ALTER COLUMN id SET DEFAULT nextval('pessoa.administrador_s_id_seq'::regclass);


--
-- Name: auth_sessions id; Type: DEFAULT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.auth_sessions ALTER COLUMN id SET DEFAULT nextval('pessoa.auth_sessions_id_seq'::regclass);


--
-- Name: operador_s id; Type: DEFAULT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador_s ALTER COLUMN id SET DEFAULT nextval('pessoa.operador_s_id_seq'::regclass);


--
-- Name: auth_provider_sync_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_provider_sync_history ALTER COLUMN id SET DEFAULT nextval('public.auth_provider_sync_history_id_seq'::regclass);


--
-- Name: execution_annotations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotations ALTER COLUMN id SET DEFAULT nextval('public.execution_annotations_id_seq'::regclass);


--
-- Name: execution_entity id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_entity ALTER COLUMN id SET DEFAULT nextval('public.execution_entity_id_seq'::regclass);


--
-- Name: execution_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_metadata ALTER COLUMN id SET DEFAULT nextval('public.execution_metadata_temp_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Data for Name: comissao; Type: TABLE DATA; Schema: cadastro; Owner: -
--

COPY cadastro.comissao (id, nome, ativo, ordem, criado_em, criado_por, atualizado_em, atualizado_por) FROM stdin;
1	CAE - Comissão de Assuntos Econômicos	t	1	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
2	CAS - Comissão de Assuntos Sociais	t	2	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
3	CCDD - Comissão de Comunicação e Direito Digital	t	3	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
4	CCJ - Comissão de Constituição, Justiça e Cidadania	t	4	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
5	CCT - Comissão de Ciência, Tecnologia, Inovação e Informática	t	5	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
6	CDD - Comissão de Defesa da Democracia	t	6	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
7	CDH - Comissão de Direitos Humanos e Legislação Participativa	t	7	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
8	CDIR - Comissão Diretora do Senado Federal	t	8	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
9	CDR - Comissão de Desenvolvimento Regional e Turismo	t	9	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
10	CE - Comissão de Educação e Cultura	t	10	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
11	CEsp - Comissão de Esporte	t	11	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
12	CI - Comissão de Serviços de Infraestrutura	t	12	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
13	CMA - Comissão de Meio Ambiente	t	13	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
14	CRA - Comissão de Agricultura e Reforma Agrária	t	14	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
15	CRE - Comissão de Relações Exteriores e Defesa Nacional	t	15	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
16	CSP - Comissão de Segurança Pública	t	16	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
17	CTFC - Comissão de Transparência, Governança, Fiscalização e Controle e Defesa do Consumidor	t	17	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
18	CCAI - Comissão Mista de Controle das Atividades de Inteligência	t	18	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
19	CMCVM - Comissão Permanente Mista de Combate à Violência contra a Mulher	t	19	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
20	CMMC - Comissão Mista Permanente sobre Mudanças Climáticas	t	20	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
21	CMMIR - Comissão Mista Permanente sobre Migrações Internacionais e Refugiados	t	21	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
22	CMO - Comissão Mista de Planos, Orçamentos Públicos e Fiscalização	t	22	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
23	CPI - Comissão Parlamentar de Inquérito	t	23	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
24	CPMI - Comissão Parlamentar Mista de Inquérito	t	24	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
25	CT - Comissão Temporária	t	25	2025-12-02 16:32:20.474634+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
26	cessão - Cessão de Sala	t	26	2025-12-17 14:48:41.583616+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
27	outros - Outros Eventos	t	27	2025-12-17 14:48:41.583616+00	1391b9e1-b006-4d9c-8c63-e39421079ca2	2025-12-17 15:07:32.863892+00	1391b9e1-b006-4d9c-8c63-e39421079ca2
\.


--
-- Data for Name: sala; Type: TABLE DATA; Schema: cadastro; Owner: -
--

COPY cadastro.sala (id, nome, ativo, criado_em, atualizado_em, ordem) FROM stdin;
1	Auditório Petrônio Portella	t	2025-10-30 18:59:51.317774+00	2025-12-18 14:00:53.431529+00	1
2	Plenário	t	2025-10-30 18:59:51.317774+00	2025-12-18 14:00:53.431529+00	2
3	Plenário 02	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	3
4	Plenário 03	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	4
5	Plenário 06	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	5
6	Plenário 07	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	6
7	Plenário 09	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	7
8	Plenário 13	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	8
9	Plenário 15	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	9
10	Plenário 19	t	2025-10-30 18:59:51.317774+00	2026-02-24 17:57:52.542248+00	10
\.


--
-- Data for Name: checklist; Type: TABLE DATA; Schema: forms; Owner: -
--

COPY forms.checklist (id, data_operacao, sala_id, turno, hora_inicio_testes, hora_termino_testes, observacoes, criado_em, atualizado_em, usb_01, usb_02, criado_por, atualizado_por, editado, observacoes_editado) FROM stdin;
1	2026-03-02	8	Matutino	07:47:46	07:48:46	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	\N	\N	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	f
2	2026-03-02	10	Matutino	10:53:14	11:04:44	Formulado preenchido juntamente com o chefe Douglas	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	\N	\N	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	f
3	2026-03-02	4	Matutino	11:04:31	11:05:32	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	\N	\N	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	f
4	2026-03-02	3	Matutino	11:29:40	11:30:44	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	\N	\N	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	f
5	2026-03-02	9	Vespertino	14:46:01	14:48:14	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f	f
6	2026-03-02	4	Vespertino	15:13:16	15:22:39	Quando acionado os 60 segundos no Zoom 1 o áudio não esta saindo na cabine e também na sala. Quando acionado no Zoom 2 esta tudo normal.	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	\N	\N	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	f	f
7	2026-03-03	3	Matutino	07:07:38	07:08:10	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	\N	\N	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	f
9	2026-03-03	9	Matutino	06:51:29	07:28:07	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	\N	\N	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	f
10	2026-03-03	8	Matutino	07:39:32	07:53:17	Durante teste ja finalizando, queda total de energia as 7:47h	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	\N	\N	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	f
11	2026-03-03	4	Matutino	08:05:15	08:13:12	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	\N	\N	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	f
12	2026-03-03	7	Matutino	08:27:03	08:48:06	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	\N	\N	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	f
13	2026-03-03	5	Matutino	08:57:14	08:59:21	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	\N	\N	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	f	f
14	2026-03-03	6	Matutino	09:36:24	09:40:30	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	\N	\N	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	f	f
15	2026-03-03	5	Vespertino	13:10:05	13:11:56	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	\N	\N	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	f	f
16	2026-03-03	3	Vespertino	13:12:21	13:13:46	Todos os testes realizados!	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f	f
8	2026-03-03	10	Matutino	06:59:23	07:16:14	A bateria reserva do microfone sem fio ainda se encontra em manutenção com os técnicos.\n\nObservação: a segunda bateria do microfone sem fio já foi consertadas e já foi devolvida.	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	\N	\N	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	t	t
17	2026-03-03	6	Vespertino	13:31:26	13:35:47	Relatório criado após verificação completa, pois o audioarchitect do pc 1 precisou ser reinstalado.	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	\N	\N	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	f	f
18	2026-03-03	7	Vespertino	13:36:08	13:37:24	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	\N	\N	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	f	f
19	2026-03-03	8	Vespertino	15:48:16	15:56:23	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	\N	\N	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	f	f
20	2026-03-04	10	Matutino	06:56:19	07:08:29	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	\N	\N	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	f
21	2026-03-04	3	Matutino	06:56:22	07:12:44	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	\N	\N	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	f
22	2026-03-04	9	Matutino	07:24:02	07:46:08	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	\N	\N	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	f
23	2026-03-04	8	Matutino	07:42:58	07:48:10	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	\N	\N	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	f
24	2026-03-04	7	Matutino	08:08:09	08:09:20	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	\N	\N	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	f
25	2026-03-04	4	Matutino	08:12:30	08:19:10	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	\N	\N	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	f
26	2026-03-04	6	Matutino	08:44:15	08:49:44	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	\N	\N	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	f	f
27	2026-03-04	5	Matutino	09:10:35	09:27:53	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	\N	\N	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	f	f
28	2026-03-04	6	Matutino	12:51:31	13:01:21	Testes realizados com zoom logado já no ID da reunião da CRA, agendada para 14 horas.	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	\N	\N	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	f	f
29	2026-03-04	3	Vespertino	13:15:09	13:50:57	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	\N	\N	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	f	f
31	2026-03-04	5	Vespertino	14:15:44	14:17:19	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	\N	\N	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	f	f
32	2026-03-04	8	Vespertino	14:31:07	14:38:03	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	\N	\N	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	f	f
45	2026-03-05	3	Vespertino	13:42:26	14:37:09	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	\N	\N	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	f	f
30	2026-03-04	9	Vespertino	13:47:18	14:10:17	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	t	t
33	2026-03-04	7	Vespertino	15:41:47	15:46:01	Testes feitos com a dinâmica  diferente  porque estava ensinando a Thalita.	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	\N	\N	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	f	f
34	2026-03-05	3	Matutino	06:55:23	07:08:06	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	\N	\N	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	f
35	2026-03-05	10	Matutino	07:14:23	07:16:24	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	\N	\N	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	f
36	2026-03-05	9	Matutino	07:04:47	07:30:52	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	\N	\N	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	f
37	2026-03-05	8	Matutino	07:28:37	07:44:33	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	\N	\N	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	f
38	2026-03-05	4	Matutino	07:51:07	08:25:19	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	\N	\N	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	f
39	2026-03-05	6	Matutino	08:23:02	08:30:27	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	\N	\N	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	f	f
40	2026-03-05	5	Matutino	07:59:09	08:33:06	Nenhuma!	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	\N	\N	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	f	f
41	2026-03-05	7	Matutino	08:17:32	08:40:55	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	\N	\N	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	f
42	2026-03-05	7	Vespertino	13:28:33	13:38:46	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	\N	\N	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	f	f
43	2026-03-05	6	Vespertino	13:20:01	13:50:32	Sem observação	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	\N	\N	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	f	f
44	2026-03-05	8	Vespertino	14:11:35	14:19:30	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	\N	\N	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	f	f
46	2026-03-05	9	Vespertino	14:13:15	14:41:46	Todos os testes realizados!	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f	f
47	2026-03-05	4	Vespertino	14:45:21	15:17:57	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	\N	\N	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	f	f
48	2026-03-06	9	Matutino	06:43:14	07:10:04	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	\N	\N	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	f
49	2026-03-06	7	Matutino	08:41:11	08:53:03	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	\N	\N	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	f
50	2026-03-06	3	Vespertino	13:33:59	13:39:35	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	\N	\N	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	f	f
51	2026-03-06	10	Vespertino	14:31:35	14:51:44	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	\N	\N	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	f	f
52	2026-03-06	5	Vespertino	15:20:38	15:35:25	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f	f
53	2026-03-09	6	Matutino	06:52:11	07:17:41	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	\N	\N	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	f
54	2026-03-09	5	Matutino	07:07:49	07:20:46	Apenas uma bateria para microfone sem fio	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	\N	\N	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	f
55	2026-03-09	3	Matutino	06:57:51	07:25:20	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	\N	\N	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	f
56	2026-03-09	9	Matutino	07:54:01	08:25:44	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	\N	\N	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	f
57	2026-03-09	10	Matutino	08:05:22	08:38:33	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	\N	\N	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	f
58	2026-03-09	7	Matutino	08:15:52	08:38:24	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	\N	\N	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	f
59	2026-03-09	4	Matutino	08:27:30	08:41:50	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	\N	\N	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	f	f
60	2026-03-09	8	Matutino	09:57:31	10:19:25	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	\N	\N	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	f	f
61	2026-03-09	6	Vespertino	13:38:14	13:42:22	2 observações: mic. A4(necessita lubrificação),e vip, sem áudio local.	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	\N	\N	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	f	f
62	2026-03-09	8	Vespertino	13:31:39	13:47:58	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	\N	\N	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	f	f
63	2026-03-09	7	Vespertino	13:38:33	14:00:19	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	\N	\N	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	f	f
64	2026-03-09	3	Vespertino	13:33:49	14:03:21	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	\N	\N	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	f	f
65	2026-03-09	9	Vespertino	13:49:43	14:11:47	Testes Concluídos.	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	\N	\N	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f	f
66	2026-03-09	4	Vespertino	14:12:49	14:23:36	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	\N	\N	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	f	f
\.


--
-- Data for Name: checklist_historico; Type: TABLE DATA; Schema: forms; Owner: -
--

COPY forms.checklist_historico (id, checklist_id, snapshot, editado_por, editado_em) FROM stdin;
2	30	{"itens": [{"status": "Ok", "resposta_id": 455, "valor_texto": null, "item_tipo_id": 2, "descricao_falha": null}, {"status": "Ok", "resposta_id": 456, "valor_texto": null, "item_tipo_id": 3, "descricao_falha": null}, {"status": "Ok", "resposta_id": 457, "valor_texto": null, "item_tipo_id": 4, "descricao_falha": null}, {"status": "Ok", "resposta_id": 458, "valor_texto": null, "item_tipo_id": 5, "descricao_falha": null}, {"status": "Ok", "resposta_id": 459, "valor_texto": null, "item_tipo_id": 6, "descricao_falha": null}, {"status": "Ok", "resposta_id": 460, "valor_texto": null, "item_tipo_id": 7, "descricao_falha": null}, {"status": "Ok", "resposta_id": 461, "valor_texto": null, "item_tipo_id": 9, "descricao_falha": null}, {"status": "Ok", "resposta_id": 462, "valor_texto": null, "item_tipo_id": 10, "descricao_falha": null}, {"status": "Ok", "resposta_id": 463, "valor_texto": "094", "item_tipo_id": 15, "descricao_falha": null}, {"status": "Ok", "resposta_id": 464, "valor_texto": "094", "item_tipo_id": 16, "descricao_falha": null}, {"status": "Ok", "resposta_id": 465, "valor_texto": null, "item_tipo_id": 29, "descricao_falha": null}, {"status": "Ok", "resposta_id": 466, "valor_texto": null, "item_tipo_id": 30, "descricao_falha": null}, {"status": "Ok", "resposta_id": 467, "valor_texto": null, "item_tipo_id": 31, "descricao_falha": null}, {"status": "Ok", "resposta_id": 468, "valor_texto": null, "item_tipo_id": 32, "descricao_falha": null}, {"status": "Ok", "resposta_id": 469, "valor_texto": null, "item_tipo_id": 33, "descricao_falha": null}, {"status": "Ok", "resposta_id": 470, "valor_texto": null, "item_tipo_id": 34, "descricao_falha": null}], "header": {"turno": "Vespertino", "usb_01": null, "usb_02": null, "sala_id": "3", "observacoes": "Todos os testes realizados.", "data_operacao": "2026-03-04", "hora_inicio_testes": "13:47:18", "hora_termino_testes": "14:10:17"}}	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	2026-03-04 18:02:01.112778+00
3	30	{"itens": [{"status": "Ok", "resposta_id": 465, "valor_texto": null, "item_tipo_id": 29, "descricao_falha": null}, {"status": "Ok", "resposta_id": 466, "valor_texto": null, "item_tipo_id": 30, "descricao_falha": null}, {"status": "Ok", "resposta_id": 467, "valor_texto": null, "item_tipo_id": 31, "descricao_falha": null}, {"status": "Ok", "resposta_id": 457, "valor_texto": null, "item_tipo_id": 4, "descricao_falha": null}, {"status": "Ok", "resposta_id": 468, "valor_texto": null, "item_tipo_id": 32, "descricao_falha": null}, {"status": "Ok", "resposta_id": 469, "valor_texto": null, "item_tipo_id": 33, "descricao_falha": null}, {"status": "Ok", "resposta_id": 470, "valor_texto": null, "item_tipo_id": 34, "descricao_falha": null}, {"status": "Ok", "resposta_id": 462, "valor_texto": null, "item_tipo_id": 10, "descricao_falha": null}, {"status": "Ok", "resposta_id": 461, "valor_texto": null, "item_tipo_id": 9, "descricao_falha": null}, {"status": "Ok", "resposta_id": 456, "valor_texto": null, "item_tipo_id": 3, "descricao_falha": null}, {"status": "Ok", "resposta_id": 459, "valor_texto": null, "item_tipo_id": 6, "descricao_falha": null}, {"status": "Ok", "resposta_id": 458, "valor_texto": null, "item_tipo_id": 5, "descricao_falha": null}, {"status": "Ok", "resposta_id": 460, "valor_texto": null, "item_tipo_id": 7, "descricao_falha": null}, {"status": "Ok", "resposta_id": 455, "valor_texto": null, "item_tipo_id": 2, "descricao_falha": null}, {"status": "Ok", "resposta_id": 463, "valor_texto": "094", "item_tipo_id": 15, "descricao_falha": null}, {"status": "Ok", "resposta_id": 464, "valor_texto": "094", "item_tipo_id": 16, "descricao_falha": null}], "header": {"turno": "Vespertino", "usb_01": null, "usb_02": null, "sala_id": "3", "observacoes": "Todos os testes realizados!", "data_operacao": "2026-03-04", "hora_inicio_testes": "13:47:18", "hora_termino_testes": "14:10:17"}}	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	2026-03-04 18:03:42.937564+00
4	30	{"itens": [{"status": "Ok", "resposta_id": 465, "valor_texto": null, "item_tipo_id": 29, "descricao_falha": null}, {"status": "Ok", "resposta_id": 466, "valor_texto": null, "item_tipo_id": 30, "descricao_falha": null}, {"status": "Ok", "resposta_id": 467, "valor_texto": null, "item_tipo_id": 31, "descricao_falha": null}, {"status": "Ok", "resposta_id": 457, "valor_texto": null, "item_tipo_id": 4, "descricao_falha": null}, {"status": "Ok", "resposta_id": 468, "valor_texto": null, "item_tipo_id": 32, "descricao_falha": null}, {"status": "Ok", "resposta_id": 469, "valor_texto": null, "item_tipo_id": 33, "descricao_falha": null}, {"status": "Ok", "resposta_id": 470, "valor_texto": null, "item_tipo_id": 34, "descricao_falha": null}, {"status": "Ok", "resposta_id": 462, "valor_texto": null, "item_tipo_id": 10, "descricao_falha": null}, {"status": "Ok", "resposta_id": 461, "valor_texto": null, "item_tipo_id": 9, "descricao_falha": null}, {"status": "Ok", "resposta_id": 456, "valor_texto": null, "item_tipo_id": 3, "descricao_falha": null}, {"status": "Ok", "resposta_id": 459, "valor_texto": null, "item_tipo_id": 6, "descricao_falha": null}, {"status": "Ok", "resposta_id": 458, "valor_texto": null, "item_tipo_id": 5, "descricao_falha": null}, {"status": "Ok", "resposta_id": 460, "valor_texto": null, "item_tipo_id": 7, "descricao_falha": null}, {"status": "Ok", "resposta_id": 455, "valor_texto": null, "item_tipo_id": 2, "descricao_falha": null}, {"status": "Ok", "resposta_id": 463, "valor_texto": "094", "item_tipo_id": 15, "descricao_falha": null}, {"status": "Ok", "resposta_id": 464, "valor_texto": "094", "item_tipo_id": 16, "descricao_falha": null}], "header": {"turno": "Vespertino", "usb_01": null, "usb_02": null, "sala_id": "9", "observacoes": "Todos os testes realizados!", "data_operacao": "2026-03-04", "hora_inicio_testes": "13:47:18", "hora_termino_testes": "14:10:17"}}	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	2026-03-04 18:04:44.128581+00
1	8	{"itens": [{"status": "Ok", "resposta_id": 101, "valor_texto": null, "item_tipo_id": 2, "descricao_falha": null}, {"status": "Ok", "resposta_id": 102, "valor_texto": null, "item_tipo_id": 3, "descricao_falha": null}, {"status": "Ok", "resposta_id": 103, "valor_texto": null, "item_tipo_id": 4, "descricao_falha": null}, {"status": "Ok", "resposta_id": 104, "valor_texto": null, "item_tipo_id": 5, "descricao_falha": null}, {"status": "Ok", "resposta_id": 105, "valor_texto": null, "item_tipo_id": 6, "descricao_falha": null}, {"status": "Ok", "resposta_id": 106, "valor_texto": null, "item_tipo_id": 7, "descricao_falha": null}, {"status": "Ok", "resposta_id": 107, "valor_texto": null, "item_tipo_id": 9, "descricao_falha": null}, {"status": "Ok", "resposta_id": 108, "valor_texto": null, "item_tipo_id": 10, "descricao_falha": null}, {"status": "Ok", "resposta_id": 109, "valor_texto": "46", "item_tipo_id": 15, "descricao_falha": null}, {"status": "Ok", "resposta_id": 110, "valor_texto": "46", "item_tipo_id": 16, "descricao_falha": null}, {"status": "Ok", "resposta_id": 111, "valor_texto": null, "item_tipo_id": 29, "descricao_falha": null}, {"status": "Ok", "resposta_id": 112, "valor_texto": null, "item_tipo_id": 30, "descricao_falha": null}, {"status": "Ok", "resposta_id": 113, "valor_texto": null, "item_tipo_id": 31, "descricao_falha": null}, {"status": "Ok", "resposta_id": 114, "valor_texto": null, "item_tipo_id": 32, "descricao_falha": null}, {"status": "Ok", "resposta_id": 115, "valor_texto": null, "item_tipo_id": 33, "descricao_falha": null}, {"status": "Ok", "resposta_id": 116, "valor_texto": null, "item_tipo_id": 34, "descricao_falha": null}], "header": {"turno": "Matutino", "usb_01": null, "usb_02": null, "sala_id": "10", "observacoes": "A bateria reserva do microfone sem fio ainda se encontra em manutenção com os técnicos", "data_operacao": "2026-03-03", "hora_inicio_testes": "06:59:23", "hora_termino_testes": "07:16:14"}}	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	2026-03-03 16:30:43.132186+00
\.


--
-- Data for Name: checklist_item_tipo; Type: TABLE DATA; Schema: forms; Owner: -
--

COPY forms.checklist_item_tipo (id, nome, criado_em, atualizado_em, tipo_widget) FROM stdin;
1	Sistema Zoom	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
2	PC do Secretário	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
4	Mic sem fio	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
7	Tablet Presidente	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
8	Tablet Secretária	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
3	Vídeowall	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
9	Relógio	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
10	VIP	2025-10-30 19:28:25.543946+00	2025-12-17 17:29:49.801044+00	radio
11	Item teste	2025-12-04 21:36:34.664062+00	2025-12-17 17:29:49.801044+00	radio
12	Página de edição	2025-12-07 17:00:17.675162+00	2025-12-17 17:29:49.801044+00	radio
14	Sistema Zoom sala 19	2026-02-11 17:03:54.785719+00	2026-02-11 17:03:54.785719+00	radio
15	Trilha do Gravador 01	2026-02-11 17:03:54.785719+00	2026-02-11 17:03:54.785719+00	text
16	Trilha do Gravador 02	2026-02-11 17:03:54.785719+00	2026-02-11 17:03:54.785719+00	text
13	Teste	2025-12-17 17:28:36.642695+00	2026-02-25 12:26:38.60788+00	radio
29	Áudio Architect	2026-03-02 12:54:46.601119+00	2026-03-02 12:54:46.601119+00	radio
30	PC 01	2026-03-02 12:55:28.78465+00	2026-03-02 12:55:28.78465+00	radio
31	PC 02	2026-03-02 12:55:40.242701+00	2026-03-02 12:55:40.242701+00	radio
41	Trilha do Gravador 01	2026-03-02 14:36:28.399531+00	2026-03-02 14:36:28.399531+00	radio
42	Trilha do Gravador 02	2026-03-02 14:36:28.399531+00	2026-03-02 14:36:28.399531+00	radio
34	60 Segundos	2026-03-02 13:00:09.780085+00	2026-03-05 00:37:00.974621+00	radio
32	Zoom 01	2026-03-02 12:59:25.018483+00	2026-03-05 00:37:00.974621+00	radio
33	Zoom 02	2026-03-02 12:59:35.531458+00	2026-03-05 00:37:00.974621+00	radio
5	Mic de Bancada	2025-10-30 19:28:25.543946+00	2026-03-05 00:37:00.974621+00	radio
6	Sinal Tv Senado	2025-10-30 19:28:25.543946+00	2026-03-05 00:37:00.974621+00	radio
\.


--
-- Data for Name: checklist_resposta; Type: TABLE DATA; Schema: forms; Owner: -
--

COPY forms.checklist_resposta (id, checklist_id, item_tipo_id, status, descricao_falha, criado_em, atualizado_em, criado_por, atualizado_por, valor_texto, editado) FROM stdin;
1	1	1	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
2	1	2	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
3	1	3	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
4	1	4	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
5	1	5	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
6	1	6	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
7	1	7	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
8	1	8	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
9	1	9	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
10	1	10	Ok	\N	2026-03-02 10:48:47.16057+00	2026-03-02 10:48:47.16057+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
11	2	2	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
12	2	3	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
13	2	4	Falha	Foi detectado que uma das baterias do microfone sem fio não está carregando.	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
14	2	5	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
15	2	6	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
16	2	7	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
17	2	8	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
18	2	9	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
19	2	10	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
20	2	14	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
21	2	15	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	02	f
22	2	16	Ok	\N	2026-03-02 14:04:44.882199+00	2026-03-02 14:04:44.882199+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	02	f
23	3	2	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
24	3	3	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
25	3	4	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
26	3	5	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
27	3	6	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
28	3	7	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
29	3	8	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
30	3	9	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
31	3	10	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
32	3	29	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
33	3	30	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
34	3	31	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
35	3	32	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
36	3	33	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
37	3	34	Ok	\N	2026-03-02 14:05:32.438756+00	2026-03-02 14:05:32.438756+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
38	4	2	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
39	4	3	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
40	4	4	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
41	4	5	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
42	4	6	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
43	4	7	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
44	4	9	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
45	4	10	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
46	4	29	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
47	4	30	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
48	4	31	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
49	4	32	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
50	4	33	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
51	4	34	Ok	\N	2026-03-02 14:30:45.096851+00	2026-03-02 14:30:45.096851+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
52	5	2	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
53	5	3	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
54	5	4	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
55	5	5	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
56	5	6	Falha	Sem sinal.	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
57	5	7	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
58	5	9	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
59	5	10	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
60	5	29	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
61	5	30	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
62	5	31	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
66	5	41	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
67	5	42	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-02 17:48:15.318222+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
68	6	2	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
69	6	3	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
70	6	4	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
71	6	5	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
72	6	6	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
73	6	7	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
74	6	8	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
75	6	9	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
76	6	10	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
77	6	29	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
78	6	30	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
79	6	31	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
80	6	32	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
81	6	33	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
82	6	34	Falha	Quando acionado os 60 segundos no Zoom 1 o áudio não esta saindo na cabine e também na sala. Quando acionado no Zoom 2 esta tudo normal.	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
83	6	41	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
84	6	42	Ok	\N	2026-03-02 18:22:39.321961+00	2026-03-02 18:22:39.321961+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
85	7	2	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
86	7	3	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
87	7	4	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
88	7	5	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
89	7	6	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
90	7	7	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
91	7	9	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
92	7	10	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
93	7	15	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	650	f
94	7	16	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	650	f
95	7	29	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
96	7	30	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
97	7	31	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
98	7	32	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
99	7	33	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
100	7	34	Ok	\N	2026-03-03 10:08:10.962911+00	2026-03-03 10:08:10.962911+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
117	9	2	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
118	9	3	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
119	9	4	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
120	9	5	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
121	9	6	Falha	Sem sinal da tv senado no telão	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
122	9	7	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
123	9	9	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
124	9	10	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
125	9	15	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	O08/012	f
126	9	16	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	008/012	f
127	9	29	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
128	9	30	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
129	9	31	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-03 10:28:06.684784+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
133	10	2	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
134	10	3	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
135	10	4	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
136	10	7	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
137	10	10	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
138	10	15	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	005	f
139	10	16	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	005	f
140	10	29	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
141	10	30	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
142	10	31	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-03 10:53:18.431974+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
143	10	5	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
147	10	9	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
132	9	34	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
146	10	34	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
130	9	32	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
144	10	32	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
131	9	33	Ok	\N	2026-03-03 10:28:06.684784+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
145	10	33	Ok	\N	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
149	11	2	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
150	11	3	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
151	11	4	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
152	11	5	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
153	11	6	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
154	11	7	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
155	11	8	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
156	11	9	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
157	11	10	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
158	11	15	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	01	f
159	11	16	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	01	f
160	11	29	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
161	11	30	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
162	11	31	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
163	11	32	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
164	11	33	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
165	11	34	Ok	\N	2026-03-03 11:13:31.179086+00	2026-03-03 11:13:31.179086+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
166	12	2	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
167	12	3	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
168	12	4	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
169	12	5	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
170	12	6	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
171	12	7	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
172	12	9	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
173	12	10	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
174	12	15	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	007/008	f
175	12	16	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	007/008	f
176	12	29	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
177	12	30	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
178	12	31	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
179	12	32	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
180	12	33	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
181	12	34	Ok	\N	2026-03-03 11:48:07.178549+00	2026-03-03 11:48:07.178549+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
182	13	2	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
183	13	3	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
184	13	4	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
185	13	5	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
186	13	6	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
187	13	7	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
188	13	9	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
189	13	10	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
190	13	15	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	123 - 156	f
191	13	16	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	121 - 154	f
192	13	29	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
193	13	30	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
194	13	31	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
195	13	32	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
196	13	33	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
197	13	34	Ok	\N	2026-03-03 11:59:33.0285+00	2026-03-03 11:59:33.0285+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
198	14	2	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
199	14	3	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
200	14	4	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
201	14	5	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
202	14	6	Falha	Tb senado Sem sinal	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
203	14	7	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
204	14	9	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
205	14	10	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
206	14	15	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	198	f
207	14	16	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	198	f
208	14	29	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
209	14	30	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
210	14	31	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
211	14	32	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
212	14	33	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
213	14	34	Ok	\N	2026-03-03 12:40:31.199164+00	2026-03-03 12:40:31.199164+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
214	15	2	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
215	15	3	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
216	15	4	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
217	15	5	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
218	15	6	Falha	Sem sinal da TV senado	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
219	15	7	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
220	15	9	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
221	15	10	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
222	15	15	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	158/184	f
223	15	16	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	156/183	f
224	15	29	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
225	15	30	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
226	15	31	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
227	15	32	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
228	15	33	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
229	15	34	Ok	\N	2026-03-03 16:11:57.16828+00	2026-03-03 16:11:57.16828+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
230	16	2	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
231	16	3	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
232	16	4	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
233	16	5	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
234	16	6	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
235	16	7	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
236	16	9	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
237	16	10	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
238	16	15	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	069	f
239	16	16	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	070	f
240	16	29	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
241	16	30	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
242	16	31	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
243	16	32	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
244	16	33	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
245	16	34	Ok	\N	2026-03-03 16:13:47.431792+00	2026-03-03 16:13:47.431792+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
111	8	29	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
112	8	30	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
113	8	31	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
104	8	5	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
103	8	4	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
106	8	7	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
101	8	2	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
109	8	15	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	46	f
110	8	16	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	46	f
102	8	3	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
107	8	9	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
105	8	6	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
108	8	10	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-03 16:30:43.132186+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
246	17	2	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
247	17	3	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
248	17	4	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
249	17	5	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
250	17	6	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
251	17	7	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
252	17	9	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
253	17	10	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
254	17	15	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	216	f
255	17	16	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	198	f
256	17	29	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
257	17	30	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
258	17	31	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
259	17	32	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
260	17	33	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
261	17	34	Ok	\N	2026-03-03 16:35:47.550791+00	2026-03-03 16:35:47.550791+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
262	18	2	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
263	18	3	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
264	18	4	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
265	18	5	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
266	18	6	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
267	18	7	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
268	18	9	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
269	18	10	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
270	18	15	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	009	f
271	18	16	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	009	f
272	18	29	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
273	18	30	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
274	18	31	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
275	18	32	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
276	18	33	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
277	18	34	Ok	\N	2026-03-03 16:37:23.627053+00	2026-03-03 16:37:23.627053+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
278	19	2	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
279	19	3	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
280	19	4	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
281	19	7	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
282	19	10	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
283	19	15	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	009 - 010	f
284	19	16	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	009 - 010	f
285	19	29	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
286	19	30	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
287	19	31	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-03 18:56:23.83942+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
294	20	2	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
295	20	3	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
296	20	4	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
297	20	5	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
298	20	6	Falha	Sem sinal de TV apenas tela preta.	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
299	20	7	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
300	20	9	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
301	20	10	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
302	20	15	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	111 -  112	f
303	20	16	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	111 - 112	f
304	20	29	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
305	20	30	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
306	20	31	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-04 10:08:29.423462+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
310	21	2	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
311	21	3	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
312	21	4	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
313	21	5	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
314	21	6	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
315	21	7	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
316	21	9	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
317	21	10	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
318	21	15	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	702	f
319	21	16	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	702	f
320	21	29	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
321	21	30	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
322	21	31	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
323	21	32	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
324	21	33	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
325	21	34	Ok	\N	2026-03-04 10:12:44.388556+00	2026-03-04 10:12:44.388556+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
326	22	2	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
327	22	3	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
328	22	4	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
329	22	5	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
330	22	6	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
331	22	7	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
332	22	9	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
333	22	10	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
334	22	15	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	077/082	f
335	22	16	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	077/082	f
336	22	29	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
337	22	30	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
338	22	31	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-04 10:46:09.391168+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
342	23	2	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
343	23	3	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
344	23	4	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
345	23	7	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
346	23	10	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
347	23	15	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	011	f
348	23	16	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	011	f
349	23	29	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
350	23	30	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
351	23	31	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-04 10:48:10.92556+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
358	24	2	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
359	24	3	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
360	24	4	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
361	24	5	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
362	24	6	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
363	24	7	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
364	24	9	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
365	24	10	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
366	24	15	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	011/012	f
367	24	16	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	011/012	f
368	24	29	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
369	24	30	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
370	24	31	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
371	24	32	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
372	24	33	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
373	24	34	Ok	\N	2026-03-04 11:09:21.583208+00	2026-03-04 11:09:21.583208+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
374	25	2	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
375	25	3	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
376	25	4	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
377	25	5	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
378	25	6	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
379	25	7	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
380	25	8	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
381	25	9	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
382	25	10	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
383	25	15	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	05	f
384	25	16	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	05	f
385	25	29	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
386	25	30	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
387	25	31	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
388	25	32	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
389	25	33	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
390	25	34	Ok	\N	2026-03-04 11:19:19.62823+00	2026-03-04 11:19:19.62823+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
391	26	2	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
392	26	3	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
393	26	4	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
394	26	5	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
395	26	6	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
396	26	7	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
397	26	9	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
398	26	10	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
399	26	15	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	235	f
400	26	16	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	211	f
401	26	29	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
402	26	30	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
403	26	31	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
404	26	32	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
405	26	33	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
406	26	34	Ok	\N	2026-03-04 11:49:45.739281+00	2026-03-04 11:49:45.739281+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
407	27	2	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
408	27	3	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
409	27	4	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
410	27	5	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
411	27	6	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
412	27	7	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
413	27	9	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
414	27	10	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
415	27	15	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	213 - 240	f
416	27	16	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	213 - 245	f
417	27	29	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
418	27	30	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
419	27	31	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
420	27	32	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
421	27	33	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
422	27	34	Ok	\N	2026-03-04 12:27:53.672971+00	2026-03-04 12:27:53.672971+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
423	28	2	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
424	28	3	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
425	28	4	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
426	28	5	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
427	28	6	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
428	28	7	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
429	28	9	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
430	28	10	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
431	28	15	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	237	f
432	28	16	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	213	f
433	28	29	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
434	28	30	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
435	28	31	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
436	28	32	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
437	28	33	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
438	28	34	Ok	\N	2026-03-04 16:01:22.06569+00	2026-03-04 16:01:22.06569+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
439	29	2	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
440	29	3	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
441	29	4	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
442	29	5	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
443	29	6	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
444	29	7	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
445	29	9	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
446	29	10	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
447	29	15	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	776-783	f
448	29	16	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	776-783	f
449	29	29	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
450	29	30	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
451	29	31	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
452	29	32	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
453	29	33	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
454	29	34	Ok	\N	2026-03-04 16:50:58.285065+00	2026-03-04 16:50:58.285065+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
471	31	2	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
472	31	3	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
473	31	4	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
474	31	5	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
475	31	6	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
476	31	7	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
477	31	9	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
478	31	10	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
479	31	15	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	248/271	f
480	31	16	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	251/277	f
481	31	29	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
482	31	30	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
483	31	31	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
484	31	32	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
485	31	33	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
486	31	34	Ok	\N	2026-03-04 17:17:21.029345+00	2026-03-04 17:17:21.029345+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
487	32	2	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
488	32	3	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
489	32	4	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
490	32	7	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
491	32	10	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
492	32	15	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	063	f
493	32	16	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	063	f
494	32	29	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
495	32	30	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
496	32	31	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-04 17:38:05.14016+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
465	30	29	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
466	30	30	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
467	30	31	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
457	30	4	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
462	30	10	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
461	30	9	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
456	30	3	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
459	30	6	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
458	30	5	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
460	30	7	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
455	30	2	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
463	30	15	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	094	f
464	30	16	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	094	f
468	30	32	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
469	30	33	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
470	30	34	Ok	\N	2026-03-04 17:10:18.873449+00	2026-03-04 18:04:44.128581+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
503	33	2	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
504	33	3	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
505	33	4	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
506	33	6	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
507	33	7	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
508	33	9	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
509	33	10	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
510	33	15	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	049	f
511	33	16	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	049	f
512	33	29	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
513	33	30	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
514	33	31	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
515	33	32	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
516	33	33	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
517	33	34	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-04 18:46:01.870263+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
497	32	5	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
518	33	5	Ok	\N	2026-03-04 18:46:01.870263+00	2026-03-05 00:37:00.974621+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
501	32	9	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
500	32	34	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
502	32	6	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
498	32	32	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
499	32	33	Ok	\N	2026-03-04 17:38:05.14016+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
288	19	5	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
352	23	5	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
292	19	9	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
356	23	9	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
65	5	34	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-05 00:37:00.974621+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
116	8	34	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
291	19	34	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
309	20	34	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
341	22	34	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
355	23	34	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
148	10	6	Falha	Sem sinal no momento	2026-03-03 10:53:18.431974+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
293	19	6	Falha	TV não está enviando sinal.	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
357	23	6	Falha	Sem sinal o momento	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
63	5	32	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-05 00:37:00.974621+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
114	8	32	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
289	19	32	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
307	20	32	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
339	22	32	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
353	23	32	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
64	5	33	Ok	\N	2026-03-02 17:48:15.318222+00	2026-03-05 00:37:00.974621+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
115	8	33	Ok	\N	2026-03-03 10:16:15.10237+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
290	19	33	Ok	\N	2026-03-03 18:56:23.83942+00	2026-03-05 00:37:00.974621+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
308	20	33	Ok	\N	2026-03-04 10:08:29.423462+00	2026-03-05 00:37:00.974621+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
340	22	33	Ok	\N	2026-03-04 10:46:09.391168+00	2026-03-05 00:37:00.974621+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
354	23	33	Ok	\N	2026-03-04 10:48:10.92556+00	2026-03-05 00:37:00.974621+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
519	34	2	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
520	34	3	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
521	34	4	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
522	34	5	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
523	34	6	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
524	34	7	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
525	34	9	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
526	34	10	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
527	34	15	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	800	f
528	34	16	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	800	f
529	34	29	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
530	34	30	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
531	34	31	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
532	34	32	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
533	34	33	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
534	34	34	Ok	\N	2026-03-05 10:08:06.283065+00	2026-03-05 10:08:06.283065+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
535	35	2	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
536	35	3	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
537	35	4	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
538	35	5	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
539	35	6	Falha	Sem sinal e imagem da TV Senado.	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
540	35	7	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
541	35	9	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
542	35	10	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
543	35	15	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	184-186	f
544	35	16	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	184-186	f
545	35	29	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
546	35	30	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
547	35	31	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
548	35	32	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
549	35	33	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
550	35	34	Ok	\N	2026-03-05 10:16:25.271585+00	2026-03-05 10:16:25.271585+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
551	36	2	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
552	36	3	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
553	36	4	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
554	36	5	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
555	36	6	Falha	Sem sinal da tv senado no telão.	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
556	36	7	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
557	36	9	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
558	36	10	Falha	Plenari 15 sem vip.	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
559	36	15	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	099/103	f
560	36	16	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	099/103	f
561	36	29	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
562	36	30	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
563	36	31	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
564	36	32	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
565	36	33	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
566	36	34	Ok	\N	2026-03-05 10:30:51.402166+00	2026-03-05 10:30:51.402166+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
567	37	2	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
568	37	3	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
569	37	4	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
570	37	5	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
571	37	6	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
572	37	7	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
573	37	9	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
574	37	10	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
575	37	15	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	063 064	f
576	37	16	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	063 064	f
577	37	29	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
578	37	30	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
579	37	31	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
580	37	32	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
581	37	33	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
582	37	34	Ok	\N	2026-03-05 10:44:34.15019+00	2026-03-05 10:44:34.15019+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
583	38	2	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
584	38	3	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
585	38	4	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
586	38	5	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
587	38	6	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
588	38	7	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
589	38	8	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
590	38	9	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
591	38	10	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
592	38	15	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	05	f
593	38	16	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	05	f
594	38	29	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
595	38	30	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
596	38	31	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
597	38	32	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
598	38	33	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
599	38	34	Ok	\N	2026-03-05 11:25:19.291483+00	2026-03-05 11:25:19.291483+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
600	39	2	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
601	39	3	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
602	39	4	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
603	39	5	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
604	39	6	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
605	39	7	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
606	39	9	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
607	39	10	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
608	39	15	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	269	f
609	39	16	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	255	f
610	39	29	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
611	39	30	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
612	39	31	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
613	39	32	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
614	39	33	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
615	39	34	Ok	\N	2026-03-05 11:30:28.404583+00	2026-03-05 11:30:28.404583+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	\N	f
616	40	2	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
617	40	3	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
618	40	4	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
619	40	5	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
620	40	6	Falha	Sem sinal(Tela black)	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
621	40	7	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
622	40	9	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
623	40	10	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
624	40	15	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	275 - 309	f
625	40	16	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	278 - 317	f
626	40	29	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
627	40	30	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
628	40	31	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
629	40	32	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
630	40	33	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
631	40	34	Ok	\N	2026-03-05 11:33:06.904175+00	2026-03-05 11:33:06.904175+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
632	41	2	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
633	41	3	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
634	41	4	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
635	41	5	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
636	41	6	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
637	41	7	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
638	41	9	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
639	41	10	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
640	41	15	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	061/062	f
641	41	16	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	061/062	f
642	41	29	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
643	41	30	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
644	41	31	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
645	41	32	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
646	41	33	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
647	41	34	Ok	\N	2026-03-05 11:40:55.72079+00	2026-03-05 11:40:55.72079+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
648	42	2	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
649	42	3	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
650	42	4	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
651	42	5	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
652	42	6	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
653	42	7	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
654	42	9	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
655	42	10	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
656	42	15	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	067	f
657	42	16	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	067	f
658	42	29	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
659	42	30	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
660	42	31	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
661	42	32	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
662	42	33	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
663	42	34	Ok	\N	2026-03-05 16:38:47.895542+00	2026-03-05 16:38:47.895542+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
664	43	2	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
665	43	3	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
666	43	4	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
667	43	5	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
668	43	6	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
669	43	7	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
670	43	9	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
671	43	10	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
672	43	15	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	284	f
673	43	16	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	262	f
674	43	29	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
675	43	30	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
676	43	31	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
677	43	32	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
678	43	33	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
679	43	34	Ok	\N	2026-03-05 16:50:33.460009+00	2026-03-05 16:50:33.460009+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	\N	f
680	44	2	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
681	44	3	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
682	44	4	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
683	44	5	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
684	44	6	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
685	44	7	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
686	44	9	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
687	44	10	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
688	44	15	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	072-073	f
689	44	16	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	072-073	f
690	44	29	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
691	44	30	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
692	44	31	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
693	44	32	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
694	44	33	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
695	44	34	Ok	\N	2026-03-05 17:19:29.659314+00	2026-03-05 17:19:29.659314+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
696	45	2	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
697	45	3	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
698	45	4	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
699	45	5	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
700	45	6	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
701	45	7	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
702	45	9	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
703	45	10	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
704	45	15	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	819/822	f
705	45	16	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	819/822	f
706	45	29	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
707	45	30	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
708	45	31	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
709	45	32	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
710	45	33	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
711	45	34	Ok	\N	2026-03-05 17:37:09.855518+00	2026-03-05 17:37:09.855518+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
712	46	2	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
713	46	3	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
714	46	4	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
715	46	5	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
716	46	6	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
717	46	7	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
718	46	9	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
719	46	10	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
720	46	15	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	104	f
721	46	16	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	104	f
722	46	29	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
723	46	30	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
724	46	31	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
725	46	32	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
726	46	33	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
727	46	34	Ok	\N	2026-03-05 17:41:47.601818+00	2026-03-05 17:41:47.601818+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
728	47	2	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
729	47	3	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
730	47	4	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
731	47	5	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
732	47	6	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
733	47	7	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
734	47	8	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
735	47	9	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
736	47	10	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
737	47	15	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	007	f
738	47	16	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	007	f
739	47	29	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
740	47	30	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
741	47	31	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
742	47	32	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
743	47	33	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
744	47	34	Ok	\N	2026-03-05 18:17:58.473394+00	2026-03-05 18:17:58.473394+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	\N	f
745	48	2	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
746	48	3	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
747	48	4	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
748	48	5	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
749	48	6	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
750	48	7	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
751	48	9	Falha	Relógio da sala 15 com horário errado(adiantado)	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
752	48	10	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
753	48	15	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	110/115	f
754	48	16	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	110/115	f
755	48	29	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
756	48	30	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
757	48	31	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
758	48	32	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
759	48	33	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
760	48	34	Ok	\N	2026-03-06 10:10:06.259767+00	2026-03-06 10:10:06.259767+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
761	49	2	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
762	49	3	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
763	49	4	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
764	49	5	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
765	49	6	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
766	49	7	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
767	49	9	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
768	49	10	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
769	49	15	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	080/082	f
770	49	16	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	081/084	f
771	49	29	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
772	49	30	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
773	49	31	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
774	49	32	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
775	49	33	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
776	49	34	Ok	\N	2026-03-06 11:53:03.989366+00	2026-03-06 11:53:03.989366+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
777	50	2	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
778	50	3	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
779	50	4	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
780	50	5	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
781	50	6	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
782	50	7	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
783	50	9	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
784	50	10	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
785	50	15	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	863	f
786	50	16	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	863	f
787	50	29	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
788	50	30	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
789	50	31	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
790	50	32	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
791	50	33	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
792	50	34	Ok	\N	2026-03-06 16:39:35.163096+00	2026-03-06 16:39:35.163096+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
793	51	2	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
794	51	3	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
795	51	4	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
796	51	5	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
797	51	6	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
798	51	7	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
799	51	9	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
800	51	10	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
801	51	15	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	253	f
802	51	16	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	253	f
803	51	29	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
804	51	30	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
805	51	31	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
806	51	32	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
807	51	33	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
808	51	34	Ok	\N	2026-03-06 17:51:43.258111+00	2026-03-06 17:51:43.258111+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
809	52	2	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
810	52	3	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
811	52	4	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
812	52	5	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
813	52	6	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
814	52	7	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
815	52	9	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
816	52	10	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
817	52	15	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	278	f
818	52	16	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	365	f
819	52	29	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
820	52	30	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
821	52	31	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
822	52	32	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
823	52	33	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
824	52	34	Ok	\N	2026-03-06 18:35:26.528973+00	2026-03-06 18:35:26.528973+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
825	53	2	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
826	53	3	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
827	53	4	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
828	53	5	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
829	53	6	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
830	53	7	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
831	53	9	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
832	53	10	Falha	O vip da sala 07 está com vídeo mas sem áudio.	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
833	53	15	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	001/040	f
834	53	16	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	001/008	f
835	53	29	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
836	53	30	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
837	53	31	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
838	53	32	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
839	53	33	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
840	53	34	Ok	\N	2026-03-09 10:17:42.444039+00	2026-03-09 10:17:42.444039+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	\N	f
841	54	2	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
842	54	3	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
843	54	4	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
844	54	5	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
845	54	6	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
846	54	7	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
847	54	9	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
848	54	10	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
849	54	15	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	12	f
850	54	16	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	11	f
851	54	29	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
852	54	30	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
853	54	31	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
854	54	32	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
855	54	33	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
856	54	34	Ok	\N	2026-03-09 10:20:46.305616+00	2026-03-09 10:20:46.305616+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	\N	f
857	55	2	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
858	55	3	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
859	55	4	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
860	55	5	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
861	55	6	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
862	55	7	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
863	55	9	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
864	55	10	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
865	55	15	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	001	f
866	55	16	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	001	f
867	55	29	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
868	55	30	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
869	55	31	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
870	55	32	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
871	55	33	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
872	55	34	Ok	\N	2026-03-09 10:25:21.011964+00	2026-03-09 10:25:21.011964+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	\N	f
873	56	2	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
874	56	3	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
875	56	4	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
876	56	5	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
877	56	6	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
878	56	7	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
879	56	9	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
880	56	10	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
881	56	15	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	001 002	f
882	56	16	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	001 002	f
883	56	29	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
884	56	30	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
885	56	31	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
886	56	32	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
887	56	33	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
888	56	34	Ok	\N	2026-03-09 11:25:44.481266+00	2026-03-09 11:25:44.481266+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	\N	f
889	57	2	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
890	57	3	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
891	57	4	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
892	57	5	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
893	57	6	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
894	57	7	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
895	57	9	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
896	57	10	Falha	Sem áudio da sala no vip, canal 24.	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
897	57	15	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	001/004	f
898	57	16	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	001/004	f
899	57	29	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
900	57	30	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
901	57	31	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
902	57	32	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
903	57	33	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
904	57	34	Ok	\N	2026-03-09 11:38:33.596372+00	2026-03-09 11:38:33.596372+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	\N	f
905	58	2	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
906	58	3	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
907	58	4	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
908	58	5	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
909	58	6	Falha	Sem sinal de video	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
910	58	7	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
911	58	9	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
912	58	10	Falha	Sem sinal de vídeo	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
913	58	15	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	85	f
914	58	16	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	86	f
915	58	29	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
916	58	30	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
917	58	31	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
918	58	32	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
919	58	33	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
920	58	34	Ok	\N	2026-03-09 11:38:57.666747+00	2026-03-09 11:38:57.666747+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	\N	f
921	59	2	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
922	59	3	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
923	59	4	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
924	59	5	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
925	59	6	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
926	59	7	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
927	59	8	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
928	59	9	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
929	59	10	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
930	59	15	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	008	f
931	59	16	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	008	f
932	59	29	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
933	59	30	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
934	59	31	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
935	59	32	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
936	59	33	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
937	59	34	Ok	\N	2026-03-09 11:41:49.270791+00	2026-03-09 11:41:49.270791+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	\N	f
938	60	2	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
939	60	3	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
940	60	4	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
941	60	5	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
942	60	6	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
943	60	7	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
944	60	9	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
945	60	10	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
946	60	15	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	074/077	f
947	60	16	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	074/077	f
948	60	29	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
949	60	30	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
950	60	31	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
951	60	32	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
952	60	33	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
953	60	34	Ok	\N	2026-03-09 13:19:26.371551+00	2026-03-09 13:19:26.371551+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
954	61	2	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
955	61	3	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
956	61	4	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
957	61	5	Falha	Mic.A4 rangendo na mola inferior.	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
958	61	6	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
959	61	7	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
960	61	9	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
961	61	10	Falha	Obs.: Vip sem saída de áudio local(plenário 07). Ao invés de reproduzir o áudio reproduzido no 07, reproduz sinal do tom pelo Distribuidor Trad.	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
962	61	15	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	41 - 69	f
963	61	16	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	09 - 15	f
964	61	29	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
965	61	30	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
966	61	31	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
967	61	32	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
968	61	33	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
969	61	34	Ok	\N	2026-03-09 16:42:22.909861+00	2026-03-09 16:42:22.909861+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	\N	f
970	62	2	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
971	62	3	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
972	62	4	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
973	62	5	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
974	62	6	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
975	62	7	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
976	62	9	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
977	62	10	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
978	62	15	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	88/89	f
979	62	16	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	88/89	f
980	62	29	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
981	62	30	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
982	62	31	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
983	62	32	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
984	62	33	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
985	62	34	Ok	\N	2026-03-09 16:47:57.834323+00	2026-03-09 16:47:57.834323+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	\N	f
986	63	2	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
987	63	3	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
988	63	4	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
989	63	5	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
990	63	6	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
991	63	7	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
992	63	9	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
993	63	10	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
994	63	15	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	094	f
995	63	16	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	095	f
996	63	29	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
997	63	30	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
998	63	31	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
999	63	32	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
1000	63	33	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
1001	63	34	Ok	\N	2026-03-09 17:00:19.790677+00	2026-03-09 17:00:19.790677+00	1793be06-d86d-4b3b-a72f-3de0fe072c61	1793be06-d86d-4b3b-a72f-3de0fe072c61	\N	f
1002	64	2	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1003	64	3	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1004	64	4	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1005	64	5	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1006	64	6	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1007	64	7	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1008	64	9	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1009	64	10	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1010	64	15	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	069/075	f
1011	64	16	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	069/075	f
1012	64	29	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1013	64	30	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1014	64	31	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1015	64	32	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1016	64	33	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1017	64	34	Ok	\N	2026-03-09 17:03:22.746286+00	2026-03-09 17:03:22.746286+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	f
1018	65	2	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1019	65	3	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1020	65	4	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1021	65	5	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1022	65	6	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1023	65	7	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1024	65	9	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1025	65	10	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1026	65	15	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	002 - 006	f
1027	65	16	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	002 - 006	f
1028	65	29	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1029	65	30	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1030	65	31	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1031	65	32	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1032	65	33	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1033	65	34	Ok	\N	2026-03-09 17:11:47.861369+00	2026-03-09 17:11:47.861369+00	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	\N	f
1034	66	2	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1035	66	3	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1036	66	4	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1037	66	5	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1038	66	6	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1039	66	7	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1040	66	8	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1041	66	9	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1042	66	10	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1043	66	15	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	009	f
1044	66	16	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	009	f
1045	66	29	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1046	66	30	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1047	66	31	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1048	66	32	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1049	66	33	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
1050	66	34	Ok	\N	2026-03-09 17:23:36.956145+00	2026-03-09 17:23:36.956145+00	3135733f-8d6a-4ac8-9cb0-c34002ae823c	3135733f-8d6a-4ac8-9cb0-c34002ae823c	\N	f
\.


--
-- Data for Name: checklist_sala_config; Type: TABLE DATA; Schema: forms; Owner: -
--

COPY forms.checklist_sala_config (id, sala_id, item_tipo_id, ordem, ativo, criado_em, atualizado_em) FROM stdin;
1	1	13	0	f	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
2	1	12	0	f	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
3	1	11	0	f	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
4	1	1	1	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
5	1	2	2	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
6	1	4	3	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
7	1	5	4	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
8	1	6	5	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
9	1	7	6	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
10	1	8	7	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
11	1	3	8	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
12	1	9	9	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
13	1	10	10	t	2026-02-11 16:47:41.94283+00	2026-02-11 16:47:41.94283+00
58	5	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
60	5	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
59	5	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
61	5	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
66	6	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
92	8	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
93	8	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
67	6	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
68	6	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
173	9	29	1	t	2026-03-02 14:27:23.974867+00	2026-03-04 17:51:15.924494+00
69	6	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
174	9	30	2	t	2026-03-02 14:27:23.974867+00	2026-03-04 17:51:15.924494+00
175	9	31	3	t	2026-03-02 14:27:23.974867+00	2026-03-04 17:51:15.924494+00
79	7	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
80	7	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
75	6	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
140	4	29	1	t	2026-03-02 13:04:12.740306+00	2026-03-05 00:58:08.233811+00
141	4	32	5	t	2026-03-02 13:04:35.35739+00	2026-03-05 00:58:08.233811+00
110	9	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
57	5	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
164	8	29	1	t	2026-03-02 14:23:52.77198+00	2026-03-04 17:50:20.672771+00
165	8	30	2	t	2026-03-02 14:23:52.77198+00	2026-03-04 17:50:20.672771+00
142	4	33	6	t	2026-03-02 13:04:35.35739+00	2026-03-05 00:58:08.233811+00
15	2	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
118	10	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
119	10	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
120	10	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
121	10	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
131	10	14	0	f	2026-02-11 17:03:54.785719+00	2026-03-04 17:52:29.02577+00
123	10	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
124	10	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
122	10	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
132	10	15	15	t	2026-02-11 17:03:54.785719+00	2026-03-04 17:52:29.02577+00
40	4	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
41	4	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
42	4	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
43	4	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
111	9	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
109	9	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
16	2	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
81	7	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
82	7	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
88	7	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
27	3	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
28	3	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
29	3	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
105	9	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
106	9	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
30	3	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
14	2	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
36	3	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
17	2	1	1	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
71	6	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
77	6	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
76	6	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
18	2	2	2	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
19	2	4	3	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
73	6	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
72	6	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
74	6	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
70	6	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
20	2	5	4	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
53	5	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
54	5	12	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
32	3	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
21	2	6	5	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
139	3	34	7	t	2026-03-02 13:00:09.780085+00	2026-03-04 17:39:39.571086+00
84	7	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
22	2	7	6	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
107	9	11	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
108	9	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
91	7	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
90	7	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
89	7	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
23	2	8	7	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
24	2	3	8	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
25	2	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
26	2	10	10	t	2026-02-11 16:47:41.94283+00	2026-03-05 18:21:30.905571+00
86	7	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
87	7	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
34	3	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
33	3	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
35	3	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
31	3	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
55	5	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
56	5	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
62	5	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
83	7	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:36:46.662282+00
135	3	30	2	t	2026-03-02 12:55:28.78465+00	2026-03-04 17:39:39.571086+00
136	3	31	3	t	2026-03-02 12:55:40.242701+00	2026-03-04 17:39:39.571086+00
137	3	32	5	t	2026-03-02 12:59:25.018483+00	2026-03-04 17:39:39.571086+00
138	3	33	6	t	2026-03-02 12:59:35.531458+00	2026-03-04 17:39:39.571086+00
127	10	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
161	7	32	5	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
162	7	33	6	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
39	3	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
163	7	34	7	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
144	4	30	2	t	2026-03-02 13:17:26.681335+00	2026-03-05 00:58:08.233811+00
145	4	31	3	t	2026-03-02 13:17:37.623346+00	2026-03-05 00:58:08.233811+00
45	4	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
166	8	31	3	t	2026-03-02 14:23:52.77198+00	2026-03-04 17:50:20.672771+00
97	8	4	4	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
143	4	34	7	t	2026-03-02 13:05:08.036723+00	2026-03-05 00:58:08.233811+00
52	4	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
51	4	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
50	4	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
47	4	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
46	4	5	12	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
48	4	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
49	4	8	14	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
44	4	2	15	t	2026-02-11 16:47:41.94283+00	2026-03-05 00:58:08.233811+00
152	6	29	1	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
114	9	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
156	6	30	2	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
102	8	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
167	8	5	12	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
185	9	41	0	f	2026-03-02 14:36:28.399531+00	2026-03-04 17:51:15.924494+00
186	9	42	0	f	2026-03-02 14:36:28.399531+00	2026-03-04 17:51:15.924494+00
157	6	31	3	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
153	6	32	5	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
154	6	33	6	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
179	10	29	1	t	2026-03-02 14:31:16.029431+00	2026-03-04 17:52:29.02577+00
180	10	30	2	t	2026-03-02 14:31:16.029431+00	2026-03-04 17:52:29.02577+00
193	5	41	0	f	2026-03-02 14:40:19.122105+00	2026-03-04 17:43:41.696866+00
194	5	42	0	f	2026-03-02 14:40:19.122105+00	2026-03-04 17:43:41.696866+00
155	6	34	7	t	2026-03-02 13:34:01.942469+00	2026-03-04 17:44:46.121+00
78	6	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:44:46.121+00
181	10	31	3	t	2026-03-02 14:31:16.029431+00	2026-03-04 17:52:29.02577+00
197	3	41	0	f	2026-03-02 14:41:47.187981+00	2026-03-04 17:39:39.571086+00
38	3	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
130	10	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
129	10	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
37	3	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:39:39.571086+00
117	9	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
116	9	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
128	10	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
115	9	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
112	9	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
113	9	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:51:15.924494+00
187	8	41	0	f	2026-03-02 14:37:29.844955+00	2026-03-04 17:50:20.672771+00
189	7	41	0	f	2026-03-02 14:38:25.188217+00	2026-03-04 17:36:46.662282+00
171	8	9	9	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
190	7	42	0	f	2026-03-02 14:38:25.188217+00	2026-03-04 17:36:46.662282+00
125	10	6	11	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
188	8	42	0	f	2026-03-02 14:37:29.844955+00	2026-03-04 17:50:20.672771+00
95	8	1	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
146	5	29	1	t	2026-03-02 13:22:27.767386+00	2026-03-04 17:43:41.696866+00
150	5	30	2	t	2026-03-02 13:27:01.527797+00	2026-03-04 17:43:41.696866+00
126	10	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:52:29.02577+00
133	10	16	16	t	2026-02-11 17:03:54.785719+00	2026-03-04 17:52:29.02577+00
151	5	31	3	t	2026-03-02 13:27:57.378639+00	2026-03-04 17:43:41.696866+00
147	5	32	5	t	2026-03-02 13:22:58.256189+00	2026-03-04 17:43:41.696866+00
148	5	33	6	t	2026-03-02 13:23:08.463892+00	2026-03-04 17:43:41.696866+00
170	8	34	7	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
184	10	34	7	t	2026-03-02 14:31:16.029431+00	2026-03-05 00:37:00.974621+00
178	9	34	7	t	2026-03-02 14:27:23.974867+00	2026-03-05 00:37:00.974621+00
168	8	32	5	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
182	10	32	5	t	2026-03-02 14:31:16.029431+00	2026-03-05 00:37:00.974621+00
176	9	32	5	t	2026-03-02 14:27:23.974867+00	2026-03-05 00:37:00.974621+00
169	8	33	6	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
183	10	33	6	t	2026-03-02 14:31:16.029431+00	2026-03-05 00:37:00.974621+00
177	9	33	6	t	2026-03-02 14:27:23.974867+00	2026-03-05 00:37:00.974621+00
149	5	34	7	t	2026-03-02 13:23:25.849579+00	2026-03-04 17:43:41.696866+00
158	7	29	1	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
159	7	30	2	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
160	7	31	3	t	2026-03-02 13:46:33.319258+00	2026-03-04 17:36:46.662282+00
198	3	42	0	f	2026-03-02 14:41:47.187981+00	2026-03-04 17:39:39.571086+00
65	5	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
64	5	9	9	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
63	5	3	10	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:43:41.696866+00
100	8	7	13	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
96	8	2	14	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
134	3	29	1	t	2026-03-02 12:54:46.601119+00	2026-03-04 17:39:39.571086+00
195	4	41	0	f	2026-03-02 14:41:00.293488+00	2026-03-05 00:58:08.233811+00
196	4	42	0	f	2026-03-02 14:41:00.293488+00	2026-03-05 00:58:08.233811+00
191	6	41	0	f	2026-03-02 14:39:32.686741+00	2026-03-04 17:44:46.121+00
192	6	42	0	f	2026-03-02 14:39:32.686741+00	2026-03-04 17:44:46.121+00
94	8	13	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
213	7	5	12	t	2026-03-04 17:34:50.723764+00	2026-03-05 00:37:00.974621+00
172	8	6	11	t	2026-03-02 14:23:52.77198+00	2026-03-05 00:37:00.974621+00
201	4	15	16	t	2026-03-02 18:37:07.009056+00	2026-03-05 00:58:08.233811+00
202	4	16	17	t	2026-03-02 18:37:07.009056+00	2026-03-05 00:58:08.233811+00
207	7	15	15	t	2026-03-02 18:37:52.008956+00	2026-03-04 17:36:46.662282+00
208	7	16	16	t	2026-03-02 18:37:52.008956+00	2026-03-04 17:36:46.662282+00
199	3	15	15	t	2026-03-02 18:36:48.665228+00	2026-03-04 17:39:39.571086+00
200	3	16	16	t	2026-03-02 18:36:48.665228+00	2026-03-04 17:39:39.571086+00
203	5	15	15	t	2026-03-02 18:37:20.099775+00	2026-03-04 17:43:41.696866+00
204	5	16	16	t	2026-03-02 18:37:20.099775+00	2026-03-04 17:43:41.696866+00
205	6	15	15	t	2026-03-02 18:37:36.152945+00	2026-03-04 17:44:46.121+00
206	6	16	16	t	2026-03-02 18:37:36.152945+00	2026-03-04 17:44:46.121+00
101	8	8	0	f	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
104	8	10	8	t	2026-02-11 16:47:41.94283+00	2026-03-04 17:50:20.672771+00
209	8	15	15	t	2026-03-02 18:38:10.430762+00	2026-03-04 17:50:20.672771+00
210	8	16	16	t	2026-03-02 18:38:10.430762+00	2026-03-04 17:50:20.672771+00
211	9	15	15	t	2026-03-02 18:38:27.651249+00	2026-03-04 17:51:15.924494+00
212	9	16	16	t	2026-03-02 18:38:27.651249+00	2026-03-04 17:51:15.924494+00
\.


--
-- Data for Name: registro_anormalidade; Type: TABLE DATA; Schema: operacao; Owner: -
--

COPY operacao.registro_anormalidade (id, registro_id, data, sala_id, nome_evento, hora_inicio_anormalidade, descricao_anormalidade, houve_prejuizo, descricao_prejuizo, houve_reclamacao, autores_conteudo_reclamacao, acionou_manutencao, hora_acionamento_manutencao, resolvida_pelo_operador, procedimentos_adotados, data_solucao, hora_solucao, responsavel_evento, criado_por, criado_em, atualizado_em, atualizado_por, entrada_id) FROM stdin;
1	4	2026-03-03	3	4° reunião da CMMPV n° 1323	15:12:00	Zoom 01 desconectou por 2 vezes e o PC foi reiniciado, porém voltou muito lento e apresentando travamentos. Fica registrado para que haja revisão por parte dos técnicos.	f	\N	f	\N	f	\N	t	Reinicio do sistema.	\N	\N	Rodrigo Ribeiro Bedritichuk	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	2026-03-03 20:16:30.012182+00	2026-03-03 20:16:30.012182+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	4
\.


--
-- Data for Name: registro_anormalidade_admin; Type: TABLE DATA; Schema: operacao; Owner: -
--

COPY operacao.registro_anormalidade_admin (registro_anormalidade_id, observacao_supervisor, observacao_chefe, criado_por, criado_em, atualizado_por, atualizado_em) FROM stdin;
\.


--
-- Data for Name: registro_operacao_audio; Type: TABLE DATA; Schema: operacao; Owner: -
--

COPY operacao.registro_operacao_audio (id, data, sala_id, criado_em, criado_por, em_aberto, fechado_em, fechado_por, checklist_do_dia_id, checklist_do_dia_ok) FROM stdin;
1	2026-03-03	9	2026-03-03 14:14:31.669631+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f	2026-03-03 14:14:31.669631+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	9	f
2	2026-03-03	10	2026-03-03 15:20:30.458075+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	2026-03-03 15:20:30.458075+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	8	t
3	2026-03-03	6	2026-03-03 18:17:24.707586+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	f	2026-03-03 18:17:24.707586+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	17	t
4	2026-03-03	3	2026-03-03 20:12:57.313138+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	f	2026-03-03 20:12:57.313138+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	16	t
5	2026-03-03	4	2026-03-03 21:24:24.588009+00	67406c3d-e3c9-423f-a140-b68bf71178f6	f	2026-03-03 21:24:24.588009+00	67406c3d-e3c9-423f-a140-b68bf71178f6	11	t
6	2026-03-04	6	2026-03-04 13:32:55.630144+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	f	2026-03-04 13:32:55.630144+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	26	t
7	2026-03-04	7	2026-03-04 13:40:08.574583+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f	2026-03-04 13:40:08.574583+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	24	t
8	2026-03-04	8	2026-03-04 14:12:10.662796+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	2026-03-04 14:12:10.662796+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	23	f
9	2026-03-04	4	2026-03-04 14:16:56.797277+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	2026-03-04 14:16:56.797277+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	25	t
10	2026-03-04	5	2026-03-04 15:22:46.43536+00	5003b79d-150a-49b0-b506-3f4cc273d496	f	2026-03-04 15:22:46.43536+00	5003b79d-150a-49b0-b506-3f4cc273d496	27	t
11	2026-03-04	3	2026-03-04 15:49:09.339672+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	f	2026-03-04 16:14:28.905962+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	21	t
12	2026-03-04	6	2026-03-04 19:30:38.720163+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	f	2026-03-04 19:30:38.720163+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	28	t
13	2026-03-05	6	2026-03-05 15:43:32.785391+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	f	2026-03-05 15:43:32.785391+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	39	t
14	2026-03-05	4	2026-03-05 16:23:50.158941+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f	2026-03-05 16:23:50.158941+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	38	t
15	2026-03-06	3	2026-03-06 14:52:14.420891+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	f	2026-03-06 15:29:17.483881+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	\N	\N
16	2026-03-09	3	2026-03-09 15:50:13.56453+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f	2026-03-09 16:31:30.749707+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	55	t
\.


--
-- Data for Name: registro_operacao_operador; Type: TABLE DATA; Schema: operacao; Owner: -
--

COPY operacao.registro_operacao_operador (id, registro_id, operador_id, ordem, hora_entrada, hora_saida, criado_em, atualizado_em, criado_por, atualizado_por, seq, usb_01, usb_02, observacoes, houve_anormalidade, nome_evento, horario_pauta, horario_inicio, horario_termino, tipo_evento, comissao_id, responsavel_evento, editado, observacoes_editado, nome_evento_editado, responsavel_evento_editado, horario_pauta_editado, horario_inicio_editado, horario_termino_editado, usb_01_editado, usb_02_editado, comissao_editado, sala_editado) FROM stdin;
1	1	fa1eadbf-e6c4-47e8-bdbc-c15338679270	1	\N	\N	2026-03-03 14:14:31.669631+00	2026-03-03 14:14:31.669631+00	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fa1eadbf-e6c4-47e8-bdbc-c15338679270	1	047/059	047/059	\N	f	Reunião Ordinária	10:00:00	10:11:00	11:10:00	operacao	10	Secretaria	f	f	f	f	f	f	f	f	f	f	f
2	2	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	1	\N	\N	2026-03-03 15:20:30.458075+00	2026-03-03 15:20:30.458075+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	1	083 107	083 107	\N	f	06ª Reunião	10:00:00	10:17:00	12:16:00	operacao	1	SGM	f	f	f	f	f	f	f	f	f	f	f
3	3	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	1	\N	\N	2026-03-03 18:17:24.707586+00	2026-03-03 18:17:24.707586+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	1	232/234	208/210	\N	f	1ª reunião CMMPV 1326/2025	14:30:00	14:46:00	15:10:00	operacao	27	Mariana de Abreu Cobra Lima	f	f	f	f	f	f	f	f	f	f	f
4	4	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	1	\N	\N	2026-03-03 20:12:57.313138+00	2026-03-03 20:16:30.012182+00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	1	663-694	663-694	\N	t	4° reunião da CMMPV n° 1323	14:00:00	14:15:00	16:49:00	operacao	27	Rodrigo Ribeiro Bedritichuk	f	f	f	f	f	f	f	f	f	f	f
5	5	67406c3d-e3c9-423f-a140-b68bf71178f6	1	\N	\N	2026-03-03 21:24:24.588009+00	2026-03-03 21:24:24.588009+00	67406c3d-e3c9-423f-a140-b68bf71178f6	67406c3d-e3c9-423f-a140-b68bf71178f6	1	003	003	\N	f	Reunião de Sala da Senadora Eudócia.	15:00:00	15:40:00	18:15:00	cessao	26	Senadora Eudócia.	f	f	f	f	f	f	f	f	f	f	f
6	6	01bc609b-dddb-4704-96b1-50f7bd2ce359	1	\N	\N	2026-03-04 13:32:55.630144+00	2026-03-04 13:32:55.630144+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	1	236/236	212/212	\N	f	3ª Reunião	10:00:00	10:16:00	10:26:00	operacao	5	Leomar Diniz	f	f	f	f	f	f	f	f	f	f	f
7	7	b00be980-b976-4c4a-a96e-eeb67baf6b8d	1	\N	\N	2026-03-04 13:40:08.574583+00	2026-03-04 13:40:08.574583+00	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b00be980-b976-4c4a-a96e-eeb67baf6b8d	1	018/031	018/031	Sessão pausada 9h35 - trilha 020\n\nRetorno 9h39 - trilha 021	f	3ª Extraordinária Deliberativa	09:00:00	09:29:00	10:34:00	operacao	2	SGM	f	f	f	f	f	f	f	f	f	f	f
8	8	45af4b4e-a691-4c9e-a390-8fec54c43a30	1	\N	\N	2026-03-04 14:12:10.662796+00	2026-03-04 14:12:10.662796+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	1	042	042	\N	f	1a Reunião	10:00:00	10:20:00	11:00:00	operacao	11	Sec Flávio	f	f	f	f	f	f	f	f	f	f	f
9	9	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	1	\N	\N	2026-03-04 14:16:56.797277+00	2026-03-04 14:16:56.797277+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	1	05	05	\N	f	1° reunião extraordinária, semipresencial	09:00:00	09:15:00	11:12:00	operacao	4	Secretário do Comissão	f	f	f	f	f	f	f	f	f	f	f
10	10	5003b79d-150a-49b0-b506-3f4cc273d496	1	\N	\N	2026-03-04 15:22:46.43536+00	2026-03-04 15:22:46.43536+00	5003b79d-150a-49b0-b506-3f4cc273d496	5003b79d-150a-49b0-b506-3f4cc273d496	1	Não houve gravação	Não houve gravação	Foi reproduzido vídeo durante toda a cessão.	f	Filme Abdias - RP	\N	10:59:00	12:14:00	cessao	26	Aline Krettlei	f	f	f	f	f	f	f	f	f	f	f
11	11	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	1	\N	\N	2026-03-04 15:49:09.339672+00	2026-03-04 15:49:09.339672+00	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	1	750	750	Troca operador 12:40	f	8 Reunião	11:07:00	12:40:00	\N	operacao	7	Dimitri	f	f	f	f	f	f	f	f	f	f	f
12	11	42fb063e-09f0-4d5a-8dd2-47757dae7656	2	\N	\N	2026-03-04 16:14:28.905962+00	2026-03-04 16:14:28.905962+00	42fb063e-09f0-4d5a-8dd2-47757dae7656	42fb063e-09f0-4d5a-8dd2-47757dae7656	1	750/774	750/774	\N	f	8 Reunião	11:00:00	11:07:00	13:04:00	operacao	7	Dimitri	f	f	f	f	f	f	f	f	f	f	f
13	12	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	1	\N	\N	2026-03-04 19:30:38.720163+00	2026-03-04 20:04:13.286977+00	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	1	260/264	236/240	VIP ficou sem sinal de 14:27 até 14:34.\nOuve uso do microfone sem fio e uma das baterias está na base para carregar.	f	3ª Reunião da CRA	14:00:00	14:23:00	16:16:00	operacao	14	Pedro Glucas	f	f	f	f	f	f	f	f	f	f	f
14	13	01bc609b-dddb-4704-96b1-50f7bd2ce359	1	\N	\N	2026-03-05 15:43:32.785391+00	2026-03-05 15:43:32.785391+00	01bc609b-dddb-4704-96b1-50f7bd2ce359	01bc609b-dddb-4704-96b1-50f7bd2ce359	1	281/283	260/261	Operadora Katiane, me auxiliou.	f	9ª Reunião	10:08:00	10:30:00	12:38:00	operacao	7	Dimitri Martin	f	f	f	f	f	f	f	f	f	f	f
15	14	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	1	\N	\N	2026-03-05 16:23:50.158941+00	2026-03-05 16:23:50.158941+00	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	1	06	06	\N	f	11° reunião da CTCivil	10:00:00	10:12:00	13:19:00	operacao	25	Secretário	f	f	f	f	f	f	f	f	f	f	f
16	15	45af4b4e-a691-4c9e-a390-8fec54c43a30	1	\N	\N	2026-03-06 14:52:14.420891+00	2026-03-06 14:52:14.420891+00	45af4b4e-a691-4c9e-a390-8fec54c43a30	45af4b4e-a691-4c9e-a390-8fec54c43a30	1	\N	\N	Troca operador 11:40	f	Gestão e Governança estratégia	09:00:00	09:01:00	\N	operacao	27	Junia RP	f	f	f	f	f	f	f	f	f	f	f
17	15	889e347c-4498-4bd3-bf60-6e54a09dd05c	2	\N	\N	2026-03-06 15:29:17.483881+00	2026-03-06 15:29:17.483881+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	1	825/862	825/862	\N	f	Gestão e Governança estratégia	09:00:00	09:01:00	12:06:00	operacao	27	Junia RP	f	f	f	f	f	f	f	f	f	f	f
18	16	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	1	\N	\N	2026-03-09 15:50:13.56453+00	2026-03-09 15:50:13.56453+00	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	1	29	29	Troca de operados as 12:40	f	10ª Reunião	10:00:00	10:10:00	\N	operacao	7	SGM	f	f	f	f	f	f	f	f	f	f	f
19	16	889e347c-4498-4bd3-bf60-6e54a09dd05c	2	\N	\N	2026-03-09 16:31:30.749707+00	2026-03-09 16:31:30.749707+00	889e347c-4498-4bd3-bf60-6e54a09dd05c	889e347c-4498-4bd3-bf60-6e54a09dd05c	1	029/067	029/067	\N	f	10ª Reunião	10:00:00	10:10:00	13:22:00	operacao	7	SGM	f	f	f	f	f	f	f	f	f	f	f
\.


--
-- Data for Name: registro_operacao_operador_historico; Type: TABLE DATA; Schema: operacao; Owner: -
--

COPY operacao.registro_operacao_operador_historico (id, entrada_id, snapshot, editado_por, editado_em) FROM stdin;
\.


--
-- Data for Name: administrador; Type: TABLE DATA; Schema: pessoa; Owner: -
--

COPY pessoa.administrador (id, nome_completo, email, username, password_hash, criado_em, atualizado_em) FROM stdin;
b6659aab-4945-4c46-a5b0-8a1fb312fa88	Evandro Batista Martins de Pinho	evandrop@senado.leg.br	evandrop	$2b$12$u99NiobxWPPOll8xE552hOSzo8e5T2JMaGKfDnprM1WM7e62gkGCq	2025-12-01 13:17:50.522482+00	2025-12-01 13:17:50.522482+00
a75a7887-0e17-4786-80cb-b345788be6a0	emmanuel gomes bezerra	emanoel@senado.leg.br	emanoel	$2b$12$JPu5oSaLr/J5..oZgm7Oj.haASj8R9mLfI0U6zIVyjO5ImDJw6BZi	2025-12-08 12:44:54.685849+00	2025-12-08 12:44:54.685849+00
1391b9e1-b006-4d9c-8c63-e39421079ca2	Douglas Antunes dos Santos	douglas.antunes@senado.leg.br	douglas.antunes	$2b$12$rFbJIME9FuQSe5tqiGhF9OVmFMWk7CBdC/7./7wzqukAegEFAMLOK	2025-10-30 19:59:14.028375+00	2026-02-24 17:29:33.100361+00
\.


--
-- Data for Name: administrador_s; Type: TABLE DATA; Schema: pessoa; Owner: -
--

COPY pessoa.administrador_s (id, nome_completo, email, username, senha, ativo, criado_em, atualizado_em) FROM stdin;
\.


--
-- Data for Name: auth_sessions; Type: TABLE DATA; Schema: pessoa; Owner: -
--

COPY pessoa.auth_sessions (id, user_id, refresh_token_hash, created_at, last_activity, revoked) FROM stdin;
44	fa1eadbf-e6c4-47e8-bdbc-c15338679270	fd05713e2bfb96927edca0f326587387	2026-02-25 16:53:09.326345+00	2026-02-25 16:53:19.889186+00	f
3	1391b9e1-b006-4d9c-8c63-e39421079ca2	e239eafdfeb93b3db5c63f50b34db3c9	2026-02-24 17:41:40.344835+00	2026-02-24 17:42:59.904806+00	t
11	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	5a4e97aab5db7ad1edfa775344461a70	2026-02-25 12:42:44.280541+00	2026-02-25 12:43:01.108956+00	t
52	45af4b4e-a691-4c9e-a390-8fec54c43a30	bc77f170715281189bb776a817edeca7	2026-03-02 11:27:12.566401+00	2026-03-02 11:48:33.343773+00	t
30	1391b9e1-b006-4d9c-8c63-e39421079ca2	7c90d8fd8ca909bd3040f511b23df444	2026-02-25 14:23:42.442264+00	2026-02-25 14:27:51.032855+00	f
19	5003b79d-150a-49b0-b506-3f4cc273d496	c3c755a455d512eea8336ed10800db5c	2026-02-25 13:31:31.634923+00	2026-02-25 13:31:32.615717+00	f
12	889e347c-4498-4bd3-bf60-6e54a09dd05c	b72e4ca75f51a5e9a1aab5120b736a2e	2026-02-25 12:46:48.513788+00	2026-02-25 12:46:49.590626+00	f
4	1391b9e1-b006-4d9c-8c63-e39421079ca2	82581d9b694460772a856c43e44ce3b7	2026-02-24 17:53:08.713166+00	2026-02-24 17:54:35.112198+00	t
16	6f0c0764-f458-4c71-b6dc-8ea25f01c12f	cc564c32111561c2e1835489993e0eb0	2026-02-25 13:11:45.514851+00	2026-02-25 13:11:46.580633+00	f
10	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	70837c6a355b0a3550a67384ad07f394	2026-02-25 12:40:32.473236+00	2026-02-25 12:48:24.85171+00	t
24	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5c39372eaeb23d9951b084ec3e0f8275	2026-02-25 13:41:43.186072+00	2026-02-25 13:41:43.484411+00	f
5	ed8276ee-ee75-41b1-bc5e-b5bd6f0cde95	ad1fedcd460488ca1c4052cf38325fb7	2026-02-24 17:54:47.39162+00	2026-02-24 17:54:57.017398+00	f
37	3135733f-8d6a-4ac8-9cb0-c34002ae823c	c515c878a6d253680d64e36c61f0821a	2026-02-25 16:07:04.793257+00	2026-02-25 16:14:31.624474+00	f
1	1391b9e1-b006-4d9c-8c63-e39421079ca2	e9a052ba7ca7dce3995a8107d69b67a4	2026-02-20 21:17:59.414456+00	2026-02-20 21:18:39.305097+00	t
36	1793be06-d86d-4b3b-a72f-3de0fe072c61	80f335a91e6524a1e78a45a66cd33919	2026-02-25 16:01:59.36739+00	2026-02-25 16:02:25.549241+00	t
17	b00be980-b976-4c4a-a96e-eeb67baf6b8d	8a8c560385fc54fcf6dd59d423d27d01	2026-02-25 13:14:40.820401+00	2026-02-25 13:15:12.754478+00	t
49	1391b9e1-b006-4d9c-8c63-e39421079ca2	7d1df5ec675276c9dae06a98fde782da	2026-03-01 22:59:33.109539+00	2026-03-01 22:59:37.361734+00	t
48	1391b9e1-b006-4d9c-8c63-e39421079ca2	b8672b2a60d4723523e5ae721dad4c6f	2026-03-01 22:34:14.877952+00	2026-03-01 22:34:30.013263+00	t
6	ed8276ee-ee75-41b1-bc5e-b5bd6f0cde95	06f26dc24219cfb65d73e8521694c492	2026-02-24 20:04:58.737839+00	2026-02-24 20:05:03.052273+00	f
13	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	4bc22dd21f3fe594073876c713281ca7	2026-02-25 12:51:56.64789+00	2026-02-25 12:53:03.274156+00	t
22	a75a7887-0e17-4786-80cb-b345788be6a0	36ef063aeb4164b5ff8e4745bf287a37	2026-02-25 13:36:36.65172+00	2026-02-25 14:07:48.442237+00	f
2	1391b9e1-b006-4d9c-8c63-e39421079ca2	959aca14d96ddb19b7b70d64462ebd70	2026-02-20 21:22:21.828355+00	2026-02-20 21:22:31.516376+00	f
25	fa1eadbf-e6c4-47e8-bdbc-c15338679270	f0ccd497a35d2af9832b4580f1831708	2026-02-25 13:44:34.53565+00	2026-02-25 13:44:52.673993+00	t
40	a75a7887-0e17-4786-80cb-b345788be6a0	95de0201b4a67c2c6bbef0fd6b775627	2026-02-25 16:31:07.062817+00	2026-02-25 16:31:09.050379+00	t
34	1391b9e1-b006-4d9c-8c63-e39421079ca2	f0eee21209b0a99fd4f12e61902ae230	2026-02-25 15:39:08.582241+00	2026-02-25 15:39:11.855716+00	f
20	a75a7887-0e17-4786-80cb-b345788be6a0	a934fcdd2ba4ae6043a26417636a2fe8	2026-02-25 13:35:50.489382+00	2026-02-25 13:36:25.834099+00	t
15	1391b9e1-b006-4d9c-8c63-e39421079ca2	a86c734a017f51b38ce69b799cc52f35	2026-02-25 13:09:22.923727+00	2026-02-25 13:24:37.499556+00	t
7	1391b9e1-b006-4d9c-8c63-e39421079ca2	e5084bb4568ef139a9701f615117bebc	2026-02-24 20:05:30.251873+00	2026-02-24 20:06:09.270342+00	f
8	1391b9e1-b006-4d9c-8c63-e39421079ca2	c3c76f4d059e856d4d05b855070a6603	2026-02-25 11:57:54.282604+00	2026-02-25 12:40:07.440479+00	t
35	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	069c67e88aad5d28485896fb0fe9e0f4	2026-02-25 15:42:35.240425+00	2026-02-25 15:42:48.842977+00	f
43	1391b9e1-b006-4d9c-8c63-e39421079ca2	346a5544170ce0388d3d2448486c7f93	2026-02-25 16:33:49.143481+00	2026-02-25 17:06:05.714256+00	f
56	1391b9e1-b006-4d9c-8c63-e39421079ca2	fb691ec5b4dc7fb5831c2ee78dc65e0e	2026-03-02 12:47:38.004368+00	2026-03-02 12:48:13.571412+00	f
51	45af4b4e-a691-4c9e-a390-8fec54c43a30	184c65f31cc1c8f3696661d84fa5d882	2026-03-02 10:47:35.654516+00	2026-03-02 10:53:39.091555+00	t
28	47aaf03e-c760-40ab-9df1-5aa7e76260a6	4c1581ae1c01149a3c3be1ab190f0c4a	2026-02-25 14:09:13.090587+00	2026-02-25 14:11:26.832734+00	f
9	a75a7887-0e17-4786-80cb-b345788be6a0	489db33c68f72b63e9fa16a8f7360bb6	2026-02-25 12:30:59.448018+00	2026-02-25 13:28:35.617654+00	f
14	6f0c0764-f458-4c71-b6dc-8ea25f01c12f	be82d754e3342c36543861444ebf1cc7	2026-02-25 13:08:40.484625+00	2026-02-25 13:08:46.704578+00	t
21	a75a7887-0e17-4786-80cb-b345788be6a0	3ceb3c2a265c08461062427ae1cb92ed	2026-02-25 13:36:28.13663+00	2026-02-25 13:36:32.545794+00	t
26	45af4b4e-a691-4c9e-a390-8fec54c43a30	c57f3fa905764ea75332ea4e7acec7ba	2026-02-25 13:58:38.11433+00	2026-02-25 14:00:18.010584+00	f
27	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	340cc3a7307eacf6f8507a410d05ae79	2026-02-25 14:07:52.253621+00	2026-02-25 14:11:36.248687+00	t
23	1391b9e1-b006-4d9c-8c63-e39421079ca2	569880612d8b140c54dc482acdc529e8	2026-02-25 13:37:30.395097+00	2026-02-25 13:38:31.693111+00	t
18	1391b9e1-b006-4d9c-8c63-e39421079ca2	225443b106d417c2b05852a8e0fa1e8f	2026-02-25 13:25:10.140202+00	2026-02-25 13:37:16.249979+00	t
41	a75a7887-0e17-4786-80cb-b345788be6a0	548a9b61026cb24dc99ead55cd7da202	2026-02-25 16:31:12.931721+00	2026-02-25 16:32:46.025576+00	f
38	67406c3d-e3c9-423f-a140-b68bf71178f6	0519489236126babcdd1e00c317dfa83	2026-02-25 16:18:07.89899+00	2026-02-25 16:18:08.481782+00	f
29	47aaf03e-c760-40ab-9df1-5aa7e76260a6	a52f3f99091c178f492d56ce4e68638c	2026-02-25 14:15:26.818069+00	2026-02-25 14:15:34.092099+00	f
33	42fb063e-09f0-4d5a-8dd2-47757dae7656	08fd2a5745ae39ff0ca7943ab81c62b9	2026-02-25 15:37:08.671605+00	2026-02-25 15:37:08.96426+00	f
55	1391b9e1-b006-4d9c-8c63-e39421079ca2	1ac079e468666af836b1bece1d061fff	2026-03-02 11:58:35.538941+00	2026-03-02 12:53:47.338819+00	t
45	fa1eadbf-e6c4-47e8-bdbc-c15338679270	cbfa8539cef70d565c4e0c4035dd9cc6	2026-02-28 21:36:35.359144+00	2026-02-28 21:37:31.273265+00	f
39	1391b9e1-b006-4d9c-8c63-e39421079ca2	ab76a6a8bec79a0dc6491ce17b777e28	2026-02-25 16:24:00.342411+00	2026-02-25 16:28:56.200002+00	t
31	a75a7887-0e17-4786-80cb-b345788be6a0	25767c45b27726d89125d06488cf4897	2026-02-25 15:29:36.511332+00	2026-02-25 16:29:14.626139+00	f
32	1391b9e1-b006-4d9c-8c63-e39421079ca2	7cdde6ebbd106476fafcc73823c51c17	2026-02-25 15:32:59.876474+00	2026-02-25 16:23:58.315501+00	t
42	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	1637cc28d18550a4d5a3036350640098	2026-02-25 16:33:26.683264+00	2026-02-25 17:29:57.900212+00	f
47	1391b9e1-b006-4d9c-8c63-e39421079ca2	5e66994978a9b4581ddc2efd00813dd5	2026-03-01 22:11:57.596728+00	2026-03-01 22:12:08.463024+00	t
54	a75a7887-0e17-4786-80cb-b345788be6a0	bf96708587bdf66266b83a5574cb1bdb	2026-03-02 11:50:17.698437+00	2026-03-02 12:22:35.661042+00	f
57	5003b79d-150a-49b0-b506-3f4cc273d496	091d53a97e512f7910f39397f77ae7e6	2026-03-02 12:53:28.732192+00	2026-03-02 13:06:54.629036+00	t
46	1391b9e1-b006-4d9c-8c63-e39421079ca2	b66d33497c3a3b88bcdfe9ef6e88957c	2026-03-01 21:51:43.023087+00	2026-03-01 21:51:50.412288+00	f
50	5003b79d-150a-49b0-b506-3f4cc273d496	2b94540859e206ce36a549c4a58d9487	2026-03-02 09:58:26.325597+00	2026-03-02 09:59:27.112624+00	f
53	1391b9e1-b006-4d9c-8c63-e39421079ca2	c8d03c2a3affad93dd113917dcb3bda6	2026-03-02 11:42:28.028928+00	2026-03-02 11:42:44.249028+00	t
61	fa1eadbf-e6c4-47e8-bdbc-c15338679270	6d7b6012b271d26687a78b83d08e09c6	2026-03-02 13:26:35.917312+00	2026-03-02 13:46:34.659958+00	t
59	5003b79d-150a-49b0-b506-3f4cc273d496	3609e57ec1902b447f59a8770a2d8004	2026-03-02 13:10:01.891474+00	2026-03-02 13:10:26.185094+00	f
60	b00be980-b976-4c4a-a96e-eeb67baf6b8d	c34b45a7c0d3e2e2c7a303e40a88dbfd	2026-03-02 13:14:21.796027+00	2026-03-02 13:32:03.783701+00	t
58	a75a7887-0e17-4786-80cb-b345788be6a0	8db6f9a65ee749681e7eb3112d250ec6	2026-03-02 12:53:30.046031+00	2026-03-02 13:51:46.823965+00	f
62	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	4611cd07906867f369fe3db2c19667eb	2026-03-02 13:51:56.278432+00	2026-03-02 14:04:48.454627+00	f
66	a75a7887-0e17-4786-80cb-b345788be6a0	df07f5aac0303f332b40f8cc727d55a2	2026-03-02 14:07:26.995226+00	2026-03-02 14:48:58.611671+00	t
63	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	d8bff3932ec4123ebb83a562b4496ce3	2026-03-02 13:52:45.049691+00	2026-03-02 14:15:42.491935+00	t
65	fa1eadbf-e6c4-47e8-bdbc-c15338679270	91fc42e06b65f4a3437b667e1d784d5d	2026-03-02 13:56:58.317763+00	2026-03-02 13:57:01.514052+00	f
88	1391b9e1-b006-4d9c-8c63-e39421079ca2	6896f9fabb3b9fb7a24961b70b034c30	2026-03-03 10:01:27.112639+00	2026-03-03 10:45:15.780477+00	f
100	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	3db52cc6a31bf6f4dba32c21be74bd7b	2026-03-03 12:44:48.480832+00	2026-03-03 12:44:58.47126+00	f
70	1391b9e1-b006-4d9c-8c63-e39421079ca2	7004f40a8213db20d6ad37e37ae5d1b2	2026-03-02 14:50:51.714325+00	2026-03-02 14:50:58.409149+00	t
110	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	ba724577eca8480bb0eb3f1e8c3c70af	2026-03-03 15:58:11.353017+00	2026-03-03 15:59:30.959321+00	f
78	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	f3c3e37bd0eb1258fa933a46075a4da5	2026-03-02 17:44:53.363191+00	2026-03-02 17:55:50.247566+00	f
125	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	1b3b6450a674df9318391121075b1b9f	2026-03-03 20:07:34.93612+00	2026-03-03 20:16:59.222856+00	f
118	a75a7887-0e17-4786-80cb-b345788be6a0	43ad45d0a9d97497510da5f45dc6679a	2026-03-03 17:26:44.689574+00	2026-03-03 17:35:13.30592+00	f
86	fa1eadbf-e6c4-47e8-bdbc-c15338679270	eaec3b31779030173ff2c01e4ec060d0	2026-03-03 09:51:17.649048+00	2026-03-03 10:37:22.890048+00	f
79	3135733f-8d6a-4ac8-9cb0-c34002ae823c	a7b9cd73400fc32ad6bc8679e37c908b	2026-03-02 18:04:02.457306+00	2026-03-02 18:24:00.860572+00	f
76	1391b9e1-b006-4d9c-8c63-e39421079ca2	11297564aaaef1c4a93682623c9ec76b	2026-03-02 17:11:23.556362+00	2026-03-02 17:58:55.127445+00	t
68	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	31a7842c31126b2d3e9655e2a2e689e7	2026-03-02 14:29:11.99082+00	2026-03-02 14:31:40.706168+00	f
64	1391b9e1-b006-4d9c-8c63-e39421079ca2	fdd5d019c9f79e683e79a6c031f263ef	2026-03-02 13:56:31.254509+00	2026-03-02 14:25:19.126311+00	t
114	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	846f9b5f630d30d82ffd4158b041abb3	2026-03-03 16:29:30.12824+00	2026-03-03 16:30:45.313232+00	f
81	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	365214438c3ea8915c3cf941e90b86fc	2026-03-02 18:21:45.915654+00	2026-03-02 18:25:19.207304+00	f
117	1391b9e1-b006-4d9c-8c63-e39421079ca2	6fa949df707ba63e388e0cd365db52ca	2026-03-03 16:39:28.457593+00	2026-03-03 17:36:31.40823+00	f
73	a75a7887-0e17-4786-80cb-b345788be6a0	4bef7c49db36ca52a927db6fde6b77f9	2026-03-02 16:22:14.491441+00	2026-03-02 16:23:33.374602+00	t
85	1391b9e1-b006-4d9c-8c63-e39421079ca2	612fc37d3bf034d91dac57e67c3e2dc1	2026-03-03 02:02:34.470989+00	2026-03-03 02:02:37.386094+00	f
71	1391b9e1-b006-4d9c-8c63-e39421079ca2	2c28386c2764b3ea6bba822197a39cc5	2026-03-02 14:51:48.203999+00	2026-03-02 14:51:56.517058+00	f
67	1391b9e1-b006-4d9c-8c63-e39421079ca2	df800d85f3ee45a3b21432e8e477da0b	2026-03-02 14:26:39.516289+00	2026-03-02 14:47:34.229693+00	f
101	1391b9e1-b006-4d9c-8c63-e39421079ca2	24a7df0f82f49d794f801fb146b3d8b7	2026-03-03 12:49:13.507125+00	2026-03-03 13:39:15.700274+00	f
83	a75a7887-0e17-4786-80cb-b345788be6a0	e67ccc70ccadcff51a394bfd4ac5feac	2026-03-02 18:36:14.054566+00	2026-03-02 18:39:53.43358+00	t
82	1391b9e1-b006-4d9c-8c63-e39421079ca2	7b0be70e77f0eaf79163b21f2664ba83	2026-03-02 18:27:20.147272+00	2026-03-02 18:27:20.576057+00	f
99	1391b9e1-b006-4d9c-8c63-e39421079ca2	2e4cf7f80058086442d8742e58b4a409	2026-03-03 12:17:09.907528+00	2026-03-03 12:18:14.961322+00	t
108	1391b9e1-b006-4d9c-8c63-e39421079ca2	49599674d03fe60c1773ab432cb92309	2026-03-03 15:55:46.260926+00	2026-03-03 16:00:53.922639+00	t
77	42fb063e-09f0-4d5a-8dd2-47757dae7656	1a96a9ae36765704f114fb738cf7b8df	2026-03-02 17:20:58.931462+00	2026-03-02 17:37:48.267638+00	f
95	a75a7887-0e17-4786-80cb-b345788be6a0	8a39f1fd181dce233503eb80e1ffa5c3	2026-03-03 11:53:04.486822+00	2026-03-03 11:54:03.46395+00	f
69	1391b9e1-b006-4d9c-8c63-e39421079ca2	61eba4908a7f5ab7858136936e61130b	2026-03-02 14:49:39.810375+00	2026-03-02 14:50:04.969568+00	t
72	1391b9e1-b006-4d9c-8c63-e39421079ca2	da389c1babb02389989e2fb851ce12d0	2026-03-02 14:56:52.129851+00	2026-03-02 14:59:17.293289+00	t
75	1793be06-d86d-4b3b-a72f-3de0fe072c61	9b24f69f0e377a08040726e570b3ba63	2026-03-02 16:57:03.427115+00	2026-03-02 17:02:06.335125+00	f
91	1391b9e1-b006-4d9c-8c63-e39421079ca2	80d00abe4fa9fbb262c1dddaf73cc709	2026-03-03 10:53:46.499042+00	2026-03-03 11:34:46.981283+00	f
74	1391b9e1-b006-4d9c-8c63-e39421079ca2	a683291c0a09cb5493ea08d8656e5fa4	2026-03-02 16:55:29.078339+00	2026-03-02 17:11:20.247874+00	t
104	fa1eadbf-e6c4-47e8-bdbc-c15338679270	a7c048216b592187623d69785812c6af	2026-03-03 14:10:46.656873+00	2026-03-03 14:14:35.910477+00	f
89	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	8fc71f259ee3eb4058296c51ee8796f1	2026-03-03 10:07:28.892814+00	2026-03-03 10:08:41.544865+00	f
97	1391b9e1-b006-4d9c-8c63-e39421079ca2	609349d0d978003ec7cd144c42dd1fca	2026-03-03 12:08:50.527525+00	2026-03-03 12:11:39.965116+00	f
98	01bc609b-dddb-4704-96b1-50f7bd2ce359	abf80ee81d0fe3c4dff5104b0f3349d0	2026-03-03 12:13:12.803283+00	2026-03-03 12:40:51.280255+00	f
94	fa1eadbf-e6c4-47e8-bdbc-c15338679270	1d7d168bc93b1d2980ccb830e288ab0f	2026-03-03 11:41:42.92678+00	2026-03-03 11:41:45.819369+00	f
87	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	94d22593d70b7b30da528c54f4b17469	2026-03-03 09:58:45.792579+00	2026-03-03 10:16:17.578837+00	f
84	1391b9e1-b006-4d9c-8c63-e39421079ca2	21150f150df891cbdc54b97553577521	2026-03-03 02:01:46.041381+00	2026-03-03 02:02:13.165006+00	t
80	1793be06-d86d-4b3b-a72f-3de0fe072c61	929af8a696ac70824eb25062ab8c7f77	2026-03-02 18:13:03.928329+00	2026-03-02 18:22:42.574764+00	f
102	1391b9e1-b006-4d9c-8c63-e39421079ca2	2a12babc8f848dd3654cc4b9ac687a03	2026-03-03 14:02:46.388024+00	2026-03-03 14:06:43.52073+00	t
92	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	d03f369a0fbf81e1bd35aa6bafa25c00	2026-03-03 11:05:19.579264+00	2026-03-03 11:13:34.520479+00	f
105	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	ccd85bd3046f0556eca8a530b427a8a8	2026-03-03 14:24:26.250225+00	2026-03-03 14:30:57.460476+00	f
96	5003b79d-150a-49b0-b506-3f4cc273d496	8a962b7bf9f39afc5b34b384b2efecb7	2026-03-03 11:56:58.466707+00	2026-03-03 12:00:07.219225+00	f
93	b00be980-b976-4c4a-a96e-eeb67baf6b8d	a41eeb9f9393a09cfaf8473103739b92	2026-03-03 11:26:49.166109+00	2026-03-03 11:48:25.305339+00	f
90	45af4b4e-a691-4c9e-a390-8fec54c43a30	c4bfbd2f43df44b05b48bb0cf576b0b8	2026-03-03 10:39:16.763617+00	2026-03-03 11:25:20.50257+00	f
115	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	fb4d88a9dc9336fe37320decc1890696	2026-03-03 16:30:18.495237+00	2026-03-03 16:36:06.934706+00	f
103	1391b9e1-b006-4d9c-8c63-e39421079ca2	3ecf4ee69d9a6fefa43fa23db6cf9cab	2026-03-03 14:06:45.24443+00	2026-03-03 14:27:10.841102+00	f
113	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	166fdb1ac004143113cfb97cc634f908	2026-03-03 16:12:11.516526+00	2026-03-03 16:14:23.555021+00	f
107	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	8aed41c75572965a8bacd97daf10c69e	2026-03-03 15:18:37.479573+00	2026-03-03 15:55:51.703817+00	f
106	1391b9e1-b006-4d9c-8c63-e39421079ca2	367b2ec67c712be367e0352448a21df9	2026-03-03 15:10:16.39297+00	2026-03-03 15:10:36.116254+00	t
112	889e347c-4498-4bd3-bf60-6e54a09dd05c	c818ece693cd7b047315be5988c77946	2026-03-03 16:09:50.878459+00	2026-03-03 16:29:36.470722+00	t
121	67406c3d-e3c9-423f-a140-b68bf71178f6	0dd68c84cead6b47c81e8a32b42aa756	2026-03-03 17:56:36.937555+00	2026-03-03 18:00:06.617711+00	f
109	1391b9e1-b006-4d9c-8c63-e39421079ca2	9b6858f064bafcc5715fd306386ec86c	2026-03-03 15:57:41.52479+00	2026-03-03 15:57:41.52479+00	f
126	67406c3d-e3c9-423f-a140-b68bf71178f6	3924c17ee85b9c54c62ad331109659fd	2026-03-03 21:20:53.677065+00	2026-03-03 21:24:27.864419+00	f
123	3135733f-8d6a-4ac8-9cb0-c34002ae823c	1aa4bd08dad9f85818cc3ecc8b821ab4	2026-03-03 18:46:54.891729+00	2026-03-03 18:56:35.148585+00	f
116	42fb063e-09f0-4d5a-8dd2-47757dae7656	665df587059432b141713d8fb346dfc5	2026-03-03 16:35:54.240137+00	2026-03-03 16:37:25.571064+00	f
119	1391b9e1-b006-4d9c-8c63-e39421079ca2	9e342bab95a2c483362beeb9f2214da9	2026-03-03 17:40:04.631369+00	2026-03-03 17:50:48.385859+00	t
111	1391b9e1-b006-4d9c-8c63-e39421079ca2	7f4e563b355e6efd76cb2bcb0420ba75	2026-03-03 16:07:31.558799+00	2026-03-03 16:39:26.260558+00	t
122	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	b5aeadeb7608676abd1da12b6ca9c596	2026-03-03 18:12:04.503618+00	2026-03-03 18:17:56.251439+00	f
120	1391b9e1-b006-4d9c-8c63-e39421079ca2	fef3d3f628907f2604c309afed8b3823	2026-03-03 17:51:20.483073+00	2026-03-03 18:38:23.79322+00	f
124	1391b9e1-b006-4d9c-8c63-e39421079ca2	3ad197fb5e6f2f09c3ec8b384fa239dc	2026-03-03 20:04:17.23445+00	2026-03-03 20:38:25.202121+00	f
127	45af4b4e-a691-4c9e-a390-8fec54c43a30	6fb1fdcf60c54601ca85903c1e7dd0ec	2026-03-03 21:40:20.480146+00	2026-03-03 22:21:45.116972+00	f
128	1391b9e1-b006-4d9c-8c63-e39421079ca2	19cd223c7c1fad26761506fcac175ccf	2026-03-03 22:49:45.911432+00	2026-03-03 23:03:06.860094+00	f
129	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	f3d08555abd13c84a379ef66cf401978	2026-03-04 09:56:07.968007+00	2026-03-04 10:08:31.827633+00	f
131	fa1eadbf-e6c4-47e8-bdbc-c15338679270	27c64f58725d308aa020be7220f6a65e	2026-03-04 10:23:53.114396+00	2026-03-04 10:51:47.085945+00	f
130	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	5d864a14e19c4c985215f5b0d340b986	2026-03-04 09:56:18.105751+00	2026-03-04 10:12:54.438447+00	f
195	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	531a7dea6333b35f467af25e9d559431	2026-03-05 16:21:32.980643+00	2026-03-05 16:23:58.110647+00	t
160	42fb063e-09f0-4d5a-8dd2-47757dae7656	6ef59c8a383bce00470551b640058e78	2026-03-04 17:27:23.909757+00	2026-03-04 17:27:28.625497+00	f
135	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	ec90cfaaaf47ffbaf72c995a6797a0f3	2026-03-04 11:12:24.793752+00	2026-03-04 11:19:27.854221+00	t
137	01bc609b-dddb-4704-96b1-50f7bd2ce359	a0fc2cf9d83499c73ecad326c25792cb	2026-03-04 11:34:45.913022+00	2026-03-04 11:49:52.183256+00	f
167	1391b9e1-b006-4d9c-8c63-e39421079ca2	9fd56cdd8a83b159a529573391763609	2026-03-04 19:43:47.443337+00	2026-03-04 20:37:28.740831+00	f
157	b00be980-b976-4c4a-a96e-eeb67baf6b8d	1292e2c2fbc94f385f832178860d6c33	2026-03-04 17:15:44.418632+00	2026-03-04 17:42:15.041589+00	f
155	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	cd55206846bc9d580de0942a7c632cb2	2026-03-04 16:47:10.535757+00	2026-03-04 17:21:34.84661+00	f
144	01bc609b-dddb-4704-96b1-50f7bd2ce359	99474d86bcef56982d2f535ec206f223	2026-03-04 13:24:42.431343+00	2026-03-04 13:32:58.663277+00	f
132	1391b9e1-b006-4d9c-8c63-e39421079ca2	b53eb70b141f30af102873467df6f73a	2026-03-04 10:27:58.183107+00	2026-03-04 11:20:57.383949+00	f
154	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	abc2fbbf655fa70ced41aae095243fba	2026-03-04 16:14:53.618725+00	2026-03-04 16:51:10.950797+00	f
159	a75a7887-0e17-4786-80cb-b345788be6a0	254e36be111f0ebdc8d904c9854b1117	2026-03-04 17:24:33.358731+00	2026-03-04 18:14:33.677641+00	f
139	fa1eadbf-e6c4-47e8-bdbc-c15338679270	c0b78ed80c473e0f88c4ea71498fc9c9	2026-03-04 12:04:05.022181+00	2026-03-04 12:08:11.943606+00	f
147	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	7aa89a6e75ed3d0b30985eb7dc80152b	2026-03-04 14:14:04.94812+00	2026-03-04 14:17:03.625462+00	t
176	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	d29b74fd7412c6e7602be152cd6f6184	2026-03-05 09:55:05.648537+00	2026-03-05 10:16:27.985409+00	f
152	1391b9e1-b006-4d9c-8c63-e39421079ca2	0c789fa9923850e47a7805596b055498	2026-03-04 15:55:28.780308+00	2026-03-04 15:55:51.595335+00	f
136	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	847a8a7992371d4fa3c612dac0e5d95e	2026-03-04 11:25:01.615014+00	2026-03-04 11:25:09.209433+00	f
151	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	8e7a8032ca0f462ff270c8282eff5393	2026-03-04 15:45:20.044471+00	2026-03-04 15:49:13.723783+00	f
181	45af4b4e-a691-4c9e-a390-8fec54c43a30	8b8459df1e0f6b6e3b7f9d11e7c29ce9	2026-03-05 10:28:28.951971+00	2026-03-05 10:44:56.684948+00	f
164	1391b9e1-b006-4d9c-8c63-e39421079ca2	b15973445566369bbe4d8a7d48074617	2026-03-04 18:18:31.947475+00	2026-03-04 19:05:40.605762+00	f
133	45af4b4e-a691-4c9e-a390-8fec54c43a30	7e46a97a86c5917ae8f5f5223208bfec	2026-03-04 10:42:15.353493+00	2026-03-04 10:48:14.598763+00	f
148	1391b9e1-b006-4d9c-8c63-e39421079ca2	fd472550102e5ba4ddf15aeddb741783	2026-03-04 14:21:06.787562+00	2026-03-04 14:23:01.404146+00	f
140	5003b79d-150a-49b0-b506-3f4cc273d496	fc62b4cba10bbb32cb3e38c8f6adaf89	2026-03-04 12:10:23.10841+00	2026-03-04 13:03:29.212079+00	f
142	1391b9e1-b006-4d9c-8c63-e39421079ca2	23feaff790bf35b9cbd6b0b39a712b43	2026-03-04 12:28:01.490629+00	2026-03-04 13:10:10.402176+00	t
141	a75a7887-0e17-4786-80cb-b345788be6a0	85c6697b7f8ad75a946017ea4bc9a979	2026-03-04 12:11:28.063728+00	2026-03-04 12:37:22.55001+00	f
145	b00be980-b976-4c4a-a96e-eeb67baf6b8d	f2f584f4aaae3b6eef989258ea6a11ab	2026-03-04 13:36:27.212915+00	2026-03-04 13:40:34.484843+00	f
150	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	5d255f074860349fdf85d6a3e8c94064	2026-03-04 15:36:54.804713+00	2026-03-04 16:02:16.307491+00	f
134	b00be980-b976-4c4a-a96e-eeb67baf6b8d	ba8f8ba0f2229770a5e14109680f15e0	2026-03-04 11:07:58.383468+00	2026-03-04 11:09:23.182123+00	f
169	1391b9e1-b006-4d9c-8c63-e39421079ca2	0774598a9c158a5409a6e7eefd2c4824	2026-03-04 20:48:08.704807+00	2026-03-04 20:52:36.337497+00	f
174	1391b9e1-b006-4d9c-8c63-e39421079ca2	0f2babad321943a3fa2298acc8629b97	2026-03-05 00:38:05.853568+00	2026-03-05 00:39:18.307007+00	f
143	1391b9e1-b006-4d9c-8c63-e39421079ca2	ca3cbdf83038076b3e2a3b6dc6f03102	2026-03-04 13:10:40.933335+00	2026-03-04 13:10:41.457237+00	f
138	1391b9e1-b006-4d9c-8c63-e39421079ca2	643152d9ed8cb9e0eb95587fa632cc4b	2026-03-04 11:44:31.126797+00	2026-03-04 11:44:31.795309+00	f
149	5003b79d-150a-49b0-b506-3f4cc273d496	05a4838aad6490c8441553bcfc689547	2026-03-04 15:15:51.669884+00	2026-03-04 15:53:28.870885+00	f
168	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	c03c87fceaf1f8b574fb82c941da7508	2026-03-04 20:18:32.225078+00	2026-03-04 20:18:40.613339+00	f
158	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	f486317391caf02cff03e89e688e225c	2026-03-04 17:22:39.577575+00	2026-03-04 17:36:56.949583+00	t
146	45af4b4e-a691-4c9e-a390-8fec54c43a30	5de9c800931c4dcb7543a95caaa84140	2026-03-04 14:10:37.451555+00	2026-03-04 14:12:15.965333+00	f
170	1391b9e1-b006-4d9c-8c63-e39421079ca2	53b1ac62a884ca2da4224e42a5d4bf54	2026-03-04 22:56:31.294279+00	2026-03-04 23:02:20.261+00	t
162	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	feb5c4b64d2ed6aa570bd47ee77a8b01	2026-03-04 17:56:57.864417+00	2026-03-04 18:04:45.584766+00	f
153	42fb063e-09f0-4d5a-8dd2-47757dae7656	f7982590fb18130fc74d8c98233b2030	2026-03-04 16:07:52.159121+00	2026-03-04 16:28:18.948199+00	f
156	889e347c-4498-4bd3-bf60-6e54a09dd05c	93e6d5a314bbbd99df847b172ea3db10	2026-03-04 17:15:30.602942+00	2026-03-04 17:17:23.257972+00	f
163	1391b9e1-b006-4d9c-8c63-e39421079ca2	ad3607f5c7cd20cf0d054d6eda9a3eaa	2026-03-04 18:00:38.21038+00	2026-03-04 18:02:51.098374+00	t
166	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	e3a7ea2bfe86f20a5736c1c478e6995f	2026-03-04 19:23:35.909692+00	2026-03-04 20:02:48.588936+00	f
171	1391b9e1-b006-4d9c-8c63-e39421079ca2	b0c66cf3cc88c20ae585da5f0e384dce	2026-03-04 23:19:50.530039+00	2026-03-04 23:20:01.164864+00	f
161	3135733f-8d6a-4ac8-9cb0-c34002ae823c	795d09a7d3f1527ebc8905df33fc3e54	2026-03-04 17:29:16.000024+00	2026-03-04 17:41:33.395526+00	f
189	1391b9e1-b006-4d9c-8c63-e39421079ca2	e18aec80e7954e77ceb19f9397ff6fb2	2026-03-05 14:14:59.920065+00	2026-03-05 14:15:08.638046+00	f
187	1391b9e1-b006-4d9c-8c63-e39421079ca2	78a32bf8d28508d3e94d94d6ad1cd2fe	2026-03-05 11:37:10.679074+00	2026-03-05 12:09:38.314821+00	f
172	b6659aab-4945-4c46-a5b0-8a1fb312fa88	9030177c4087a3bfa84db8d60948a7fe	2026-03-04 23:23:38.478261+00	2026-03-04 23:28:00.835422+00	f
165	42fb063e-09f0-4d5a-8dd2-47757dae7656	9482c4a5351cc682ebad9417be94624a	2026-03-04 18:41:33.97625+00	2026-03-04 18:46:03.62192+00	f
185	b00be980-b976-4c4a-a96e-eeb67baf6b8d	b177ceea503cdfb479df6caf97ea58cb	2026-03-05 11:17:21.495054+00	2026-03-05 11:40:58.116058+00	f
173	1391b9e1-b006-4d9c-8c63-e39421079ca2	1ac6443568085870c77dc7192befce41	2026-03-04 23:35:09.792432+00	2026-03-04 23:35:15.432741+00	t
180	1391b9e1-b006-4d9c-8c63-e39421079ca2	e2a2e635e93f301ee17e734ef16868a3	2026-03-05 10:23:38.976999+00	2026-03-05 11:21:26.852082+00	f
175	1391b9e1-b006-4d9c-8c63-e39421079ca2	5bd8b45d6df49f3f8f316c115e1f3ff2	2026-03-05 00:54:12.809799+00	2026-03-05 01:03:00.200296+00	f
183	5003b79d-150a-49b0-b506-3f4cc273d496	b1483ad5581b66b2dcfb1085bb18b5cd	2026-03-05 10:58:59.776286+00	2026-03-05 11:45:38.579458+00	f
179	1391b9e1-b006-4d9c-8c63-e39421079ca2	cd8741c65fdd7968dcd6245a2ed84907	2026-03-05 10:15:41.85032+00	2026-03-05 10:16:02.939314+00	f
177	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	a48c55c34d3ed1ee4e88f491aae8cfd9	2026-03-05 09:55:17.966439+00	2026-03-05 10:08:10.512442+00	f
178	fa1eadbf-e6c4-47e8-bdbc-c15338679270	8b382e0c172d22cd1d5819fc3dace057	2026-03-05 10:04:33.278374+00	2026-03-05 10:30:53.270643+00	f
184	01bc609b-dddb-4704-96b1-50f7bd2ce359	8f5b6596f2b4cd1520b1457b1db9c001	2026-03-05 11:11:03.717882+00	2026-03-05 11:30:30.316783+00	f
188	1391b9e1-b006-4d9c-8c63-e39421079ca2	7ef8c08c1f25bd64728cc4f6ebd1da3f	2026-03-05 13:11:54.508836+00	2026-03-05 13:14:03.087512+00	f
186	a75a7887-0e17-4786-80cb-b345788be6a0	64c6d8dffc4ee1f920ef1c9e5c7bf9a0	2026-03-05 11:25:39.999856+00	2026-03-05 11:27:55.110152+00	f
182	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	0eb4fe09fccd9fc955a63ef76ed10dca	2026-03-05 10:50:07.517955+00	2026-03-05 11:25:21.77678+00	f
192	b00be980-b976-4c4a-a96e-eeb67baf6b8d	3af5767c8fc631a9e8fb2b72bf898c96	2026-03-05 16:02:27.351443+00	2026-03-05 16:13:51.223699+00	f
190	01bc609b-dddb-4704-96b1-50f7bd2ce359	3a0d444e9e3f4ea913ed99a752d6a0d8	2026-03-05 15:37:52.806609+00	2026-03-05 15:43:35.157498+00	f
191	1391b9e1-b006-4d9c-8c63-e39421079ca2	1a67e258687e83a7c4b79150807452e0	2026-03-05 15:39:41.352551+00	2026-03-05 15:39:49.125742+00	f
193	a75a7887-0e17-4786-80cb-b345788be6a0	162958e7e5ccc7ea992c9bcca7bdb4cb	2026-03-05 16:16:38.861564+00	2026-03-05 16:16:47.436971+00	f
194	5b3890dc-65b1-4237-aef7-bd2c6c8c697e	aa1c5d07732e7a71765029a3b3a6f79e	2026-03-05 16:19:42.124588+00	2026-03-05 16:50:36.512258+00	f
196	1391b9e1-b006-4d9c-8c63-e39421079ca2	5ab287a7c76edf613283051a68ea9502	2026-03-05 16:25:34.821625+00	2026-03-05 16:27:20.481497+00	f
216	889e347c-4498-4bd3-bf60-6e54a09dd05c	66599eea6208a696c4d94937fba09261	2026-03-06 15:28:04.702008+00	2026-03-06 16:23:47.541811+00	f
226	1391b9e1-b006-4d9c-8c63-e39421079ca2	a7dfc100a7275a8314a5a6b4009ffff2	2026-03-08 22:16:27.57935+00	2026-03-08 22:16:34.66675+00	f
219	1793be06-d86d-4b3b-a72f-3de0fe072c61	6163c10bff2e10701fbac2a1c628b6ff	2026-03-06 17:31:11.836479+00	2026-03-06 17:54:25.727698+00	f
212	45af4b4e-a691-4c9e-a390-8fec54c43a30	0f12973d66fe4239c4abb5522c75b96b	2026-03-06 13:42:02.733147+00	2026-03-06 13:42:10.783071+00	f
201	67406c3d-e3c9-423f-a140-b68bf71178f6	fa0f78ea9c0baae1b9b76eede131f8cb	2026-03-05 17:44:22.652251+00	2026-03-05 18:18:02.652928+00	f
205	1391b9e1-b006-4d9c-8c63-e39421079ca2	bb5ccc3094209b9fa4f6a92ef5e93972	2026-03-05 20:16:48.25707+00	2026-03-05 20:33:40.363321+00	f
248	3135733f-8d6a-4ac8-9cb0-c34002ae823c	20702796a770da1c2d9432d33e7ecd89	2026-03-09 17:12:36.111266+00	2026-03-09 17:23:39.069017+00	f
209	fa1eadbf-e6c4-47e8-bdbc-c15338679270	076b342c82d1c2b67d38b9821b5fd38c	2026-03-06 09:43:01.967145+00	2026-03-06 10:16:46.507915+00	f
233	b00be980-b976-4c4a-a96e-eeb67baf6b8d	d7502215bc94bb944023006d45bc9e8d	2026-03-09 11:03:31.114344+00	2026-03-09 11:38:35.595564+00	f
207	1391b9e1-b006-4d9c-8c63-e39421079ca2	93365efcafc10426a9557ff675c8d035	2026-03-06 00:43:08.686915+00	2026-03-06 00:43:14.976967+00	f
213	5003b79d-150a-49b0-b506-3f4cc273d496	63e1df0bfa5277d6bc82ed0f212dada0	2026-03-06 14:17:04.787786+00	2026-03-06 14:17:48.735468+00	t
217	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	125abb0c74823f9f57a554fdb404ea39	2026-03-06 16:33:45.845633+00	2026-03-06 16:39:36.717209+00	f
204	1391b9e1-b006-4d9c-8c63-e39421079ca2	ea5e114a925117715e5a1919fb076e56	2026-03-05 19:43:28.147463+00	2026-03-05 19:50:52.531597+00	t
197	42fb063e-09f0-4d5a-8dd2-47757dae7656	76dfa49c17a58d5fdbfceb19f8f79f06	2026-03-05 16:28:23.34717+00	2026-03-05 16:42:31.589573+00	t
238	889e347c-4498-4bd3-bf60-6e54a09dd05c	e310d1aa28155ed237953fa17d1fe010	2026-03-09 12:57:17.059152+00	2026-03-09 13:19:29.345145+00	f
242	5003b79d-150a-49b0-b506-3f4cc273d496	a46de3e3219393978fc0759d35e37b99	2026-03-09 16:04:59.231536+00	2026-03-09 16:42:30.274168+00	f
230	cafbc827-dd5f-4913-9a6e-7a74a157ed0d	3ec23e108a611e4bda0dfe1b1fffaf21	2026-03-09 10:07:33.477133+00	2026-03-09 10:20:52.594217+00	f
221	1391b9e1-b006-4d9c-8c63-e39421079ca2	5be4440e177b35d2e21fa589e1457dea	2026-03-06 19:41:11.346107+00	2026-03-06 19:41:40.67413+00	f
210	b00be980-b976-4c4a-a96e-eeb67baf6b8d	2657f82ed46f240a5f376d299ec6d613	2026-03-06 11:30:15.673973+00	2026-03-06 11:53:06.970237+00	f
224	1391b9e1-b006-4d9c-8c63-e39421079ca2	e01b7d447a3cc5cc6ba51b486e188734	2026-03-08 14:15:25.363219+00	2026-03-08 14:15:33.941989+00	f
218	1391b9e1-b006-4d9c-8c63-e39421079ca2	ddb5a230bf1f8b349b3abe2fa57e0075	2026-03-06 16:57:14.779394+00	2026-03-06 16:58:36.893359+00	t
214	45af4b4e-a691-4c9e-a390-8fec54c43a30	5fea8fe44ca4fa33f6ef1737633f797c	2026-03-06 14:50:58.826743+00	2026-03-06 14:52:16.151292+00	f
215	1391b9e1-b006-4d9c-8c63-e39421079ca2	2a961504cdddde532739b74f152fe630	2026-03-06 15:02:55.260265+00	2026-03-06 15:04:04.304112+00	f
208	1391b9e1-b006-4d9c-8c63-e39421079ca2	beef9082becb98d0c8677b335d0d9e2b	2026-03-06 00:57:21.290475+00	2026-03-06 00:57:25.761165+00	f
199	3135733f-8d6a-4ac8-9cb0-c34002ae823c	f85c3319735b8c3da4664a9c65f4be53	2026-03-05 17:11:27.6192+00	2026-03-05 17:19:31.510559+00	f
202	1391b9e1-b006-4d9c-8c63-e39421079ca2	832f3829aa3a429ffbd63d674c674ea6	2026-03-05 17:44:57.360505+00	2026-03-05 18:32:38.301993+00	f
198	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	2772cff86334fbeedaa9d5f4475812ca	2026-03-05 16:41:52.196817+00	2026-03-05 17:37:12.130182+00	f
237	1391b9e1-b006-4d9c-8c63-e39421079ca2	859fd86b254c8891d5ab3945c3303094	2026-03-09 12:04:48.010072+00	2026-03-09 13:01:41.653696+00	f
206	1391b9e1-b006-4d9c-8c63-e39421079ca2	19b707ec2c6d76961ad63948fd2b40bb	2026-03-05 22:29:24.730549+00	2026-03-05 22:29:40.135586+00	f
200	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	7e473465ef31c79e2d8f36e5061b58f4	2026-03-05 17:13:01.227161+00	2026-03-05 17:41:49.755365+00	f
220	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	d447e74f2b2014bb1b8692c0aed6dbe2	2026-03-06 18:07:48.137773+00	2026-03-06 18:35:28.435914+00	f
222	45af4b4e-a691-4c9e-a390-8fec54c43a30	e8f1eee4d895c0664f8ba0111a87a403	2026-03-07 12:10:46.000082+00	2026-03-07 12:10:48.361392+00	f
203	1391b9e1-b006-4d9c-8c63-e39421079ca2	95970b4c6871acec4e2d08f7b99d9a68	2026-03-05 18:52:37.82327+00	2026-03-05 19:43:25.071632+00	t
211	a75a7887-0e17-4786-80cb-b345788be6a0	89f4b0f1cc1061c6297a13bcb264b2c1	2026-03-06 12:23:07.409884+00	2026-03-06 12:23:43.730817+00	f
227	1391b9e1-b006-4d9c-8c63-e39421079ca2	259f935ff567564a49abd77dc16c78b1	2026-03-08 23:39:18.268859+00	2026-03-08 23:39:25.856526+00	f
225	1391b9e1-b006-4d9c-8c63-e39421079ca2	b69b12dc4b8f7be262c6e3469afae14d	2026-03-08 15:31:30.244922+00	2026-03-08 15:49:19.479602+00	t
229	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	5607390d36f2774c59d7e58bfb676e1b	2026-03-09 09:57:40.723413+00	2026-03-09 10:25:23.845014+00	f
234	b060da0f-1164-40d8-9bb4-b3cb551f6b4c	5d84ef550d6e4ec75cca061b7e438174	2026-03-09 11:16:11.700286+00	2026-03-09 11:39:03.508558+00	f
236	a75a7887-0e17-4786-80cb-b345788be6a0	20988bcb65acb24a3c0050dadd7a5123	2026-03-09 11:55:38.426716+00	2026-03-09 12:27:13.773641+00	f
231	45af4b4e-a691-4c9e-a390-8fec54c43a30	d3fed1b5861491edc9c643cd244c2a15	2026-03-09 10:53:46.738083+00	2026-03-09 11:25:53.075271+00	f
244	64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	744c583c95b821d73bddc3ab14f11899	2026-03-09 16:31:25.943096+00	2026-03-09 16:48:00.661504+00	f
223	1391b9e1-b006-4d9c-8c63-e39421079ca2	7429c6fa9c8e2df672fd9be9f9c7ee0f	2026-03-07 18:43:50.309266+00	2026-03-07 18:43:54.547896+00	f
239	1391b9e1-b006-4d9c-8c63-e39421079ca2	490c90beeb7b0a0b5272a4d9ff2f592f	2026-03-09 13:14:28.415645+00	2026-03-09 13:35:20.460363+00	f
235	42fb063e-09f0-4d5a-8dd2-47757dae7656	b00200a89a9f47b1791ec07885991b90	2026-03-09 11:27:20.947871+00	2026-03-09 11:41:51.575629+00	f
228	fa1eadbf-e6c4-47e8-bdbc-c15338679270	cbaf43117ea677907860487b92075577	2026-03-09 09:52:04.934993+00	2026-03-09 10:17:49.02148+00	f
247	1391b9e1-b006-4d9c-8c63-e39421079ca2	86faf0e21ff8e3593ec2f17052363e4a	2026-03-09 16:50:59.16183+00	2026-03-09 16:55:09.691743+00	f
232	1391b9e1-b006-4d9c-8c63-e39421079ca2	d1abbe77399ca8f3c0ea9e35b273d631	2026-03-09 11:00:56.807543+00	2026-03-09 11:56:02.239727+00	f
243	889e347c-4498-4bd3-bf60-6e54a09dd05c	67d41514839fb1264283900841f84c77	2026-03-09 16:30:19.548077+00	2026-03-09 17:03:25.012821+00	f
240	1391b9e1-b006-4d9c-8c63-e39421079ca2	75cc06c34f2ffeeee63c63196a819290	2026-03-09 14:22:20.556962+00	2026-03-09 14:22:34.934295+00	f
241	ea14ee40-0a22-4fc4-89a2-7dd007a4328d	4029b7b4f8594c53a0288f118219c400	2026-03-09 15:44:37.678575+00	2026-03-09 15:50:27.298219+00	f
246	04b5a9ec-760e-4aef-ba96-d0b61ef9d587	3877ed0edcef8ec0c388b2168302aa11	2026-03-09 16:49:32.70928+00	2026-03-09 17:11:50.192924+00	f
245	1793be06-d86d-4b3b-a72f-3de0fe072c61	d2a1c400b719837f5d148346bd9e726b	2026-03-09 16:37:50.644414+00	2026-03-09 17:01:16.793554+00	t
\.


--
-- Data for Name: operador; Type: TABLE DATA; Schema: pessoa; Owner: -
--

COPY pessoa.operador (id, nome_completo, email, username, foto_url, password_hash, criado_em, atualizado_em, nome_exibicao) FROM stdin;
b060da0f-1164-40d8-9bb4-b3cb551f6b4c	André Luiz Alves da Silva Lucas	luizsil@senado.leg.br	luizsil	/files/operadores/luizsil_1772023004496.jpg	$2b$12$HCOvFAdPJXl4MSkTAJM2i.f7iqzte6SZA/81KPbKNmJm8DLuPnkYq	2026-02-25 12:36:44.742657+00	2026-02-25 12:36:44.742657+00	André
889e347c-4498-4bd3-bf60-6e54a09dd05c	Katiane dos Santos Dantas Medeiros	kdantas@senado.leg.br	kdantas	/files/operadores/kdantas_1772023547448.jpg	$2b$12$M9A9hVvnjuGarymHt4G7dO6dNc3QA0tEmax251M3SXcNqAPq.jPBG	2026-02-25 12:45:47.690497+00	2026-02-25 12:45:47.690497+00	Katiane
b00be980-b976-4c4a-a96e-eeb67baf6b8d	Kátia Mayara da Silva Mendes	katia.mendes@sdr.senado.leg.br	02710230151	/files/operadores/02710230151_1772025211267.jpg	$2b$12$LShIQyE0jDYeUPIOmvrz5eCGiFXcZMWrPXOlmK4m8HyWDcJZP0Zyy	2026-02-25 13:13:31.50761+00	2026-02-25 13:13:31.50761+00	Kátia
5003b79d-150a-49b0-b506-3f4cc273d496	Diana Simão da Rocha	dianasr@senado.leg.br	dianasr	/files/operadores/dianasr_1772026115629.jpg	$2b$12$BS/RpLmaICwyVKXUCUQsbegTul0b7KKDoa0PSr/ECJIRr0b.UMI.i	2026-02-25 13:28:35.869344+00	2026-02-25 13:28:35.869344+00	Diana
5b3890dc-65b1-4237-aef7-bd2c6c8c697e	Geraldo Magela dos Santos	geraldo.magela@senado.leg.br	72340932149	/files/operadores/72340932149_1772026783302.jpg	$2b$12$2GlSiiutcUJu7uKlgH4wg.gCzzOi9WJ6cNfefVxI/bZOxMStFRXDq	2026-02-25 13:39:43.544601+00	2026-02-25 13:39:43.544601+00	Geraldo
fa1eadbf-e6c4-47e8-bdbc-c15338679270	Luiz Caio de Carvalho	luca_22df@hotmail.com	luca	/files/operadores/luca_1772026956530.jpg	$2b$12$2INN6H71yYaVpBNPbexogODnVRh0vAt2Z0cCvPevv1mxLIyo0sb2e	2026-02-25 13:42:36.768563+00	2026-02-25 13:42:36.768563+00	Caio
ea14ee40-0a22-4fc4-89a2-7dd007a4328d	Eduardo Castro Furtado	efurtado@senado.leb.br	efurtado	/files/operadores/efurtado_1772028376348.jpg	$2b$12$6W8Zf5ACtFQfh3CyzCQeBeKQBZVS99oIcuWD/6WsHnarCbu9662UO	2026-02-25 14:06:16.592315+00	2026-02-25 14:06:16.592315+00	Eduardo
42fb063e-09f0-4d5a-8dd2-47757dae7656	Heloisa Viti Ribeiro	heloisa38@yahoo.com.br	heloisav	/files/operadores/heloisav_1772033672570.jpg	$2b$12$sDXdFhgBsbhe9lpbPftLu.PAanJJjYJYEq6ubanIeeEj/FA4SEtx.	2026-02-25 15:34:32.812554+00	2026-02-25 15:34:32.812554+00	Heloisa
64fae2cf-b9c3-4c7a-b2e8-e469501bcf00	Estevan Michael Anderle	estevan.anderle@senado.leg.br	01116834162	/files/operadores/01116834162_1772034078658.jpg	$2b$12$9RxXwO.0w6sVg.jJFeJ7muSfD7EPa3saJ4RX6hi/QbsoHTiUL9aaG	2026-02-25 15:41:18.896331+00	2026-02-25 15:41:18.896331+00	Estevan
45af4b4e-a691-4c9e-a390-8fec54c43a30	RICARDO WALLACE SOARES	ricardow@senado.leg.br	ricardow	/files/operadores/ricardow_1772027782216.jpg	$2b$12$ioRiUeDI62z4yhTLK.bFqe2PafATJVvYoGrWCf0g0bFKzUvFC4VdC	2026-02-25 13:56:22.461948+00	2026-02-25 15:43:50.382177+00	Ricardo
1793be06-d86d-4b3b-a72f-3de0fe072c61	Carlos Eduardo dos Santos Barros	carlos.santos.barros@senado.leg.br	70994170106	/files/operadores/70994170106_1772035244027.jpg	$2b$12$SVFMhAGzQ..IZMBXxXa0U.Ka9Ah9.03xBdPR2k5J8NEv7um7/H7hC	2026-02-25 16:00:44.273368+00	2026-02-25 16:00:44.273368+00	Carlos Eduardo
3135733f-8d6a-4ac8-9cb0-c34002ae823c	Rafael Santos da Silva	rafael.santos.silva@senado.leg.br	04625551196	/files/operadores/04625551196_1772035562557.jpg	$2b$12$i/paivJcezi.WZTkmKU23OKS2Qbvz4saBOaam3.50iua..v7aqsmK	2026-02-25 16:06:02.810094+00	2026-02-25 16:06:02.810094+00	Rafael Santos
67406c3d-e3c9-423f-a140-b68bf71178f6	Wesley Teixeira de Souza	wesleydemori@gmail.com	wesl	/files/operadores/wesl_1772036188591.jpg	$2b$12$6pkJcOxNhfTW7nWkh27TOOAdozW6Ug/QGoNQ6Ur9gq8Ip7cWnHvK2	2026-02-25 16:16:28.838754+00	2026-02-25 16:16:28.838754+00	Wesley
04b5a9ec-760e-4aef-ba96-d0b61ef9d587	Alessandro Viana	alessandrov@senado.leg.br	alessandrov	/files/operadores/alessandrov_1772037166028.jpg	$2b$12$58NvZhzgmG.iTKPVjfVd4uP.UiuqcZUZfJtSm2Qw8P1RochdKysvu	2026-02-25 16:32:46.266983+00	2026-02-25 16:32:46.266983+00	Alessandro
cafbc827-dd5f-4913-9a6e-7a74a157ed0d	Pedro Correa Ditano Moraes	ditano@senado.leg.br	ditano	\N	$2b$12$.MWWZfpO0Oc/LmTnM2or2efYwmEyW30UuK3D9/M3QaRMxxEvETwPe	2026-03-02 14:28:52.854379+00	2026-03-02 14:28:52.854379+00	Pedro
01bc609b-dddb-4704-96b1-50f7bd2ce359	Joelma Oliveira de Lima	jo5163@hotmail.com	Joelm	/files/operadores/joelm_1772539896592.jpg	$2b$12$N8gF1O8BAt4KRetWoTNP4O72hlxaIK66U4jDvqXlJfIy1nWPFjYzu	2026-03-03 12:11:36.832893+00	2026-03-03 12:12:10.578708+00	Joelma
\.


--
-- Data for Name: operador_s; Type: TABLE DATA; Schema: pessoa; Owner: -
--

COPY pessoa.operador_s (id, nome_completo, email, username, senha, ativo, criado_em, atualizado_em) FROM stdin;
\.


--
-- Data for Name: annotation_tag_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.annotation_tag_entity (id, name, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Data for Name: auth_identity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_identity ("userId", "providerId", "providerType", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add user	4	add_user
14	Can change user	4	change_user
15	Can delete user	4	delete_user
16	Can view user	4	view_user
17	Can add content type	5	add_contenttype
18	Can change content type	5	change_contenttype
19	Can delete content type	5	delete_contenttype
20	Can view content type	5	view_contenttype
21	Can add session	6	add_session
22	Can change session	6	change_session
23	Can delete session	6	delete_session
24	Can view session	6	view_session
\.


--
-- Data for Name: auth_provider_sync_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_provider_sync_history (id, "providerType", "runMode", status, "startedAt", "endedAt", scanned, created, updated, disabled, error) FROM stdin;
\.


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Data for Name: chat_hub_messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chat_hub_messages (id, "sessionId", "previousMessageId", "revisionOfMessageId", "retryOfMessageId", type, name, content, provider, model, "workflowId", "executionId", "createdAt", "updatedAt", status) FROM stdin;
\.


--
-- Data for Name: chat_hub_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chat_hub_sessions (id, title, "ownerId", "lastMessageAt", "credentialId", provider, model, "workflowId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: credentials_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.credentials_entity (name, data, type, "createdAt", "updatedAt", id, "isManaged") FROM stdin;
Microsoft Excel account	U2FsdGVkX19+j5Eiy6bW/N12bkEKbenqVEXxjjEA0GqKgFp1a/VAFtoWPNmgF55N20UVWHUPyGe+5/RrEDY0b/yjJGcJ+VpCpQ2AWc+suHRUusCko+0j3IY9UHSUgeNbuiXiJx7EPwzqjiI/86Mut7Rc02LiCvkADOVFlVIgL901trXz+wdntbl1p/V99VhcI4XA0ayxHZUrVKP6NHX5tDLy8CjyAmoP9a0TvZ+6+Q12MjQGhTXCjH3Nx3u0VqIb0FIMf4IlN2TGB88nA/Kc7QIOlW3AWareXpPw6FFTQP9JScKRM7Ku2m7PgzWlIfqPgeDfH2a/0KzHPHfzYUw+8+dQr7tsSAAQRw7CZOhG2Cy8/rObrP0xbXaUtHbs9WAqJ5uF6iSKkHNBc5OIb9yM0wi7BuMU/cV82/32djOCPTJSVnJRLVTceyXz1Vo4rp27rrwZfaMehY4ePJImLEg97bnEM0ooKop39AihJH8pihUdDsHTUvirkuzYGN9Qh8FguD7BJq+0tWLkZdRrKXzPiSdTjjKVdKbE47Q+mTzRFa1B9t14l2CpPviGWS2XURf4n05/4r8Kl59QcLzLPFVO+k4u3f4W+wddYPf7qmVoLDjGszNNPfQ5krvjLWcHXWt7UErWTpIvXpqEaT5jjj5IUWj8sbQFgL19I3HrrgCCvhHj8Rnl4+bfGQ7V9RcAem+syreX2kj+u9Qv3qXGRuUyvaN1scUEhwFe+AhqcD+3nGA+4OtTteMFFcIiwgU6sxmzAs9ewUrU5krXyA8fnWeekXnbJ/IqTh2EiLGfeBicDAP0/fxwP1guAL4yAXeaQ56k75hczz/5100C6fJuYEGmG8CP2lJ2nQoosVxWfVirvp0Lt1PXLguv4MgET+Hn7c4qOv6qbr4F/BjCfzKID37EkErihM0DYqwBBGzYZwUyvSR4yw+LfzTHUoV2TU9F/mpoQOzhfMNHHsd9cnaZCj9y42r6j4g6CX9pnGL/G7tfCWQrdnsJOukTAcnwwLeEi2wEwuWgz+0MRmwrXvIXDWeSuSv9ALHoRBtOcLVCIdUqEol0zQcwU+EnPI68y0mhdy01WNgui0zZ/PGs5sEYPNXwOzgnoUQqBukHcdYpPChkIyqXK234za/or2OrV4wqB1YFIeC5xDT60tpfEjHwTEdKpNrGy2zgabW/NwpvBOwzY05Uujsncf52uyE1EixSv+86ySknculVZXD30kTdW63QXdIcfYIIHUILG50vTyC4pQ0BPyNpVzrwNS1LgPT6tYy9A1aoG9lUICb2NKWlBMkJydhwV0vzUD7wqktv8ZzfOtFRkfuj92SMjc4jpEVxWLCwoNbTPknCemZRkbRzDbQsJ3/0WrJzuMMlbLiclOakIfBjwXkVz+V88ZmyFc1iRrn6KZ6kicF3kQ279xZG0BILuGRJjP/Nun9Ec5uPKX8KbBJ26NXcM0D37P6pR4Z21kp55a2jV36gaHKUpVx2bv1/HXDhnFzOLIhmdJTMeOFgWpjk78GAhirSVCd0IBlKpfqJfhdU/LOjj2rwJ8Gc7xqlcNbCsLs+C5aYco2d7BDIUPiX4gTgwet15rQUZKi3waMAr6dK1pq9ftbjgnQiyLPofZDK6oGS1TYeFZPy7WuEd3GoNm1f6CotMhFfFngYoWn/HJURNTDTsUQXgCpz661RN0F+U0QgCpGZ5Oj4bVLVpnkRk+hWAe9QZGOWOtddb+BaC8OzwosXJOtvn+dpNaUIFhKMUN29ooYj7575bb5of3mQzzJMBc12HbUKOVFPnc1+zvRECsYlRZr3qdlhoST/A7z9iy/tg/MfTFIbSodpr85pLQPonFtamtvDDSwnNvyo+vIhYvcxcXG9DyIqkEIiIsawgoSEPn8dOABm2y4gvdvi50Rs/PIS4uTImH3XezQRg9kdM3MX53fieulQlXOaR8OjzUfV9+F6olci++8+3pPsJ8aiEfC1KScgXwYuTf/vz7nlUNLBSTAdYMnmVDLkp6sIkiBMgLEFkokxqqWKfmfe1Uae15lS+hLjLz9dNiFaKuqovMt+JlUBcUs5ZQWWxCLDo0bw6scXVzFiDAotXP7jloxye/pQKDiJqL18hw8/skSZK0Wcxy1x+CxcdgqsGP5Wk3zx0ytNPPfioSt39xVwTOJLeUzxdXk9WleaJ8v8sgsOD+9Fhu9FzSgQGXRg5P5xNUFgTDtOe7d4Gbb7bz8bkp1mHRyOGazPQmqNrcuWrOWrRcGs4Top9GSuqHu6l64WeTLtbeaCOgKjH0585SJi4sNseq7ZuRwRX/YD88kV5/A8V0voK0CrRdCduzDH603TPaUMzMyVPwLkenU/612KVWvnoJE8Sv/Cwwy9Y12HIMEHBpfnapM1wV490X7m59xbnuLzExceqVNMh1EvCQBkERYmdarGKew4eZkk7JVISF7uP5/6Q4SPmkZnepvvGhVO4wCMzeK1SxI109XUvXgPg+7wyYgagK5f6JJ9fNPAnUgto0AOAKtb6cfHXix8tmREqhH1aokofeiKcBE+PolXi7tl5T2mZu0DgBzlVN1uSQ0YRNCRKOYDvi3UzQNE4zt2Y3c6/pJ4gWUm1QOz4WHd/vVYmByuQsSNBEg4MBHGlyKxR3ke0I94TgDa9EYxyC5Eua8Dsz18NcJGK3+jq/qeJPvy5zpH7v21jTmHvL5GuX01pHRAosu9lPwmCqAhC56AbwCT0/8atZ/hnam0EJMNtdTE2O0atAtdbDRM0qIGZ/Hw2uDOLhl0dSC481NOQums7Kx8TmArZ1lCPVdcRhc2JivsxwDDd2e3ssG2/xrYgx95MTJH/CzWc99gmGzJG3A2sZ1x25fB4CMvwf7CsOBZSq5kDMTa+hNCOdQa0IfrtbAA4K17tyhQ9G7Zp4QANR/fUSMETGawwaBoo8qXPSnSlss0wIwar6z37+QlHJtzfrpmR2I1LGiiinepM+xfe5DGQ+REila9XPm+KtpVg3Ya06jVEK8+YTkYH/Bv7OUsULmPMTEY0VjcU1c8G19t+1/IBN4rwff5T8XX/BDXscbp/68XKOPUuRBlH4O60otZuW26O5yMpaaUwoI338thro9v+rZOiDC14H8CfsFgSxRnTL4cddIRxvQMioO4zgSNzM25821/lr/KcIVAvDcaixVlgRch8R/bO26ucPO9JeeLp9jtnTcbjlQUOqz2VeH0CCZKHMX4SbEGv/YRHZjrC4MtZmKdVnVACjqXF8U+lfcceNFTKDZKo4+W3oWpbuom79LjrkRMiboBxFAjrk8ZozHCD/PZ2dlwGpZHOc6OUKVkNwq/u6R2k4m9e/ji/gq5dkON3qm14h/t9Tsu9iSDNzdVyUhVgi+24xAnot9p4CiZpRuhOp29VinrvqPtSwS3pBmBb5BquTh4+H1bxTMmbx+jbzPtlk4t1j60kQWgcoQoIJ/ElA46kj3T+y7Aq0TGPbkERbrr7jfLg0U4zZhD3Nczb4av+aMrblUCU4gNLtGzLVeV719qq/fUkApodsdU7s+Xuunr3VzIauEQNP9NTtRh8qNdQVFnj+cnwT+iFyS43Y5uv6Plce3YQwFFpGBJuWY2s/mAtm3EglEVod8uTwsTVAgBZiuGUTYuoL1j3eSqidEM3vYWDOtXU4uHuf4nD+XtZX0V8M3cD4szMIj6mzrA/nCjJEy5HKUoGdpSfWE0w8sNFPriOSG6kPfDY3bG/83IdoJRKoEL5VNc3xhL5mGAMx004rmpp/swVtQb2bIVIsK/OrXNIePkIHLT/FNsjdt4Ew1KkwMe1jhifIxllVN5WRWA22lAeC1M5lsrgI91z9J1wrZcq5l54T7DQ3ZlfkyMtUZKgs5I2NwIwpC9h9Kyt3ECOKpn23oU2Pxk7t3TBPmXui2gXoeA7BMoxMFykWwH0aB53p/+GraTBQKbAM0ykbXtnLkgx0+N6oCnOXXAPyjWEP64olepTc1qzLL3Eiz8DHpBNwDuDqB99z7JnZtiynjdi5eb9QmkFEgcBPZ/6aeRvMq1sLRbWesybiHhrfpAhNYWKVt7Apa0qPX/hgX1Rm42W6YmIe9uAj2zwWywvPzrM9UAzFbDq3p4qAmiHx6yY81NyQ1O2/fGayRkFB5fkTMsk/FmiWEKT3236pGPwReBwRkEmfD9pXU6KAXuoPlzQwepAmj2Pyn4OyEN4iXsgU6Yosgt4m3vEWgCbNxdzd+3SRIIAD6la4CmIodQpd0epmx8f9hvvcRlKssRLz/JAqpu7Oeij34NrmhqZ9DBEb27ysi74Lhfdkx7TSqPIXmUZCsFJw8fufv78JfLf6gw+hEX1/b0sq+bEdBoP9jmbrAHYaSVw5Djr4dP+hU60JybO9sUMaTsfzbWRm57sA==	microsoftExcelOAuth2Api	2025-10-28 14:41:22.587+00	2025-10-29 10:39:21.482+00	iHakh8oiPPXmA0qx	f
Postgres account	U2FsdGVkX1/nNgARLbi9M9wrvUerZsxv61EFOYgvMiiLOJ8sYuJ/ujuR+L1yzVJW75DJW4DDNSSuuQXkgMBQfVkHOBSWofgQBQ0hBXz+TBD+pPSzOKIICbq1I91AFI5b9OpLhzms5g1q/ZSAl1djx1NP6PSKDKZPE8yK6Uetk9I=	postgres	2025-10-28 17:04:57.111+00	2025-11-03 18:56:27.773+00	6su8u1Ut25O71hCo	f
\.


--
-- Data for Name: data_table; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.data_table (id, name, "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: data_table_column; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.data_table_column (id, name, type, index, "dataTableId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: data_table_user_5EBBvwJHpAKSfA9V; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."data_table_user_5EBBvwJHpAKSfA9V" (id, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	auth	user
5	contenttypes	contenttype
6	sessions	session
\.


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2026-03-01 22:04:04.427097+00
2	auth	0001_initial	2026-03-01 22:04:04.483655+00
3	admin	0001_initial	2026-03-01 22:04:04.499228+00
4	admin	0002_logentry_remove_auto_add	2026-03-01 22:04:04.546717+00
5	admin	0003_logentry_add_action_flag_choices	2026-03-01 22:04:04.552397+00
6	contenttypes	0002_remove_content_type_name	2026-03-01 22:04:04.562258+00
7	auth	0002_alter_permission_name_max_length	2026-03-01 22:04:04.568633+00
8	auth	0003_alter_user_email_max_length	2026-03-01 22:04:04.573488+00
9	auth	0004_alter_user_username_opts	2026-03-01 22:04:04.578097+00
10	auth	0005_alter_user_last_login_null	2026-03-01 22:04:04.583195+00
11	auth	0006_require_contenttypes_0002	2026-03-01 22:04:04.58414+00
12	auth	0007_alter_validators_add_error_messages	2026-03-01 22:04:04.588537+00
13	auth	0008_alter_user_username_max_length	2026-03-01 22:04:04.597143+00
14	auth	0009_alter_user_last_name_max_length	2026-03-01 22:04:04.601998+00
15	auth	0010_alter_group_name_max_length	2026-03-01 22:04:04.607968+00
16	auth	0011_update_proxy_permissions	2026-03-01 22:04:04.612131+00
17	auth	0012_alter_user_first_name_max_length	2026-03-01 22:04:04.616401+00
18	sessions	0001_initial	2026-03-01 22:04:04.624267+00
\.


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: event_destinations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.event_destinations (id, destination, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_annotation_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.execution_annotation_tags ("annotationId", "tagId") FROM stdin;
\.


--
-- Data for Name: execution_annotations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.execution_annotations (id, "executionId", vote, note, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.execution_data ("executionId", "workflowData", data) FROM stdin;
\.


--
-- Data for Name: execution_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.execution_entity (id, finished, mode, "retryOf", "retrySuccessId", "startedAt", "stoppedAt", "waitTill", status, "workflowId", "deletedAt", "createdAt") FROM stdin;
\.


--
-- Data for Name: execution_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.execution_metadata (id, "executionId", key, value) FROM stdin;
\.


--
-- Data for Name: folder; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.folder (id, name, "parentFolderId", "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: folder_tag; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.folder_tag ("folderId", "tagId") FROM stdin;
\.


--
-- Data for Name: insights_by_period; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.insights_by_period (id, "metaId", type, value, "periodUnit", "periodStart") FROM stdin;
\.


--
-- Data for Name: insights_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.insights_metadata ("metaId", "workflowId", "projectId", "workflowName", "projectName") FROM stdin;
\.


--
-- Data for Name: insights_raw; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.insights_raw (id, "metaId", type, value, "timestamp") FROM stdin;
\.


--
-- Data for Name: installed_nodes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.installed_nodes (name, type, "latestVersion", package) FROM stdin;
\.


--
-- Data for Name: installed_packages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.installed_packages ("packageName", "installedVersion", "authorName", "authorEmail", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: invalid_auth_token; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.invalid_auth_token (token, "expiresAt") FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.migrations (id, "timestamp", name) FROM stdin;
1	1587669153312	InitialMigration1587669153312
2	1589476000887	WebhookModel1589476000887
3	1594828256133	CreateIndexStoppedAt1594828256133
4	1607431743768	MakeStoppedAtNullable1607431743768
5	1611144599516	AddWebhookId1611144599516
6	1617270242566	CreateTagEntity1617270242566
7	1620824779533	UniqueWorkflowNames1620824779533
8	1626176912946	AddwaitTill1626176912946
9	1630419189837	UpdateWorkflowCredentials1630419189837
10	1644422880309	AddExecutionEntityIndexes1644422880309
11	1646834195327	IncreaseTypeVarcharLimit1646834195327
12	1646992772331	CreateUserManagement1646992772331
13	1648740597343	LowerCaseUserEmail1648740597343
14	1652254514002	CommunityNodes1652254514002
15	1652367743993	AddUserSettings1652367743993
16	1652905585850	AddAPIKeyColumn1652905585850
17	1654090467022	IntroducePinData1654090467022
18	1658932090381	AddNodeIds1658932090381
19	1659902242948	AddJsonKeyPinData1659902242948
20	1660062385367	CreateCredentialsUserRole1660062385367
21	1663755770893	CreateWorkflowsEditorRole1663755770893
22	1664196174001	WorkflowStatistics1664196174001
23	1665484192212	CreateCredentialUsageTable1665484192212
24	1665754637025	RemoveCredentialUsageTable1665754637025
25	1669739707126	AddWorkflowVersionIdColumn1669739707126
26	1669823906995	AddTriggerCountColumn1669823906995
27	1671535397530	MessageEventBusDestinations1671535397530
28	1671726148421	RemoveWorkflowDataLoadedFlag1671726148421
29	1673268682475	DeleteExecutionsWithWorkflows1673268682475
30	1674138566000	AddStatusToExecutions1674138566000
31	1674509946020	CreateLdapEntities1674509946020
32	1675940580449	PurgeInvalidWorkflowConnections1675940580449
33	1676996103000	MigrateExecutionStatus1676996103000
34	1677236854063	UpdateRunningExecutionStatus1677236854063
35	1677501636754	CreateVariables1677501636754
36	1679416281778	CreateExecutionMetadataTable1679416281778
37	1681134145996	AddUserActivatedProperty1681134145996
38	1681134145997	RemoveSkipOwnerSetup1681134145997
39	1690000000000	MigrateIntegerKeysToString1690000000000
40	1690000000020	SeparateExecutionData1690000000020
41	1690000000030	RemoveResetPasswordColumns1690000000030
42	1690000000030	AddMfaColumns1690000000030
43	1690787606731	AddMissingPrimaryKeyOnExecutionData1690787606731
44	1691088862123	CreateWorkflowNameIndex1691088862123
45	1692967111175	CreateWorkflowHistoryTable1692967111175
46	1693491613982	ExecutionSoftDelete1693491613982
47	1693554410387	DisallowOrphanExecutions1693554410387
48	1694091729095	MigrateToTimestampTz1694091729095
49	1695128658538	AddWorkflowMetadata1695128658538
50	1695829275184	ModifyWorkflowHistoryNodesAndConnections1695829275184
51	1700571993961	AddGlobalAdminRole1700571993961
52	1705429061930	DropRoleMapping1705429061930
53	1711018413374	RemoveFailedExecutionStatus1711018413374
54	1711390882123	MoveSshKeysToDatabase1711390882123
55	1712044305787	RemoveNodesAccess1712044305787
56	1714133768519	CreateProject1714133768519
57	1714133768521	MakeExecutionStatusNonNullable1714133768521
58	1717498465931	AddActivatedAtUserSetting1717498465931
59	1720101653148	AddConstraintToExecutionMetadata1720101653148
60	1721377157740	FixExecutionMetadataSequence1721377157740
61	1723627610222	CreateInvalidAuthTokenTable1723627610222
62	1723796243146	RefactorExecutionIndices1723796243146
63	1724753530828	CreateAnnotationTables1724753530828
64	1724951148974	AddApiKeysTable1724951148974
65	1726606152711	CreateProcessedDataTable1726606152711
66	1727427440136	SeparateExecutionCreationFromStart1727427440136
67	1728659839644	AddMissingPrimaryKeyOnAnnotationTagMapping1728659839644
68	1729607673464	UpdateProcessedDataValueColumnToText1729607673464
69	1729607673469	AddProjectIcons1729607673469
70	1730386903556	CreateTestDefinitionTable1730386903556
71	1731404028106	AddDescriptionToTestDefinition1731404028106
72	1731582748663	MigrateTestDefinitionKeyToString1731582748663
73	1732271325258	CreateTestMetricTable1732271325258
74	1732549866705	CreateTestRun1732549866705
75	1733133775640	AddMockedNodesColumnToTestDefinition1733133775640
76	1734479635324	AddManagedColumnToCredentialsTable1734479635324
77	1736172058779	AddStatsColumnsToTestRun1736172058779
78	1736947513045	CreateTestCaseExecutionTable1736947513045
79	1737715421462	AddErrorColumnsToTestRuns1737715421462
80	1738709609940	CreateFolderTable1738709609940
81	1739549398681	CreateAnalyticsTables1739549398681
82	1740445074052	UpdateParentFolderIdColumn1740445074052
83	1741167584277	RenameAnalyticsToInsights1741167584277
84	1742918400000	AddScopesColumnToApiKeys1742918400000
85	1745322634000	ClearEvaluation1745322634000
86	1745587087521	AddWorkflowStatisticsRootCount1745587087521
87	1745934666076	AddWorkflowArchivedColumn1745934666076
88	1745934666077	DropRoleTable1745934666077
89	1747824239000	AddProjectDescriptionColumn1747824239000
90	1750252139166	AddLastActiveAtColumnToUser1750252139166
91	1750252139166	AddScopeTables1750252139166
92	1750252139167	AddRolesTables1750252139167
93	1750252139168	LinkRoleToUserTable1750252139168
94	1750252139170	RemoveOldRoleColumn1750252139170
95	1752669793000	AddInputsOutputsToTestCaseExecution1752669793000
96	1753953244168	LinkRoleToProjectRelationTable1753953244168
97	1754475614601	CreateDataStoreTables1754475614601
98	1754475614602	ReplaceDataStoreTablesWithDataTables1754475614602
99	1756906557570	AddTimestampsToRoleAndRoleIndexes1756906557570
100	1758731786132	AddAudienceColumnToApiKeys1758731786132
101	1758794506893	AddProjectIdToVariableTable1758794506893
102	1759399811000	ChangeValueTypesForInsights1759399811000
103	1760019379982	CreateChatHubTables1760019379982
104	1760020838000	UniqueRoleNames1760020838000
105	1760314000000	CreateWorkflowDependencyTable1760314000000
106	1760965142113	DropUnusedChatHubColumns1760965142113
\.


--
-- Data for Name: processed_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.processed_data ("workflowId", context, "createdAt", "updatedAt", value) FROM stdin;
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project (id, name, type, "createdAt", "updatedAt", icon, description) FROM stdin;
Qgt2DgtOESvqQVZO	Douglas Antunes <douglas.antunes.sen@outlook.com>	personal	2025-10-27 22:21:32.688+00	2025-10-27 22:26:00.893+00	\N	\N
\.


--
-- Data for Name: project_relation; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_relation ("projectId", "userId", role, "createdAt", "updatedAt") FROM stdin;
Qgt2DgtOESvqQVZO	65df07de-4758-4935-ae13-bfc19b6f239b	project:personalOwner	2025-10-27 22:21:32.688+00	2025-10-27 22:21:32.688+00
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.role (slug, "displayName", description, "roleType", "systemRole", "createdAt", "updatedAt") FROM stdin;
global:owner	Owner	Owner	global	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.553+00
global:admin	Admin	Admin	global	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.553+00
global:member	Member	Member	global	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.553+00
project:admin	Project Admin	Full control of settings, members, workflows, credentials and executions	project	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.591+00
project:personalOwner	Project Owner	Project Owner	project	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.591+00
project:editor	Project Editor	Create, edit, and delete workflows, credentials, and executions	project	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.591+00
project:viewer	Project Viewer	Read-only access to workflows, credentials, and executions	project	t	2025-10-27 22:21:33.374+00	2025-10-27 22:21:33.591+00
credential:owner	Credential Owner	Credential Owner	credential	t	2025-10-27 22:21:33.599+00	2025-10-27 22:21:33.599+00
credential:user	Credential User	Credential User	credential	t	2025-10-27 22:21:33.599+00	2025-10-27 22:21:33.599+00
workflow:owner	Workflow Owner	Workflow Owner	workflow	t	2025-10-27 22:21:33.603+00	2025-10-27 22:21:33.603+00
workflow:editor	Workflow Editor	Workflow Editor	workflow	t	2025-10-27 22:21:33.603+00	2025-10-27 22:21:33.603+00
\.


--
-- Data for Name: role_scope; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.role_scope ("roleSlug", "scopeSlug") FROM stdin;
global:owner	annotationTag:create
global:owner	annotationTag:read
global:owner	annotationTag:update
global:owner	annotationTag:delete
global:owner	annotationTag:list
global:owner	auditLogs:manage
global:owner	banner:dismiss
global:owner	community:register
global:owner	communityPackage:install
global:owner	communityPackage:uninstall
global:owner	communityPackage:update
global:owner	communityPackage:list
global:owner	credential:share
global:owner	credential:move
global:owner	credential:create
global:owner	credential:read
global:owner	credential:update
global:owner	credential:delete
global:owner	credential:list
global:owner	externalSecretsProvider:sync
global:owner	externalSecretsProvider:create
global:owner	externalSecretsProvider:read
global:owner	externalSecretsProvider:update
global:owner	externalSecretsProvider:delete
global:owner	externalSecretsProvider:list
global:owner	externalSecret:list
global:owner	externalSecret:use
global:owner	eventBusDestination:test
global:owner	eventBusDestination:create
global:owner	eventBusDestination:read
global:owner	eventBusDestination:update
global:owner	eventBusDestination:delete
global:owner	eventBusDestination:list
global:owner	ldap:sync
global:owner	ldap:manage
global:owner	license:manage
global:owner	logStreaming:manage
global:owner	orchestration:read
global:owner	project:create
global:owner	project:read
global:owner	project:update
global:owner	project:delete
global:owner	project:list
global:owner	saml:manage
global:owner	securityAudit:generate
global:owner	sourceControl:pull
global:owner	sourceControl:push
global:owner	sourceControl:manage
global:owner	tag:create
global:owner	tag:read
global:owner	tag:update
global:owner	tag:delete
global:owner	tag:list
global:owner	user:resetPassword
global:owner	user:changeRole
global:owner	user:enforceMfa
global:owner	user:create
global:owner	user:read
global:owner	user:update
global:owner	user:delete
global:owner	user:list
global:owner	variable:create
global:owner	variable:read
global:owner	variable:update
global:owner	variable:delete
global:owner	variable:list
global:owner	projectVariable:create
global:owner	projectVariable:read
global:owner	projectVariable:update
global:owner	projectVariable:delete
global:owner	projectVariable:list
global:owner	workersView:manage
global:owner	workflow:share
global:owner	workflow:execute
global:owner	workflow:move
global:owner	workflow:create
global:owner	workflow:read
global:owner	workflow:update
global:owner	workflow:delete
global:owner	workflow:list
global:owner	folder:create
global:owner	folder:read
global:owner	folder:update
global:owner	folder:delete
global:owner	folder:list
global:owner	folder:move
global:owner	insights:list
global:owner	oidc:manage
global:owner	provisioning:manage
global:owner	dataTable:list
global:owner	role:manage
global:owner	mcp:manage
global:owner	mcpApiKey:create
global:owner	mcpApiKey:rotate
global:owner	chatHub:manage
global:owner	chatHub:message
global:admin	annotationTag:create
global:admin	annotationTag:read
global:admin	annotationTag:update
global:admin	annotationTag:delete
global:admin	annotationTag:list
global:admin	auditLogs:manage
global:admin	banner:dismiss
global:admin	community:register
global:admin	communityPackage:install
global:admin	communityPackage:uninstall
global:admin	communityPackage:update
global:admin	communityPackage:list
global:admin	credential:share
global:admin	credential:move
global:admin	credential:create
global:admin	credential:read
global:admin	credential:update
global:admin	credential:delete
global:admin	credential:list
global:admin	externalSecretsProvider:sync
global:admin	externalSecretsProvider:create
global:admin	externalSecretsProvider:read
global:admin	externalSecretsProvider:update
global:admin	externalSecretsProvider:delete
global:admin	externalSecretsProvider:list
global:admin	externalSecret:list
global:admin	externalSecret:use
global:admin	eventBusDestination:test
global:admin	eventBusDestination:create
global:admin	eventBusDestination:read
global:admin	eventBusDestination:update
global:admin	eventBusDestination:delete
global:admin	eventBusDestination:list
global:admin	ldap:sync
global:admin	ldap:manage
global:admin	license:manage
global:admin	logStreaming:manage
global:admin	orchestration:read
global:admin	project:create
global:admin	project:read
global:admin	project:update
global:admin	project:delete
global:admin	project:list
global:admin	saml:manage
global:admin	securityAudit:generate
global:admin	sourceControl:pull
global:admin	sourceControl:push
global:admin	sourceControl:manage
global:admin	tag:create
global:admin	tag:read
global:admin	tag:update
global:admin	tag:delete
global:admin	tag:list
global:admin	user:resetPassword
global:admin	user:changeRole
global:admin	user:enforceMfa
global:admin	user:create
global:admin	user:read
global:admin	user:update
global:admin	user:delete
global:admin	user:list
global:admin	variable:create
global:admin	variable:read
global:admin	variable:update
global:admin	variable:delete
global:admin	variable:list
global:admin	projectVariable:create
global:admin	projectVariable:read
global:admin	projectVariable:update
global:admin	projectVariable:delete
global:admin	projectVariable:list
global:admin	workersView:manage
global:admin	workflow:share
global:admin	workflow:execute
global:admin	workflow:move
global:admin	workflow:create
global:admin	workflow:read
global:admin	workflow:update
global:admin	workflow:delete
global:admin	workflow:list
global:admin	folder:create
global:admin	folder:read
global:admin	folder:update
global:admin	folder:delete
global:admin	folder:list
global:admin	folder:move
global:admin	insights:list
global:admin	oidc:manage
global:admin	provisioning:manage
global:admin	dataTable:list
global:admin	role:manage
global:admin	mcp:manage
global:admin	mcpApiKey:create
global:admin	mcpApiKey:rotate
global:admin	chatHub:manage
global:admin	chatHub:message
global:member	annotationTag:create
global:member	annotationTag:read
global:member	annotationTag:update
global:member	annotationTag:delete
global:member	annotationTag:list
global:member	eventBusDestination:test
global:member	eventBusDestination:list
global:member	tag:create
global:member	tag:read
global:member	tag:update
global:member	tag:list
global:member	user:list
global:member	variable:read
global:member	variable:list
global:member	dataTable:list
global:member	mcpApiKey:create
global:member	mcpApiKey:rotate
global:member	chatHub:message
project:admin	credential:share
project:admin	credential:move
project:admin	credential:create
project:admin	credential:read
project:admin	credential:update
project:admin	credential:delete
project:admin	credential:list
project:admin	project:read
project:admin	project:update
project:admin	project:delete
project:admin	project:list
project:admin	sourceControl:push
project:admin	projectVariable:create
project:admin	projectVariable:read
project:admin	projectVariable:update
project:admin	projectVariable:delete
project:admin	projectVariable:list
project:admin	workflow:execute
project:admin	workflow:move
project:admin	workflow:create
project:admin	workflow:read
project:admin	workflow:update
project:admin	workflow:delete
project:admin	workflow:list
project:admin	folder:create
project:admin	folder:read
project:admin	folder:update
project:admin	folder:delete
project:admin	folder:list
project:admin	folder:move
project:admin	dataTable:create
project:admin	dataTable:read
project:admin	dataTable:update
project:admin	dataTable:delete
project:admin	dataTable:readRow
project:admin	dataTable:writeRow
project:admin	dataTable:listProject
project:personalOwner	credential:share
project:personalOwner	credential:move
project:personalOwner	credential:create
project:personalOwner	credential:read
project:personalOwner	credential:update
project:personalOwner	credential:delete
project:personalOwner	credential:list
project:personalOwner	project:read
project:personalOwner	project:list
project:personalOwner	workflow:share
project:personalOwner	workflow:execute
project:personalOwner	workflow:move
project:personalOwner	workflow:create
project:personalOwner	workflow:read
project:personalOwner	workflow:update
project:personalOwner	workflow:delete
project:personalOwner	workflow:list
project:personalOwner	folder:create
project:personalOwner	folder:read
project:personalOwner	folder:update
project:personalOwner	folder:delete
project:personalOwner	folder:list
project:personalOwner	folder:move
project:personalOwner	dataTable:create
project:personalOwner	dataTable:read
project:personalOwner	dataTable:update
project:personalOwner	dataTable:delete
project:personalOwner	dataTable:readRow
project:personalOwner	dataTable:writeRow
project:personalOwner	dataTable:listProject
project:editor	credential:create
project:editor	credential:read
project:editor	credential:update
project:editor	credential:delete
project:editor	credential:list
project:editor	project:read
project:editor	project:list
project:editor	projectVariable:create
project:editor	projectVariable:read
project:editor	projectVariable:update
project:editor	projectVariable:delete
project:editor	projectVariable:list
project:editor	workflow:execute
project:editor	workflow:create
project:editor	workflow:read
project:editor	workflow:update
project:editor	workflow:delete
project:editor	workflow:list
project:editor	folder:create
project:editor	folder:read
project:editor	folder:update
project:editor	folder:delete
project:editor	folder:list
project:editor	dataTable:create
project:editor	dataTable:read
project:editor	dataTable:update
project:editor	dataTable:delete
project:editor	dataTable:readRow
project:editor	dataTable:writeRow
project:editor	dataTable:listProject
project:viewer	credential:read
project:viewer	credential:list
project:viewer	project:read
project:viewer	project:list
project:viewer	projectVariable:read
project:viewer	projectVariable:list
project:viewer	workflow:read
project:viewer	workflow:list
project:viewer	folder:read
project:viewer	folder:list
project:viewer	dataTable:read
project:viewer	dataTable:readRow
project:viewer	dataTable:listProject
credential:owner	credential:share
credential:owner	credential:move
credential:owner	credential:read
credential:owner	credential:update
credential:owner	credential:delete
credential:user	credential:read
workflow:owner	workflow:share
workflow:owner	workflow:execute
workflow:owner	workflow:move
workflow:owner	workflow:read
workflow:owner	workflow:update
workflow:owner	workflow:delete
workflow:editor	workflow:execute
workflow:editor	workflow:read
workflow:editor	workflow:update
\.


--
-- Data for Name: scope; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.scope (slug, "displayName", description) FROM stdin;
annotationTag:create	Create Annotation Tag	Allows creating new annotation tags.
annotationTag:read	annotationTag:read	\N
annotationTag:update	annotationTag:update	\N
annotationTag:delete	annotationTag:delete	\N
annotationTag:list	annotationTag:list	\N
annotationTag:*	annotationTag:*	\N
auditLogs:manage	auditLogs:manage	\N
auditLogs:*	auditLogs:*	\N
banner:dismiss	banner:dismiss	\N
banner:*	banner:*	\N
community:register	community:register	\N
community:*	community:*	\N
communityPackage:install	communityPackage:install	\N
communityPackage:uninstall	communityPackage:uninstall	\N
communityPackage:update	communityPackage:update	\N
communityPackage:list	communityPackage:list	\N
communityPackage:manage	communityPackage:manage	\N
communityPackage:*	communityPackage:*	\N
credential:share	credential:share	\N
credential:move	credential:move	\N
credential:create	credential:create	\N
credential:read	credential:read	\N
credential:update	credential:update	\N
credential:delete	credential:delete	\N
credential:list	credential:list	\N
credential:*	credential:*	\N
externalSecretsProvider:sync	externalSecretsProvider:sync	\N
externalSecretsProvider:create	externalSecretsProvider:create	\N
externalSecretsProvider:read	externalSecretsProvider:read	\N
externalSecretsProvider:update	externalSecretsProvider:update	\N
externalSecretsProvider:delete	externalSecretsProvider:delete	\N
externalSecretsProvider:list	externalSecretsProvider:list	\N
externalSecretsProvider:*	externalSecretsProvider:*	\N
externalSecret:list	externalSecret:list	\N
externalSecret:use	externalSecret:use	\N
externalSecret:*	externalSecret:*	\N
eventBusDestination:test	eventBusDestination:test	\N
eventBusDestination:create	eventBusDestination:create	\N
eventBusDestination:read	eventBusDestination:read	\N
eventBusDestination:update	eventBusDestination:update	\N
eventBusDestination:delete	eventBusDestination:delete	\N
eventBusDestination:list	eventBusDestination:list	\N
eventBusDestination:*	eventBusDestination:*	\N
ldap:sync	ldap:sync	\N
ldap:manage	ldap:manage	\N
ldap:*	ldap:*	\N
license:manage	license:manage	\N
license:*	license:*	\N
logStreaming:manage	logStreaming:manage	\N
logStreaming:*	logStreaming:*	\N
orchestration:read	orchestration:read	\N
orchestration:list	orchestration:list	\N
orchestration:*	orchestration:*	\N
project:create	project:create	\N
project:read	project:read	\N
project:update	project:update	\N
project:delete	project:delete	\N
project:list	project:list	\N
project:*	project:*	\N
saml:manage	saml:manage	\N
saml:*	saml:*	\N
securityAudit:generate	securityAudit:generate	\N
securityAudit:*	securityAudit:*	\N
sourceControl:pull	sourceControl:pull	\N
sourceControl:push	sourceControl:push	\N
sourceControl:manage	sourceControl:manage	\N
sourceControl:*	sourceControl:*	\N
tag:create	tag:create	\N
tag:read	tag:read	\N
tag:update	tag:update	\N
tag:delete	tag:delete	\N
tag:list	tag:list	\N
tag:*	tag:*	\N
user:resetPassword	user:resetPassword	\N
user:changeRole	user:changeRole	\N
user:enforceMfa	user:enforceMfa	\N
user:create	user:create	\N
user:read	user:read	\N
user:update	user:update	\N
user:delete	user:delete	\N
user:list	user:list	\N
user:*	user:*	\N
variable:create	variable:create	\N
variable:read	variable:read	\N
variable:update	variable:update	\N
variable:delete	variable:delete	\N
variable:list	variable:list	\N
variable:*	variable:*	\N
projectVariable:create	projectVariable:create	\N
projectVariable:read	projectVariable:read	\N
projectVariable:update	projectVariable:update	\N
projectVariable:delete	projectVariable:delete	\N
projectVariable:list	projectVariable:list	\N
projectVariable:*	projectVariable:*	\N
workersView:manage	workersView:manage	\N
workersView:*	workersView:*	\N
workflow:share	workflow:share	\N
workflow:execute	workflow:execute	\N
workflow:move	workflow:move	\N
workflow:activate	workflow:activate	\N
workflow:deactivate	workflow:deactivate	\N
workflow:create	workflow:create	\N
workflow:read	workflow:read	\N
workflow:update	workflow:update	\N
workflow:delete	workflow:delete	\N
workflow:list	workflow:list	\N
workflow:*	workflow:*	\N
folder:create	folder:create	\N
folder:read	folder:read	\N
folder:update	folder:update	\N
folder:delete	folder:delete	\N
folder:list	folder:list	\N
folder:move	folder:move	\N
folder:*	folder:*	\N
insights:list	insights:list	\N
insights:*	insights:*	\N
oidc:manage	oidc:manage	\N
oidc:*	oidc:*	\N
provisioning:manage	provisioning:manage	\N
provisioning:*	provisioning:*	\N
dataTable:create	dataTable:create	\N
dataTable:read	dataTable:read	\N
dataTable:update	dataTable:update	\N
dataTable:delete	dataTable:delete	\N
dataTable:list	dataTable:list	\N
dataTable:readRow	dataTable:readRow	\N
dataTable:writeRow	dataTable:writeRow	\N
dataTable:listProject	dataTable:listProject	\N
dataTable:*	dataTable:*	\N
execution:delete	execution:delete	\N
execution:read	execution:read	\N
execution:retry	execution:retry	\N
execution:list	execution:list	\N
execution:get	execution:get	\N
execution:*	execution:*	\N
workflowTags:update	workflowTags:update	\N
workflowTags:list	workflowTags:list	\N
workflowTags:*	workflowTags:*	\N
role:manage	role:manage	\N
role:*	role:*	\N
mcp:manage	mcp:manage	\N
mcp:*	mcp:*	\N
mcpApiKey:create	mcpApiKey:create	\N
mcpApiKey:rotate	mcpApiKey:rotate	\N
mcpApiKey:*	mcpApiKey:*	\N
chatHub:manage	chatHub:manage	\N
chatHub:message	chatHub:message	\N
chatHub:*	chatHub:*	\N
*	*	\N
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.settings (key, value, "loadOnStartup") FROM stdin;
ui.banners.dismissed	["V1"]	t
features.ldap	{"loginEnabled":false,"loginLabel":"","connectionUrl":"","allowUnauthorizedCerts":false,"connectionSecurity":"none","connectionPort":389,"baseDn":"","bindingAdminDn":"","bindingAdminPassword":"","firstNameAttribute":"","lastNameAttribute":"","emailAttribute":"","loginIdAttribute":"","ldapIdAttribute":"","userFilter":"","synchronizationEnabled":false,"synchronizationInterval":60,"searchPageSize":0,"searchTimeout":60}	t
userManagement.authenticationMethod	email	t
features.sourceControl.sshKeys	{"encryptedPrivateKey":"U2FsdGVkX1/sAGCScrVguft4SkGnqDMmJc/YpD0+0YzjHbEtFsfgYCKe+oNo+UNLs9fFFOQCrYmjRcgZcwQdMsrIs0cZXHNjHE1x8L+j8+tmcQjmh+F1OH4NEIOkTl65BFmT4C4r7wxZkyAARMf6EMRtQQVj4UwhmMe/Ryi4mWsq8x0Aqxc/VwF7KvS5ryOI3ykPNfV1NDKJ38UDCwjSmbnuO7OVAoWRyHQhQ8dh/M5jotpCqjjvDyH7NUfULb1yaxhOH8ZDQRP72ofqi6fpwTsq4OxHBKj6umorwt9ZQcTvJnjl97DCPRaTgooO9dShs0ieA5Xv8dPbFt73YpJdYLMXgjZKZFfDePzKdeqiwTq3/ns8jmFyENIrKHGPWVI8Jp9Xz6fe/AwdYfm4t+OPUGVQYYtDPf1AlzNLNFsTTqklf7eDDlpx5jT0PecT7nLPyhST7tn/rQSvwj4sP4z2NRkN1FqYr7dn3CSYrW6zXRCzFArBASF7SZXL2vWhTLXxoNBeRSmXQAVyM0NPmggxaXSSaYNbMFm2R62bTPE7bHyJFNzc3hD/h2tlgQX0faqh","publicKey":"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEcr55rXEXQ8DbEuWXwbvlmNRw3FvoSiQotX9ll/yc7 n8n deploy key"}	t
features.sourceControl	{"branchName":"main","connectionType":"ssh","keyGeneratorType":"ed25519"}	t
userManagement.isInstanceOwnerSetUp	true	t
\.


--
-- Data for Name: shared_credentials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shared_credentials ("credentialsId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: shared_workflow; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shared_workflow ("workflowId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: tag_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tag_entity (name, "createdAt", "updatedAt", id) FROM stdin;
\.


--
-- Data for Name: test_case_execution; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_case_execution (id, "testRunId", "executionId", status, "runAt", "completedAt", "errorCode", "errorDetails", metrics, "createdAt", "updatedAt", inputs, outputs) FROM stdin;
\.


--
-- Data for Name: test_run; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_run (id, "workflowId", status, "errorCode", "errorDetails", "runAt", "completedAt", metrics, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."user" (id, email, "firstName", "lastName", password, "personalizationAnswers", "createdAt", "updatedAt", settings, disabled, "mfaEnabled", "mfaSecret", "mfaRecoveryCodes", "lastActiveAt", "roleSlug") FROM stdin;
65df07de-4758-4935-ae13-bfc19b6f239b	douglas.antunes.sen@outlook.com	Douglas	Antunes	$2a$10$D14HPgp9kvnqD42p/AZm2O9gecVMvY12Vx9XNWEgybnEd1n6mC7GG	{"version":"v4","personalization_survey_submitted_at":"2025-10-27T22:26:11.941Z","personalization_survey_n8n_version":"1.117.2","companySize":"20-99","companyType":"ecommerce","role":"business-owner","reportedSource":"google"}	2025-10-27 22:21:32.128+00	2025-12-02 11:56:30.48+00	{"userActivated":true,"firstSuccessfulWorkflowId":"W34KHQno95soj6Ka","userActivatedAt":1762003262126,"npsSurvey":{"responded":true,"lastShownAt":1762956258424}}	f	f	\N	\N	2025-12-02	global:owner
\.


--
-- Data for Name: user_api_keys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_api_keys (id, "userId", label, "apiKey", "createdAt", "updatedAt", scopes, audience) FROM stdin;
\.


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.variables (key, type, value, id, "projectId") FROM stdin;
\.


--
-- Data for Name: webhook_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.webhook_entity ("webhookPath", method, node, "webhookId", "pathLength", "workflowId") FROM stdin;
\.


--
-- Data for Name: workflow_dependency; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.workflow_dependency (id, "workflowId", "workflowVersionId", "dependencyType", "dependencyKey", "dependencyInfo", "indexVersionId", "createdAt") FROM stdin;
\.


--
-- Data for Name: workflow_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.workflow_entity (name, active, nodes, connections, "createdAt", "updatedAt", settings, "staticData", "pinData", "versionId", "triggerCount", id, meta, "parentFolderId", "isArchived") FROM stdin;
Auth — Login (POST /login)	f	[{"parameters":{"httpMethod":"POST","path":"login","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-288,0],"id":"644ad336-1d50-4ad8-bcc7-8f39a1598a27","name":"Webhook","webhookId":"87a3d963-24c7-41d9-afd8-f8ab3e9fc81b"},{"parameters":{"operation":"executeQuery","query":"SELECT * FROM (\\n  SELECT\\n    'administrador'::text AS perfil,\\n    a.id,\\n    a.nome_completo,\\n    a.username::text AS username,\\n    a.email::text    AS email\\n  FROM pessoa.administrador a\\n  WHERE (a.username = $1 OR a.email = $1)\\n    AND a.password_hash = pessoa.crypt($2::text, a.password_hash::text)\\n\\n  UNION ALL\\n\\n  SELECT\\n    'operador'::text AS perfil,\\n    o.id,\\n    o.nome_completo,\\n    o.username::text AS username,\\n    o.email::text    AS email\\n  FROM pessoa.operador o\\n  WHERE (o.username = $1 OR o.email = $1)\\n    AND o.password_hash = pessoa.crypt($2::text, o.password_hash::text)\\n) u\\nLIMIT 1;","options":{"queryReplacement":"={{$json.body.usuario}}\\n{{$json.body.senha}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-112,0],"id":"1162c23a-c1c3-4832-8c27-c089bb379e92","name":"Consultar Usuário","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"2269d16f-5686-474e-9b01-058a04e8963a","leftValue":"={{$json.id}}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[32,0],"id":"4eee0d0c-cfe1-4207-b126-1fc3e8141733","name":"If","alwaysOutputData":true},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"error\\":\\"Credenciais inválidas\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[192,160],"id":"1865d2ba-dced-44c7-af23-cb1ad68b6ef0","name":"Respond to Webhook"},{"parameters":{"operation":"executeQuery","query":"WITH\\nheader AS (SELECT '{\\"alg\\":\\"HS256\\",\\"typ\\":\\"JWT\\"}'::text AS j),\\npayload AS (\\n  SELECT json_build_object(\\n    'sub',      $1::text,\\n    'perfil',   $2::text,\\n    'username', $3::text,\\n    'nome',     $4::text,\\n    'email',    $5::text,\\n    'sid',      $6::text,         -- NOVO\\n    'iat',      EXTRACT(EPOCH FROM NOW())::int,\\n    'exp',      (EXTRACT(EPOCH FROM NOW())::int + 60*60)   -- 1h (ajuste seu prazo)\\n  )::text AS j\\n),\\nparts AS (\\n  SELECT\\n    translate(rtrim(REPLACE(encode(convert_to(h.j,'utf8'),'base64'), E'\\\\n', ''), '='), '+/','-_') AS hb,\\n    translate(rtrim(REPLACE(encode(convert_to(p.j,'utf8'),'base64'), E'\\\\n', ''), '='), '+/','-_') AS pb\\n  FROM header h, payload p\\n),\\nsig AS (\\n  SELECT\\n    encode(\\n      pessoa.hmac(\\n        convert_to(hb || '.' || pb, 'utf8'),\\n        convert_to($7::text, 'utf8'),   -- antes era $6\\n        'sha256'::text\\n      ),\\n      'base64'\\n    ) AS sb64,\\n    hb, pb\\n  FROM parts\\n),\\nsigurl AS (\\n  SELECT translate(rtrim(REPLACE(sb64, E'\\\\n', ''), '='), '+/','-_') AS sb, hb, pb FROM sig\\n)\\nSELECT\\n  (hb || '.' || pb || '.' || sb) AS token,\\n  $1::text AS id,\\n  $2::text AS perfil,\\n  $3::text AS username,\\n  $4::text AS nome_completo,\\n  $5::text AS email,\\n  $6::text AS sid\\nFROM sigurl;\\n","options":{"queryReplacement":"={{$json.id}}\\n{{$json.perfil}}\\n{{$json.username}}\\n{{$json.nome_completo}}\\n{{$json.email}}\\n{{$json.sid}}\\n{{$env.AUTH_JWT_SECRET}}\\n"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[384,-16],"id":"a9630720-d250-4e44-ab59-8469dd37b0fe","name":"Gerar JWT","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"token\\": \\"{{ JSON.stringify($json.token).slice(1, -1).replace(/\\\\\\\\n/g,'') }}\\",\\n  \\"user\\": {\\n    \\"id\\": \\"{{ JSON.stringify($json.id).slice(1, -1) }}\\",\\n    \\"role\\": \\"{{ JSON.stringify($json.perfil).slice(1, -1) }}\\",\\n    \\"username\\": \\"{{ JSON.stringify($json.username).slice(1, -1) }}\\",\\n    \\"nome\\": \\"{{ JSON.stringify($json.nome_completo).slice(1, -1) }}\\",\\n    \\"email\\": \\"{{ JSON.stringify($json.email).slice(1, -1) }}\\"\\n  }\\n}","options":{}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[544,-16],"id":"5e4dacb3-4eb6-4789-979b-db52656d1eb1","name":"Respond 200 (JSON)"},{"parameters":{"operation":"executeQuery","query":"WITH ins AS (\\n  INSERT INTO pessoa.auth_sessions (\\n    user_id,\\n    refresh_token_hash,\\n    created_at,\\n    last_activity,\\n    revoked\\n  )\\n  VALUES (\\n    $1::uuid,\\n    md5(($1::uuid)::text || clock_timestamp()::text || random()::text),\\n    NOW(),\\n    NOW(),\\n    false\\n  )\\n  RETURNING id\\n)\\nSELECT\\n  ins.id::text AS sid,\\n  $1::uuid     AS id,\\n  $2::text     AS perfil,\\n  $3::text     AS username,\\n  $4::text     AS nome_completo,\\n  $5::text     AS email\\nFROM ins;\\n","options":{"queryReplacement":"={{$json.id}}\\n{{$json.perfil}}\\n{{$json.username}}\\n{{$json.nome_completo}}\\n{{$json.email}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[224,-16],"id":"102296a3-d2aa-4a1b-b426-9ecb6059f791","name":"create_session","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}}]	{"Webhook":{"main":[[{"node":"Consultar Usuário","type":"main","index":0}]]},"Consultar Usuário":{"main":[[{"node":"If","type":"main","index":0}]]},"If":{"main":[[{"node":"create_session","type":"main","index":0}],[{"node":"Respond to Webhook","type":"main","index":0}]]},"Gerar JWT":{"main":[[{"node":"Respond 200 (JSON)","type":"main","index":0}]]},"create_session":{"main":[[{"node":"Gerar JWT","type":"main","index":0}]]}}	2025-11-01 22:54:52.96+00	2025-11-16 18:30:33.445+00	{"executionOrder":"v1"}	\N	{}	038135cb-4db6-48a1-951b-00a018553cbc	1	FxFG2bGhVq2DEQuz	{"templateCredsSetupCompleted":true}	\N	f
My workflow	f	[{"parameters":{"httpMethod":"POST","path":"7fd38b4e-7632-4dec-bd77-32c5642194e8","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[0,0],"id":"1318696d-bdce-4c4a-9228-53f97a00568c","name":"Webhook","webhookId":"7fd38b4e-7632-4dec-bd77-32c5642194e8"},{"parameters":{"resource":"table","workbook":{"__rl":true,"value":"B11466CBB7443807!s80d931d0c02b49a0b2ece41cb81ac1bd","mode":"list","cachedResultName":"Checklist diario","cachedResultUrl":"https://onedrive.live.com/personal/b11466cbb7443807/_layouts/15/doc.aspx?resid=80d931d0-c02b-49a0-b2ec-e41cb81ac1bd&cid=b11466cbb7443807"},"worksheet":{"__rl":true,"value":"{4E211EF9-0A07-F44E-AC6D-92132C38B2AA}","mode":"list","cachedResultName":"Planilha1","cachedResultUrl":"https://onedrive.live.com/personal/b11466cbb7443807/_layouts/15/doc.aspx?resid=80d931d0-c02b-49a0-b2ec-e41cb81ac1bd&cid=b11466cbb7443807&activeCell=Planilha1!A1"},"table":{"__rl":true,"value":"{07C601F6-9B95-5E4D-8F30-6022941724D0}","mode":"list","cachedResultName":"Tabela1","cachedResultUrl":"https://onedrive.live.com/personal/b11466cbb7443807/_layouts/15/doc.aspx?resid=80d931d0-c02b-49a0-b2ec-e41cb81ac1bd&cid=b11466cbb7443807&activeCell=Planilha1!A1:T4"},"fieldsUi":{"values":[{"column":"Data da Operação","fieldValue":"={{ $json.data_operacao }}"},{"column":"=Plenário/Sala","fieldValue":"={{ $json.local }}"},{"column":"Turno","fieldValue":"={{ $json.turno }}"},{"column":"=Horário de início dos testes","fieldValue":"={{ $json.hora_inicio }}"},{"column":"Sistema Zoom","fieldValue":"={{ $json.sistema_zoom }}"},{"column":"Horário de término dos testes","fieldValue":"={{ $json.hora_termino }}"},{"column":"Observações Gerais","fieldValue":"={{ $json.observacoes }}"}]},"options":{}},"type":"n8n-nodes-base.microsoftExcel","typeVersion":2.2,"position":[512,-32],"id":"2d01f84f-bb50-49e4-a6f0-3cc39b7db56a","name":"Append rows to table","credentials":{"microsoftExcelOAuth2Api":{"id":"iHakh8oiPPXmA0qx","name":"Microsoft Excel account"}}},{"parameters":{"mode":"raw","jsonOutput":"={\\n  \\"data_operacao\\": \\"={{ $json.body.dataOperacao }}\\",\\n  \\"turno\\": \\"={{ $json.body.turno }}\\",\\n  \\"hora_inicio\\":\\"{{ $json.body.horaInicio }}\\",\\n  \\"hora_termino\\":\\"{{ $json.body.horaTermino }}\\",\\n}","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[224,-160],"id":"69921968-634e-484f-87e9-63f72adf8681","name":"Edit Fields"},{"parameters":{"schema":{"__rl":true,"value":"forms","mode":"list","cachedResultName":"forms"},"table":{"__rl":true,"value":"checklist","mode":"list","cachedResultName":"checklist"},"columns":{"mappingMode":"defineBelow","value":{"data_operacao":"={{ $json.body.dataOperacao.toDateTime() }}","turno":"={{ $json.body.turno }}","hora_inicio":"={{ $json.body.horaInicio }}","hora_termino":"={{ $json.body.horaTermino }}","local":"={{ $json.body.local }}","sistema_zoom":"={{ $json.body.sistemaZoom }}","falha_mic_bancada":"={{ $json.body.falhaMicBancada }}","mic_bancada":"={{ $json.body.micBancada }}","mic_sem_fio":"={{ $json.body.micSemFio }}","pc_secretario":"={{ $json.body.pcSecretario }}","falha_mic_sem_fio":"={{ $json.body.falhaMicSemFio }}","falha_pc_secretario":"={{ $json.body.falhaPcSecretario }}","falha_videowall":"={{ $json.body.falhaVideowall }}","videowall":"={{ $json.body.videowall }}","vip":"={{ $json.body.vip }}","tablet_secretaria":"={{ $json.body.tabletSecretaria }}","falha_vip":"={{ $json.body.falhaVip }}","falha_tablet_secretaria":"={{ $json.body.falhaTabletSecretaria }}","falha_tablet_presidente":"={{ $json.body.falhaTabletPresidente }}","tablet_presidente":"={{ $json.body.tabletPresidente }}","relogio":"={{ $json.body.relogio }}","sinal_tv_senado":"={{ $json.body.sinalTVSenado }}","observacoes":"={{ $json.body.observacoes }}","falha_sinal_tv_senado":"={{ $json.body.falhaSinalTVSenado }}","falha_sistema_zoom":"={{ $json.body.falhaSistemaZoom }}","falha_relogio":"={{ $json.body.falhaRelogio }}"},"matchingColumns":["id"],"schema":[{"id":"id","displayName":"id","required":false,"defaultMatch":true,"display":true,"type":"number","canBeUsedToMatch":true,"removed":false},{"id":"created_at","displayName":"created_at","required":false,"defaultMatch":false,"display":true,"type":"dateTime","canBeUsedToMatch":true},{"id":"data_operacao","displayName":"data_operacao","required":true,"defaultMatch":false,"display":true,"type":"dateTime","canBeUsedToMatch":true},{"id":"turno","displayName":"turno","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"hora_inicio","displayName":"hora_inicio","required":true,"defaultMatch":false,"display":true,"type":"time","canBeUsedToMatch":true},{"id":"hora_termino","displayName":"hora_termino","required":true,"defaultMatch":false,"display":true,"type":"time","canBeUsedToMatch":true},{"id":"local","displayName":"local","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"sistema_zoom","displayName":"sistema_zoom","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_sistema_zoom","displayName":"falha_sistema_zoom","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"mic_bancada","displayName":"mic_bancada","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_mic_bancada","displayName":"falha_mic_bancada","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"mic_sem_fio","displayName":"mic_sem_fio","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_mic_sem_fio","displayName":"falha_mic_sem_fio","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"pc_secretario","displayName":"pc_secretario","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_pc_secretario","displayName":"falha_pc_secretario","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"videowall","displayName":"videowall","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_videowall","displayName":"falha_videowall","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"vip","displayName":"vip","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_vip","displayName":"falha_vip","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"tablet_secretaria","displayName":"tablet_secretaria","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_tablet_secretaria","displayName":"falha_tablet_secretaria","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"tablet_presidente","displayName":"tablet_presidente","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_tablet_presidente","displayName":"falha_tablet_presidente","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"relogio","displayName":"relogio","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_relogio","displayName":"falha_relogio","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"sinal_tv_senado","displayName":"sinal_tv_senado","required":true,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"falha_sinal_tv_senado","displayName":"falha_sinal_tv_senado","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true},{"id":"observacoes","displayName":"observacoes","required":false,"defaultMatch":false,"display":true,"type":"string","canBeUsedToMatch":true}],"attemptToConvertTypes":false,"convertFieldsToString":false},"options":{}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[256,-16],"id":"5edb0613-f902-459e-97e4-79544fc1a852","name":"Insert rows in a table","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}}]	{"Webhook":{"main":[[{"node":"Insert rows in a table","type":"main","index":0}]]},"Edit Fields":{"main":[[]]},"Insert rows in a table":{"main":[[{"node":"Append rows to table","type":"main","index":0}]]}}	2025-10-28 13:25:33.359+00	2025-11-16 18:36:48.743+00	{"executionOrder":"v1"}	\N	{"Webhook":[{"json":{"headers":{"host":"n8n.senado-nusp.cloud","x-real-ip":"177.174.217.244","x-forwarded-for":"177.174.217.244","x-forwarded-proto":"https","connection":"upgrade","content-length":"555","user-agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0","accept":"*/*","accept-language":"pt-BR,pt;q=0.8,en-US;q=0.5,en;q=0.3","accept-encoding":"gzip, deflate, br, zstd","referer":"https://form.senado-nusp.cloud/","content-type":"application/json","origin":"https://form.senado-nusp.cloud","sec-fetch-dest":"empty","sec-fetch-mode":"cors","sec-fetch-site":"same-site","priority":"u=0"},"params":{},"query":{},"body":{"dataOperacao":"2025-10-28","local":"Sala 02","turno":"Matutino","horaInicio":"10:10","sistemaZoom":"Ok","falhaSistemaZoom":"","pcSecretario":"Falha","falhaPcSecretario":"fdsafs","videowall":"Ok","falhaVideowall":"","micSemFio":"Ok","falhaMicSemFio":"","micBancada":"Ok","falhaMicBancada":"","sinalTVSenado":"Ok","falhaSinalTVSenado":"","tabletPresidente":"Ok","falhaTabletPresidente":"","tabletSecretaria":"Ok","falhaTabletSecretaria":"","relogio":"Ok","falhaRelogio":"","vip":"Falha","falhaVip":"fasfads","horaTermino":"10:10","observacoes":"dfdsfdsf"},"webhookUrl":"https://n8n.senado-nusp.cloud/webhook-test/7fd38b4e-7632-4dec-bd77-32c5642194e8","executionMode":"test"}}]}	d19105d4-1f7d-4318-872f-ee127e22928a	1	6af3iughxqRv5Q4L	{"templateCredsSetupCompleted":true}	\N	f
Checklist (protegido) copy	f	[{"parameters":{"httpMethod":"POST","path":"checklist2","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-112,0],"id":"5cbc038d-f5aa-43ad-aa9c-15e74afca6af","name":"Webhook","webhookId":"620cece3-ccf1-4695-b476-769feaa489c8"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": true,\\n  \\"token_preview\\": \\"{{ JSON.stringify($json.token).slice(0,24) }}...\\"\\n}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[144,-432],"id":"a417ddc7-0b71-4a7c-aaf0-72b04bd2e92a","name":"Respond to Webhook"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3e40b949-272d-406f-acd2-ab8c79245a52","leftValue":"=={{$json.not_expired}}","rightValue":"=={{true}}","operator":{"type":"string","operation":"equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[464,0],"id":"066c8742-d15f-4b96-9e39-3823df936f81","name":"If","alwaysOutputData":true},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": {\\n    \\"id\\": \\"{{ $json.sub }}\\",\\n    \\"perfil\\": \\"{{ $json.perfil }}\\",\\n    \\"username\\": \\"{{ $json.username }}\\",\\n    \\"nome\\": \\"{{ $json.nome }}\\",\\n    \\"email\\": \\"{{ $json.email }}\\"\\n  }\\n}\\n","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,-64],"id":"aa6941f1-972b-4b92-a74e-875b7462d627","name":"Respond 200 (JSON)"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": false, \\"error\\": \\"Token inválido ou expirado\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,80],"id":"bef182c8-c8cc-4217-abc9-87962641c732","name":"Resond 401 (JSON)"},{"parameters":{"operation":"executeQuery","query":"SELECT\\n  translate(\\n    rtrim(\\n      encode(\\n        pessoa.hmac(convert_to('probe','utf8'), convert_to($1::text,'utf8'), 'sha256'),\\n        'base64'\\n      ),\\n      '='\\n    ),\\n    '+/',\\n    '-_'\\n  ) AS fp;","options":{"queryReplacement":"=={{$env.JWT_SECRET}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[368,-432],"id":"ea42490b-4692-4a3f-9f03-126b14778142","name":"Execute a SQL query1","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"operation":"executeQuery","query":"WITH parts AS (\\n  SELECT\\n    split_part($1, '.', 1) AS h,\\n    split_part($1, '.', 2) AS p,\\n    split_part($1, '.', 3) AS s\\n),\\nrecompute AS (\\n  SELECT\\n    encode(\\n      pessoa.hmac(\\n        convert_to(h || '.' || p, 'utf8'),\\n        convert_to($2::text, 'utf8'),\\n        'sha256'::text\\n      ),\\n      'base64'\\n    ) AS s_b64,\\n    h, p, s\\n  FROM parts\\n),\\n-- normaliza ambas as assinaturas para base64url (sem padding)\\nnorm AS (\\n  SELECT\\n    translate(rtrim(s_b64, '='), '+/', '-_') AS s_calc_norm,\\n    translate(rtrim(s,     '='), '+/', '-_') AS s_recv_norm,\\n    h, p\\n  FROM recompute\\n),\\nok_sig AS (\\n  SELECT (s_calc_norm = s_recv_norm) AS assinatura_ok, h, p, s_calc_norm, s_recv_norm\\n  FROM norm\\n),\\npayload AS (\\n  SELECT\\n    convert_from(\\n      decode(translate(p, '-_', '+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64'),\\n      'utf8'\\n    ) AS pl\\n  FROM ok_sig\\n  WHERE assinatura_ok\\n),\\nclaims AS (\\n  SELECT\\n    (pl::jsonb)->>'sub'      AS sub,\\n    (pl::jsonb)->>'perfil'   AS perfil,\\n    (pl::jsonb)->>'username' AS username,\\n    (pl::jsonb)->>'nome'     AS nome,\\n    (pl::jsonb)->>'email'    AS email,\\n    ((pl::jsonb)->>'exp')::int AS exp\\n  FROM payload\\n)\\nSELECT\\n  COALESCE((SELECT assinatura_ok FROM ok_sig), false)           AS assinatura_ok,\\n  (SELECT left(s_recv_norm,16) FROM ok_sig)                     AS recv_prefix,\\n  (SELECT left(s_calc_norm,16) FROM ok_sig)                     AS calc_prefix,\\n  (SELECT sub   FROM claims)                                    AS sub,\\n  (SELECT perfil FROM claims)                                   AS perfil,\\n  (SELECT username FROM claims)                                 AS username,\\n  (SELECT nome  FROM claims)                                    AS nome,\\n  (SELECT email FROM claims)                                    AS email,\\n  (SELECT exp   FROM claims)                                    AS exp,\\n  CASE WHEN (SELECT exp FROM claims) IS NOT NULL\\n       THEN ((SELECT exp FROM claims) > EXTRACT(EPOCH FROM NOW())::int)\\n       ELSE false\\n  END AS not_expired;","options":{"queryReplacement":"=={{$json.token}}\\n={{$env.JWT_SECRET}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[272,0],"id":"119361af-b2e8-4d83-8ccc-c0168c40d07d","name":"Validar JWT","alwaysOutputData":true,"credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"mode":"raw","jsonOutput":"=={{\\n  {\\n    token: (\\n      ($json.headers?.authorization || $json.headers?.Authorization || '')\\n        .replace(/^Bearer\\\\s+/, '')\\n        .replace(/\\\\s+/g, '')\\n    )\\n  }\\n}}","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[64,0],"id":"97a4c8fe-1455-4899-bf26-8f30119ab1af","name":"Set (token)"}]	{"Webhook":{"main":[[{"node":"Set (token)","type":"main","index":0}]]},"If":{"main":[[{"node":"Respond 200 (JSON)","type":"main","index":0}],[{"node":"Resond 401 (JSON)","type":"main","index":0}]]},"Execute a SQL query1":{"main":[[]]},"Validar JWT":{"main":[[{"node":"If","type":"main","index":0}]]},"Set (token)":{"main":[[{"node":"Validar JWT","type":"main","index":0}]]}}	2025-11-03 15:36:39.111+00	2025-11-06 10:40:51.14+00	{"executionOrder":"v1"}	\N	{}	019f6d5a-d9ef-40a1-abb1-8994a74bb6cb	1	KXbzznuNMJdaxypm	{"templateCredsSetupCompleted":true}	\N	t
auth_jwt_validator	f	[{"parameters":{"httpMethod":"POST","path":"checklist","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-112,0],"id":"8cd71624-1b8c-4d25-ad8b-c729543d5d06","name":"Webhook","webhookId":"80589f02-2b5e-4c62-9e38-7f965bab3786"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3e40b949-272d-406f-acd2-ab8c79245a52","leftValue":"=={{$json.not_expired}}","rightValue":"=={{true}}","operator":{"type":"string","operation":"equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[528,0],"id":"6068e835-4e73-482b-bed5-959217039f6c","name":"If","alwaysOutputData":true},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": {\\n    \\"id\\": \\"{{ $json.sub }}\\",\\n    \\"perfil\\": \\"{{ $json.perfil }}\\",\\n    \\"username\\": \\"{{ $json.username }}\\",\\n    \\"nome\\": \\"{{ $json.nome }}\\",\\n    \\"email\\": \\"{{ $json.email }}\\"\\n  }\\n}\\n","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,-64],"id":"9c62b5cd-ab12-4124-a0d5-8fb612db3828","name":"Respond 200 (JSON)"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": false, \\"error\\": \\"Token inválido ou expirado\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,80],"id":"8ac38f83-d355-43df-b663-48871b609ea2","name":"Resond 401 (JSON)"},{"parameters":{"operation":"executeQuery","query":"WITH parts AS (\\n  SELECT\\n    split_part($1, '.', 1) AS h,\\n    split_part($1, '.', 2) AS p,\\n    split_part($1, '.', 3) AS s\\n),\\nrecompute AS (\\n  SELECT\\n    -- CORREÇÃO: Mantém o REPLACE para limpar a assinatura recalculada\\n    REPLACE(\\n      encode(\\n        pessoa.hmac(\\n          convert_to(h || '.' || p, 'utf8'),\\n          convert_to($2::text, 'utf8'),\\n          'sha256'::text\\n        ),\\n        'base64'\\n      ),\\n    E'\\\\n', '') AS s_b64,\\n    h, p, s\\n  FROM parts\\n),\\nnorm AS (\\n  SELECT\\n    translate(rtrim(s_b64, '='), '+/', '-_') AS s_calc_norm,\\n    translate(rtrim(s,     '='), '+/', '-_') AS s_recv_norm,\\n    h, p\\n  FROM recompute\\n),\\nok_sig AS (\\n  SELECT (s_calc_norm = s_recv_norm) AS assinatura_ok, h, p, s_calc_norm, s_recv_norm\\n  FROM norm\\n),\\npayload AS (\\n  SELECT\\n    convert_from(\\n      decode(translate(p, '-_', '+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64'),\\n      'utf8'\\n    ) AS pl\\n  FROM ok_sig\\n  WHERE assinatura_ok\\n),\\nclaims AS (\\n  SELECT\\n    (pl::jsonb)->>'sub'      AS sub,\\n    (pl::jsonb)->>'perfil'   AS perfil,\\n    (pl::jsonb)->>'username' AS username,\\n    (pl::jsonb)->>'nome'     AS nome,\\n    (pl::jsonb)->>'email'    AS email,\\n    ((pl::jsonb)->>'exp')::int AS exp\\n  FROM payload\\n)\\nSELECT\\n  COALESCE((SELECT assinatura_ok FROM ok_sig), false)           AS assinatura_ok,\\n  (SELECT left(s_recv_norm,16) FROM ok_sig)                     AS recv_prefix,\\n  (SELECT left(s_calc_norm,16) FROM ok_sig)                     AS calc_prefix,\\n  (SELECT sub   FROM claims)                                    AS sub,\\n  (SELECT perfil FROM claims)                                   AS perfil,\\n  (SELECT username FROM claims)                                 AS username,\\n  (SELECT nome  FROM claims)                                    AS nome,\\n  (SELECT email FROM claims)                                    AS email,\\n  (SELECT exp   FROM claims)                                    AS exp,\\n  CASE WHEN (SELECT exp FROM claims) IS NOT NULL\\n  THEN ((SELECT exp FROM claims) > EXTRACT(EPOCH FROM NOW())::int)\\n  ELSE false\\n  END AS not_expired;","options":{"queryReplacement":"={{$json.token}}\\n{{$env.JWT_SECRET}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[320,0],"id":"90fc5519-aee1-4c3b-9c58-e3b4be8a8461","name":"Validar JWT","alwaysOutputData":true,"credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"mode":"raw","jsonOutput":"={{\\n  {\\n    token: (\\n      ($json.headers?.authorization || $json.headers?.Authorization || '')\\n        .replace(/^Bearer\\\\s+/, '')\\n        .replace(/\\\\s+/g, '')\\n    )\\n  }\\n}}","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[112,0],"id":"24c1cd0e-dad1-4b52-8d29-bc662cb82d51","name":"Edit Fields"}]	{"Webhook":{"main":[[{"node":"Edit Fields","type":"main","index":0}]]},"If":{"main":[[{"node":"Respond 200 (JSON)","type":"main","index":0}],[{"node":"Resond 401 (JSON)","type":"main","index":0}]]},"Validar JWT":{"main":[[{"node":"If","type":"main","index":0}]]},"Edit Fields":{"main":[[{"node":"Validar JWT","type":"main","index":0}]]}}	2025-11-03 12:05:02.274+00	2025-11-13 20:05:45.381+00	{"executionOrder":"v1"}	\N	{}	afe046a3-cca1-4d0b-8293-2da25723b203	1	qfFXbb2EsUXoOzp8	{"templateCredsSetupCompleted":true}	\N	t
Login Simples	f	[{"parameters":{"httpMethod":"POST","path":"login-simples","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-656,0],"id":"14488209-ceff-44a1-a124-a15ab8766481","name":"Webhook","webhookId":"873893cc-250d-4d0d-a6d4-294af4eca275"},{"parameters":{"operation":"executeQuery","query":"SELECT papel, nome_completo, username, id\\nFROM (\\n  SELECT 'administrador' AS papel, nome_completo, username, id, 1 AS prio\\n  FROM pessoa.administrador_s\\n  WHERE username = $1 AND senha = $2 AND ativo = true\\n\\n  UNION ALL\\n\\n  SELECT 'operador' AS papel, nome_completo, username, id, 2 AS prio\\n  FROM pessoa.operador_s\\n  WHERE username = $1 AND senha = $2 AND ativo = true\\n) t\\nORDER BY prio\\nLIMIT 1;\\n","options":{"queryReplacement":"={{$json.body.username}}\\n{{$json.body.password}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-448,0],"id":"fdcf6831-7fcd-4f82-abba-bf05b0204e42","name":"Execute a SQL query","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"08e24ae5-f4e1-4f72-8c98-76ad9fe441c5","leftValue":"={{$items().length > 0}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-256,0],"id":"63857c16-03e3-49f0-82b2-d938f6d5557a","name":"If"},{"parameters":{"respondWith":"json","responseBody":"={{ { ok: false, mensagem: 'Usuário ou senha inválidos' } }}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-32,96],"id":"556d4329-20c8-46fd-a63d-375a1b9cc480","name":"Respond to Webhook1"},{"parameters":{"mode":"raw","jsonOutput":"={\\n  \\"ok\\": true,\\n  \\"papel\\": \\"={{$json.papel}}\\",\\n  \\"nome\\": \\"={{$json.nome_completo}}\\",\\n  \\"username\\": \\"={{$json.username}}\\",\\n  \\"user_id\\": \\"={{$json.id}}\\",\\n  \\"mensagem\\": \\"Login aceito\\"\\n}","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-32,-48],"id":"236f4a67-a83f-4d04-9e4e-6368c9881357","name":"Edit Fields"},{"parameters":{"respondWith":"json","responseBody":"={{$json}}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[176,-48],"id":"93aa80ad-b2af-470f-85d2-a42c5a984091","name":"Respond to Webhook"}]	{"Webhook":{"main":[[{"node":"Execute a SQL query","type":"main","index":0}]]},"Execute a SQL query":{"main":[[{"node":"If","type":"main","index":0}]]},"If":{"main":[[{"node":"Edit Fields","type":"main","index":0}],[{"node":"Respond to Webhook1","type":"main","index":0}]]},"Edit Fields":{"main":[[{"node":"Respond to Webhook","type":"main","index":0}]]}}	2025-11-03 19:12:00.845+00	2025-11-13 20:06:12.237+00	{"executionOrder":"v1"}	\N	{}	88e4c3fb-79f0-4448-9d34-2b57a70d9cba	1	C7doPKElvmTnprHd	{"templateCredsSetupCompleted":true}	\N	t
SEAP	f	[{"parameters":{"httpMethod":"POST","path":"login-test","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[0,0],"id":"ec33545f-bebe-4549-a735-875d48301be6","name":"Webhook","webhookId":"112510ef-b0fe-465c-904c-bbb9f386878e"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"a5d34825-6695-4ddb-8d0b-1f6af83056af","leftValue":"={{ $json.body.username }}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}},{"id":"8b04ff01-ac03-487c-82be-f8ce055d414c","leftValue":"={{ $json.body.password }}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[256,0],"id":"789f68f7-8fba-4703-9616-2092b6576d2c","name":"If"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": true\\n}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[464,-96],"id":"8941de43-b47a-406f-b074-74662aa3ca3b","name":"Respond to Webhook"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"error\\":\\"faltam campos\\"\\n}","options":{"responseCode":400}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[464,96],"id":"67bf74ef-6a31-487b-9054-acd0e668bbc1","name":"Respond to Webhook1"}]	{"Webhook":{"main":[[{"node":"If","type":"main","index":0}]]},"If":{"main":[[{"node":"Respond to Webhook","type":"main","index":0}],[{"node":"Respond to Webhook1","type":"main","index":0}]]}}	2025-11-01 12:52:09.082+00	2025-11-06 10:40:34.017+00	{"executionOrder":"v1"}	\N	{}	0e5250cb-8e43-4959-8722-d9acaea1b7c5	1	W34KHQno95soj6Ka	\N	\N	t
Checklist (protegido) copy 3	f	[{"parameters":{"httpMethod":"POST","path":"85beb5af-5f8e-4943-95ba-b6d765093477","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-112,0],"id":"81d9851b-ebf9-480f-a916-06ddc1864ec0","name":"Webhook","webhookId":"85beb5af-5f8e-4943-95ba-b6d765093477"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": true,\\n  \\"token_preview\\": \\"{{ JSON.stringify($json.token).slice(0,24) }}...\\"\\n}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[144,-432],"id":"63764ade-ffca-423f-894c-b4fd7ace9d43","name":"Respond to Webhook"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3e40b949-272d-406f-acd2-ab8c79245a52","leftValue":"=={{$json.not_expired}}","rightValue":"=={{true}}","operator":{"type":"string","operation":"equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[528,0],"id":"09b2eab8-398a-49cb-93e1-367c275d339f","name":"If","alwaysOutputData":true},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": {\\n    \\"id\\": \\"{{ $json.sub }}\\",\\n    \\"perfil\\": \\"{{ $json.perfil }}\\",\\n    \\"username\\": \\"{{ $json.username }}\\",\\n    \\"nome\\": \\"{{ $json.nome }}\\",\\n    \\"email\\": \\"{{ $json.email }}\\"\\n  }\\n}\\n","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,-64],"id":"4cb28063-6153-422f-a587-2bd8241a2a66","name":"Respond 200 (JSON)"},{"parameters":{"respondWith":"json","responseBody":"{\\n  \\"ok\\": false, \\"error\\": \\"Token inválido ou expirado\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[736,80],"id":"f096201b-9a63-4920-bec8-300fde20767b","name":"Resond 401 (JSON)"},{"parameters":{"operation":"executeQuery","query":"SELECT\\n  translate(\\n    rtrim(\\n      encode(\\n        pessoa.hmac(convert_to('probe','utf8'), convert_to($1::text,'utf8'), 'sha256'),\\n        'base64'\\n      ),\\n      '='\\n    ),\\n    '+/',\\n    '-_'\\n  ) AS fp;","options":{"queryReplacement":"=={{$env.JWT_SECRET}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[368,-432],"id":"17e8292f-26ed-496a-bf3c-7a27f2bb83a8","name":"Execute a SQL query1","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"operation":"executeQuery","query":"WITH parts AS (\\n  SELECT\\n    split_part($1, '.', 1) AS h,\\n    split_part($1, '.', 2) AS p,\\n    split_part($1, '.', 3) AS s\\n),\\ncalc AS (\\n  SELECT\\n    pessoa.hmac(\\n      convert_to(h || '.' || p, 'utf8'),\\n      convert_to($2::text, 'utf8'),\\n      'sha256'::text\\n    ) AS c_bytes,\\n    h, p, s\\n  FROM parts\\n),\\nrecv AS (\\n  SELECT\\n    decode(\\n      translate(s, '-_', '+/')\\n      || repeat('=', (4 - length(s) % 4) % 4),\\n      'base64'\\n    ) AS r_bytes,\\n    h, p, s\\n  FROM parts\\n),\\nfp AS (\\n\\n  SELECT left(\\n    translate(\\n      rtrim(\\n        encode(\\n          pessoa.hmac(convert_to('probe','utf8'),\\n                      convert_to($2::text,'utf8'),\\n                      'sha256'::text),\\n          'base64'\\n        ),\\n        '='\\n      ),\\n      '+/', '-_'\\n    ), 16\\n  ) AS secret_fp\\n)\\nSELECT\\n\\n  (c_bytes = r_bytes) AS bytes_equal,\\n\\n  left(encode(c_bytes,'base64'), 16) AS calc_b64_pre,\\n  left(encode(r_bytes,'base64'), 16) AS recv_b64_pre,\\n\\n  (\\n    translate(rtrim(encode(c_bytes,'base64'), '='), '+/', '-_') =\\n    translate(rtrim(s,        '='),             '+/', '-_')\\n  ) AS url_equal,\\n\\n  left(h, 16) AS h_seg,\\n  left(p, 16) AS p_seg,\\n\\n  left(convert_from(decode(translate(h,'-_','+/') || repeat('=',(4 - length(h) % 4) % 4),'base64'),'utf8'), 32) AS header_json_pre,\\n  left(convert_from(decode(translate(p,'-_','+/') || repeat('=',(4 - length(p) % 4) % 4),'base64'),'base64'),'utf8'), 32) AS payload_json_pre,\\n\\n  (SELECT secret_fp FROM fp) AS secret_fp,\\n\\n  length($1) AS token_len,\\n  length(h)  AS h_len,\\n  length(p)  AS p_len,\\n  length(s)  AS s_len;","options":{"queryReplacement":"=={{$json.token}}\\n={{$env.JWT_SECRET}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[320,-192],"id":"5b11e4b3-43c8-4894-89aa-a04c6bef2a50","name":"Validar JWT","alwaysOutputData":true,"credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"language":"python","pythonCode":"import os, hmac, hashlib, base64, json, time, re\\n\\ndef b64u_to_b64(s: str) -> str:\\n    pad = \\"=\\" * ((4 - len(s) % 4) % 4)\\n    return s.replace(\\"-\\", \\"+\\").replace(\\"_\\", \\"/\\") + pad\\n\\ndef b64u_to_bytes(s: str) -> bytes:\\n    return base64.b64decode(b64u_to_b64(s).encode())\\n\\ndef b64u_from_bytes(b: bytes) -> str:\\n    return base64.urlsafe_b64encode(b).decode().rstrip(\\"=\\")\\n\\n# ---------------------------\\n# LER O SEGREDO ANTES DO LOOP\\n# ---------------------------\\nfirst_json = (items[0].get(\\"json\\", {}) if items else {})\\nsecret_raw = str(first_json.get(\\"secret\\", \\"\\") or \\"\\").strip()\\n\\ndef key_candidates_from_secret(secret_str: str):\\n    \\"\\"\\"\\n    Gera candidatos de chave (bytes) a partir do segredo em possíveis formatos:\\n    - utf8 (texto puro)\\n    - hex (ex: 64 chars hex -> 32 bytes)\\n    - base64 (RFC, com + e /)\\n    - base64url (com - e _)\\n    Retorna lista de tuplas (key_bytes, mode).\\n    \\"\\"\\"\\n    cands = []\\n    # 1) UTF-8 puro\\n    if secret_str:\\n        cands.append((secret_str.encode(), \\"utf8\\"))\\n\\n    # 2) HEX (somente se parecer hex válido e comprimento par)\\n    if secret_str and re.fullmatch(r\\"[0-9a-fA-F]+\\", secret_str) and len(secret_str) % 2 == 0:\\n        try:\\n            cands.append((bytes.fromhex(secret_str), \\"hex\\"))\\n        except Exception:\\n            pass\\n\\n    # 3) base64 \\"normal\\"\\n    if secret_str and ((\\"+\\" in secret_str) or (\\"/\\" in secret_str) or (\\"=\\" in secret_str)):\\n        try:\\n            cands.append((base64.b64decode(secret_str), \\"base64\\"))\\n        except Exception:\\n            pass\\n\\n    # 4) base64url\\n    if secret_str and ((\\"-\\" in secret_str) or (\\"_\\" in secret_str)):\\n        try:\\n            cands.append((base64.urlsafe_b64decode(b64u_to_b64(secret_str)), \\"base64url\\"))\\n        except Exception:\\n            pass\\n\\n    # Remover duplicados por conteúdo\\n    seen = set()\\n    unique = []\\n    for kb, mode in cands:\\n        sig = (len(kb), kb[:8])  # pequeno fingerprint\\n        if sig not in seen:\\n            seen.add(sig)\\n            unique.append((kb, mode))\\n    return unique\\n\\nkey_candidates = key_candidates_from_secret(secret_raw)\\n\\n# fingerprint do segredo (do primeiro candidato, se existir) para debug\\ndef secret_fingerprint(kb: bytes) -> str:\\n    return b64u_from_bytes(hmac.new(kb, b\\"probe\\", hashlib.sha256).digest())[:16]\\n\\nsecret_fp = \\"\\"\\nif key_candidates:\\n    try:\\n        secret_fp = secret_fingerprint(key_candidates[0][0])\\n    except Exception:\\n        secret_fp = \\"\\"\\n\\nout = []\\n\\nfor item in items:\\n    tok = str(item.get(\\"json\\", {}).get(\\"token\\", \\"\\")).strip()\\n    parts = tok.split(\\".\\")\\n    if len(parts) != 3:\\n        out.append({\\"json\\": {\\n            \\"assinatura_ok\\": False, \\"not_expired\\": False,\\n            \\"error\\": \\"Token malformado\\",\\n            \\"token_len\\": len(tok),\\n            \\"secret_len\\": len(secret_raw),\\n            \\"secret_fp\\": secret_fp,\\n            \\"key_mode\\": None\\n        }})\\n        continue\\n\\n    h, p, s_recv = parts\\n    msg = f\\"{h}.{p}\\".encode()\\n\\n    assinatura_ok = False\\n    s_calc = \\"\\"\\n    key_mode_ok = None\\n\\n    # Tenta cada interpretação do segredo\\n    for key_bytes, mode in key_candidates or [(b\\"\\", \\"none\\")]:\\n        try:\\n            if key_bytes:\\n                s_try = b64u_from_bytes(hmac.new(key_bytes, msg, hashlib.sha256).digest())\\n                if hmac.compare_digest(s_try, s_recv):\\n                    assinatura_ok = True\\n                    s_calc = s_try\\n                    key_mode_ok = mode\\n                    break\\n                else:\\n                    # guarda último cálculo só para debug\\n                    s_calc = s_try\\n                    key_mode_ok = key_mode_ok or mode\\n        except Exception:\\n            pass\\n\\n    # decodifica payload (não depende da assinatura)\\n    try:\\n        payload_json = b64u_to_bytes(p).decode(\\"utf-8\\")\\n        claims = json.loads(payload_json)\\n    except Exception:\\n        claims = {}\\n\\n    now = int(time.time())\\n    exp_raw = claims.get(\\"exp\\", 0)\\n    try:\\n        exp = int(exp_raw)\\n    except Exception:\\n        exp = 0\\n\\n    not_expired = assinatura_ok and exp > now\\n\\n    out.append({\\n        \\"json\\": {\\n            \\"assinatura_ok\\": assinatura_ok,\\n            \\"recv_prefix\\": s_recv[:16],\\n            \\"calc_prefix\\": s_calc[:16] if s_calc else \\"\\",\\n            \\"token_len\\": len(tok),\\n            \\"h_len\\": len(h),\\n            \\"p_len\\": len(p),\\n            \\"s_len\\": len(s_recv),\\n            \\"msg_prefix\\": msg[:16].decode(errors=\\"ignore\\"),\\n            \\"secret_len\\": len(secret_raw),\\n            \\"secret_fp\\": secret_fp,\\n            \\"key_mode\\": key_mode_ok,  # <- qual formato do segredo validou\\n            \\"sub\\": claims.get(\\"sub\\"),\\n            \\"perfil\\": claims.get(\\"perfil\\"),\\n            \\"username\\": claims.get(\\"username\\"),\\n            \\"nome\\": claims.get(\\"nome\\"),\\n            \\"email\\": claims.get(\\"email\\"),\\n            \\"exp\\": exp,\\n            \\"now\\": now,\\n            \\"not_expired\\": not_expired\\n        }\\n    })\\n\\nreturn out"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[384,128],"id":"cea28527-1444-4066-9640-646a2522fc86","name":"Code in Python (Beta)"},{"parameters":{"mode":"raw","jsonOutput":"=={{ { token: (\\n  ($json.headers?.authorization || $json.headers?.Authorization || '')\\n      .replace(/^Bearer\\\\s+/, '')\\n      .replace(/\\\\s+/g, '')\\n) } }}\\n","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[64,0],"id":"f8b9c5e0-d42a-410c-8171-1a7cb9aa6b1d","name":"Set (token)"},{"parameters":{"mode":"raw","jsonOutput":"={{ { token: $json.token, secret: $env.JWT_SECRET } }}\\n","options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[208,0],"id":"7e740131-f4e7-4e7b-b683-434bc991f009","name":"Edit Fields"}]	{"Webhook":{"main":[[{"node":"Set (token)","type":"main","index":0}]]},"If":{"main":[[{"node":"Respond 200 (JSON)","type":"main","index":0}],[{"node":"Resond 401 (JSON)","type":"main","index":0}]]},"Execute a SQL query1":{"main":[[]]},"Validar JWT":{"main":[[]]},"Code in Python (Beta)":{"main":[[{"node":"If","type":"main","index":0}]]},"Set (token)":{"main":[[{"node":"Edit Fields","type":"main","index":0}]]},"Edit Fields":{"main":[[{"node":"Code in Python (Beta)","type":"main","index":0}]]}}	2025-11-05 15:13:27.092+00	2025-11-06 10:40:54.321+00	{"executionOrder":"v1"}	\N	{}	8d93c173-e690-4d24-94f5-7e42b0573bc9	1	LjG3YyJxvlVjtncY	{"templateCredsSetupCompleted":true}	\N	t
auth_core_validate	f	[{"parameters":{"inputSource":"passthrough"},"type":"n8n-nodes-base.executeWorkflowTrigger","typeVersion":1.1,"position":[-1056,0],"id":"796ff054-92fa-423a-9be1-70ecabfd12c5","name":"When Executed by Another Workflow"},{"parameters":{"assignments":{"assignments":[{"id":"031af9b5-cf23-46de-92b2-2c01aadbf0ea","name":"jwt","value":"={{ \\n  $json.jwt \\n    || $json.token \\n    || ($json.authorization || '').replace(/^Bearer\\\\s+/i, '') \\n    || ($json.headers?.authorization || '').replace(/^Bearer\\\\s+/i, '') \\n    || ($json.headers?.Authorization || '').replace(/^Bearer\\\\s+/i, '') \\n    || '' \\n}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-880,0],"id":"785ba2e0-ce32-4eb5-b9ca-86487bd39712","name":"get_token"},{"parameters":{"operation":"executeQuery","query":"WITH parts AS (\\n  SELECT split_part($1,'.',1) AS h, split_part($1,'.',2) AS p, split_part($1,'.',3) AS s\\n),\\nrecompute AS (\\n  SELECT\\n    REPLACE(encode(\\n      pessoa.hmac(convert_to(h || '.' || p,'utf8'), convert_to($2::text,'utf8'), 'sha256')\\n    ,'base64'), E'\\\\n','') AS s_b64,\\n    h, p, s\\n  FROM parts\\n),\\nnorm AS (\\n  SELECT\\n    translate(rtrim(s_b64,'='), '+/','-_') AS s_calc_norm,\\n    translate(rtrim(s,'='),     '+/','-_') AS s_recv_norm, h, p\\n  FROM recompute\\n),\\nok_sig AS (\\n  SELECT (s_calc_norm = s_recv_norm) AS assinatura_ok, h, p, s_calc_norm, s_recv_norm\\n  FROM norm\\n),\\npayload AS (\\n  SELECT convert_from(\\n           decode(translate(p,'-_','+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64'),\\n           'utf8'\\n         ) AS pl\\n  FROM ok_sig WHERE assinatura_ok\\n),\\nclaims AS (\\n  SELECT\\n    (pl::jsonb)->>'sub'      AS sub,\\n    (pl::jsonb)->>'perfil'   AS perfil,\\n    (pl::jsonb)->>'username' AS username,\\n    (pl::jsonb)->>'nome'     AS nome,\\n    (pl::jsonb)->>'email'    AS email,\\n    (pl::jsonb)->>'sid'      AS sid,           -- << NOVO\\n    ((pl::jsonb)->>'exp')::int AS exp\\n  FROM payload\\n)\\nSELECT\\n  COALESCE((SELECT assinatura_ok FROM ok_sig),false) AS assinatura_ok,\\n  (SELECT left(s_recv_norm,16) FROM ok_sig) AS recv_prefix,\\n  (SELECT left(s_calc_norm,16) FROM ok_sig) AS calc_prefix,\\n  (SELECT sub FROM claims)      AS sub,\\n  (SELECT perfil FROM claims)   AS perfil,\\n  (SELECT username FROM claims) AS username,\\n  (SELECT nome FROM claims)     AS nome,\\n  (SELECT email FROM claims)    AS email,\\n  (SELECT sid FROM claims)      AS sid,        -- << NOVO\\n  (SELECT exp FROM claims)      AS exp,\\n  CASE WHEN (SELECT exp FROM claims) IS NOT NULL\\n       THEN ((SELECT exp FROM claims) > EXTRACT(EPOCH FROM NOW())::int)\\n       ELSE false END AS not_expired;\\n","options":{"queryReplacement":"={{$json.jwt}}\\n{{$json.secret}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-480,0],"id":"71518fac-f997-41e4-95fe-3fd5bd692626","name":"validar_jwt_db","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"assignments":{"assignments":[{"id":"fb51056c-79ab-4580-ba26-a127ad683526","name":"secret","value":"={{$env.AUTH_JWT_SECRET}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-672,0],"id":"499899c1-d750-4e01-9eb8-3b1989ddeebf","name":"set_secret"}]	{"When Executed by Another Workflow":{"main":[[{"node":"get_token","type":"main","index":0}]]},"get_token":{"main":[[{"node":"set_secret","type":"main","index":0}]]},"set_secret":{"main":[[{"node":"validar_jwt_db","type":"main","index":0}]]}}	2025-11-06 11:21:04.946+00	2025-11-12 17:25:18.562+00	{"executionOrder":"v1"}	\N	{}	bdb30f7f-1e2b-4e28-a1eb-6b857be29bc0	0	4BlE5Bm4TsK4DI0T	{"templateCredsSetupCompleted":true}	\N	f
(deletar depois) Auth – Login (POST /auth/login)	f	[{"parameters":{"httpMethod":"POST","path":"auth/login","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-400,0],"id":"07b67b70-5f65-4218-9413-579ea551c0e4","name":"Webhook","webhookId":"102c24e6-ab2a-4cf6-833f-0f38945d5336"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"token\\": \\"{{$json.token}}\\",\\n  \\"user\\": {\\n    \\"id\\": \\"{{$json.id}}\\",\\n    \\"role\\": \\"{{$json.perfil}}\\",\\n    \\"username\\": \\"{{$json.username}}\\",\\n    \\"nome\\": \\"{{$json.nome_completo}}\\",\\n    \\"email\\": \\"{{$json.email}}\\"\\n  }\\n}\\n","options":{}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[432,-112],"id":"65d935fa-1a81-42e4-be0c-d340894c0831","name":"Respond to Webhook"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"ef3d2125-2d3d-4e26-8517-300eb484e37f","leftValue":"={{ $json.id }}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[0,0],"id":"76e19172-e0ed-4580-af07-242528092304","name":"If"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"error\\": \\"invalid_credentials\\",\\n  \\"message\\": \\"Usuário ou senha inválidos\\"\\n}\\n","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[160,176],"id":"a9d427de-edc4-449d-85f4-e685af7e2d0c","name":"Respond to Webhook1"},{"parameters":{"operation":"executeQuery","query":"WITH\\nheader AS (SELECT '{\\"alg\\":\\"HS256\\",\\"typ\\":\\"JWT\\"}'::text AS j),\\npayload AS (\\n  SELECT json_build_object(\\n    'sub',      $1::text,\\n    'perfil',   $2::text,\\n    'username', $3::text,\\n    'nome',     $4::text,\\n    'email',    $5::text,\\n    'iat',      EXTRACT(EPOCH FROM NOW())::int,\\n    'exp',      (EXTRACT(EPOCH FROM NOW())::int + 60*60)   -- 1h\\n  )::text AS j\\n),\\nparts AS (\\n  SELECT\\n    translate(rtrim(REPLACE(encode(convert_to(h.j,'utf8'),'base64'), E'\\\\n', ''), '='), '+/','-_') AS hb,\\n    translate(rtrim(REPLACE(encode(convert_to(p.j,'utf8'),'base64'), E'\\\\n', ''), '='), '+/','-_') AS pb\\n  FROM header h, payload p\\n),\\nsig AS (\\n  SELECT\\n    encode(\\n      pessoa.hmac(\\n        convert_to(hb || '.' || pb, 'utf8'),\\n        convert_to($6::text, 'utf8'),\\n        'sha256'::text\\n      ),\\n      'base64'\\n    ) AS sb64,\\n    hb, pb\\n  FROM parts\\n),\\nsigurl AS (\\n  SELECT\\n    translate(rtrim(REPLACE(sb64, E'\\\\n', ''), '='), '+/','-_') AS sb, \\n    hb, pb \\n  FROM sig\\n)\\nSELECT\\n  (hb || '.' || pb || '.' || sb) AS token,\\n  $1::text AS id,\\n  $2::text AS perfil,\\n  $3::text AS username,\\n  $4::text AS nome_completo,\\n  $5::text AS email\\nFROM sigurl;","options":{"queryReplacement":"={{$json.id}}\\n{{$json.perfil}}\\n{{$json.username}}\\n{{$json.nome_completo}}\\n{{$json.email}}\\n{{$env.AUTH_JWT_SECRET}}\\n"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[192,-112],"id":"8e3de820-70d2-4de7-b244-f3adaf443e82","name":"Gerar JWT","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"operation":"executeQuery","query":"WITH admin_match AS (\\n  SELECT\\n    'administrador'::text AS perfil,\\n    a.id,\\n    a.nome_completo,\\n    a.username::text AS username,\\n    a.email::text    AS email\\n  FROM pessoa.administrador a\\n  WHERE (a.username = $1 OR a.email = $1)\\n    AND a.password_hash = pessoa.crypt($2::text, a.password_hash::text)\\n),\\noper_match AS (\\n  SELECT\\n    'operador'::text AS perfil,\\n    o.id,\\n    o.nome_completo,\\n    o.username::text AS username,\\n    o.email::text    AS email\\n  FROM pessoa.operador o\\n  WHERE (o.username = $1 OR o.email = $1)\\n    AND o.password_hash = pessoa.crypt($2::text, o.password_hash::text)\\n)\\nSELECT * FROM admin_match\\nUNION ALL\\nSELECT * FROM oper_match\\nLIMIT 1;","options":{"queryReplacement":"={{$json.body.usuario || $json.body.username}}\\n{{$json.body.senha   || $json.body.password}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-160,0],"id":"943c06dd-449c-461d-935f-5caf022fd79e","name":"Consultar Usuario","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}}]	{"Webhook":{"main":[[{"node":"Consultar Usuario","type":"main","index":0}]]},"If":{"main":[[{"node":"Gerar JWT","type":"main","index":0}],[{"node":"Respond to Webhook1","type":"main","index":0}]]},"Consultar Usuario":{"main":[[{"node":"If","type":"main","index":0}]]},"Gerar JWT":{"main":[[{"node":"Respond to Webhook","type":"main","index":0}]]}}	2025-11-07 19:20:57.791+00	2025-11-13 20:03:58.351+00	{"executionOrder":"v1"}	\N	{}	0041cabf-d580-4469-9dc9-bf0ac20e8ba4	1	fdMSa5hpWmtIFdQr	{"templateCredsSetupCompleted":true}	\N	t
Forms — Lookup Operadores (GET)	f	[{"parameters":{"path":"forms/lookup/operadores","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-384,0],"id":"dee16ed0-acb2-4131-b99b-d8ba01509239","name":"Webhook","webhookId":"ba6d8ee5-4acc-46cf-ba93-85619ce0e184"},{"parameters":{"operation":"executeQuery","query":"SELECT id, nome_completo\\nFROM pessoa.operador\\nORDER BY nome_completo ASC;","options":{}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-192,0],"id":"dc0ebe8e-a26e-4666-83ff-8e081fb4b3bf","name":"Execute a SQL query","alwaysOutputData":true,"executeOnce":false,"credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"jsCode":"const rows = items.map(i => i.json);   // transforma em array de objetos puros\\nreturn [{ json: { data: rows } }];     // único item com { data: [...] }\\n"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[16,0],"id":"38682a76-14ea-48d6-b9ef-5205bfb95ae0","name":"Code in JavaScript"},{"parameters":{"respondWith":"json","responseBody":"={{ $json }}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[224,0],"id":"faabb29f-3f7e-4f3d-9fe8-b8697e36b962","name":"Respond to Webhook"}]	{"Webhook":{"main":[[{"node":"Execute a SQL query","type":"main","index":0}]]},"Execute a SQL query":{"main":[[{"node":"Code in JavaScript","type":"main","index":0}]]},"Code in JavaScript":{"main":[[{"node":"Respond to Webhook","type":"main","index":0}]]}}	2025-11-04 20:21:38.443+00	2025-11-16 18:36:45.435+00	{"executionOrder":"v1"}	\N	{}	d7b1e6e4-ef77-4843-af11-de146e70bff6	1	jVurKy5pOeALzztO	{"templateCredsSetupCompleted":true}	\N	f
Forms — Lookup Salas (GET)	f	[{"parameters":{"path":"forms/lookup/salas","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-400,-16],"id":"458901ba-1e32-4fd1-b7a0-3f24d2d04f14","name":"Webhook","webhookId":"4f48f5e2-76f2-42a0-a855-68de0f9ac642"},{"parameters":{"operation":"executeQuery","query":"SELECT id, nome\\nFROM cadastro.sala\\nWHERE ativo = true\\nORDER BY nome ASC;","options":{}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-208,-16],"id":"65e8268f-e5c1-4260-b58f-90818b24f31d","name":"pg_listar_salas","alwaysOutputData":true,"credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"jsCode":"// Espera entrada como array de objetos [{id, nome}, ...]\\nconst rows = items.map(i => i.json);\\nreturn [{ json: { data: rows } }];"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-32,-16],"id":"fad1c766-c763-4102-b343-c406d6f6eb58","name":"Code in JavaScript"},{"parameters":{"respondWith":"json","responseBody":"={{ $json }}","options":{}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[176,-16],"id":"469ae0ef-f0c1-4d32-b9dc-97f471a88e76","name":"Respond to Webhook"}]	{"Webhook":{"main":[[{"node":"pg_listar_salas","type":"main","index":0}]]},"pg_listar_salas":{"main":[[{"node":"Code in JavaScript","type":"main","index":0}]]},"Code in JavaScript":{"main":[[{"node":"Respond to Webhook","type":"main","index":0}]]}}	2025-11-04 20:15:49.073+00	2025-11-16 18:36:43.937+00	{"executionOrder":"v1"}	\N	{}	8fc933e3-f56f-46b0-b5f1-f187ad8e217f	1	o2JDfSsAnLMjdqpc	{"templateCredsSetupCompleted":true}	\N	f
api_whoami	f	[{"parameters":{"path":"whoami","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-688,16],"id":"fdd2f664-14b1-4538-b307-e285a6711e19","name":"Webhook","webhookId":"5d316747-d4ea-4aa8-9d34-0d17f6c46467"},{"parameters":{"workflowId":{"__rl":true,"value":"cywBx2YTJlWGMLcT","mode":"list","cachedResultUrl":"/workflow/cywBx2YTJlWGMLcT","cachedResultName":"auth_guard_jwt"},"workflowInputs":{"mappingMode":"defineBelow","value":{}},"options":{"waitForSubWorkflow":true}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-224,16],"id":"c6e524c8-d426-4273-8a93-9e5e3a39c242","name":"Call 'auth_guard_jwt'"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"8de42271-e979-4d07-a676-cb12e2ad5640","leftValue":"={{ $json.guard?.ok === true }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-16,16],"id":"699760f2-ab96-4ec1-adbb-4a2556bbdbf2","name":"If"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": {\\n    \\"id\\": \\"={{$json.auth_user.id}}\\",\\n    \\"username\\": \\"={{$json.auth_user.username}}\\",\\n    \\"name\\": \\"={{$json.auth_user.name}}\\",\\n    \\"email\\": \\"={{$json.auth_user.email}}\\"\\n  },\\n  \\"role\\": \\"={{$json.auth_user.role}}\\",\\n  \\"exp\\": \\"={{$json.auth_user.exp}}\\"\\n}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[192,-80],"id":"ff2fcd9e-7746-4069-86db-5a5c7f072c5c","name":"(200 OK)"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"unauthorized\\",\\n  \\"message\\": \\"={{$json.guard?.message || $json.guard?.error || 'Missing/invalid token'}}\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[192,112],"id":"89e4e672-c579-4d2f-8bc6-dcf5fd2afa3c","name":"(401 Unauthorized)"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"f066e455-e960-49d7-9760-487f64eee791","leftValue":"={{ !!$json.headers?.authorization }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-496,16],"id":"6e26cc04-218d-4e56-b36a-129b86c5c1e3","name":"IF has Authorization"},{"parameters":{"respondWith":"json","responseBody":"{ \\"error\\": \\"unauthorized\\", \\"message\\": \\"Missing Authorization header\\" }","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-224,208],"id":"8b91614b-05f1-41d5-8bf5-1150af4dc01f","name":"Respond to Webhook"}]	{"Webhook":{"main":[[{"node":"IF has Authorization","type":"main","index":0}]]},"Call 'auth_guard_jwt'":{"main":[[{"node":"If","type":"main","index":0}]]},"If":{"main":[[{"node":"(200 OK)","type":"main","index":0}],[{"node":"(401 Unauthorized)","type":"main","index":0}]]},"IF has Authorization":{"main":[[{"node":"Call 'auth_guard_jwt'","type":"main","index":0}],[{"node":"Respond to Webhook","type":"main","index":0}]]}}	2025-11-06 18:39:10.399+00	2025-11-16 18:36:46.752+00	{"executionOrder":"v1"}	\N	{}	a9b567e6-e189-4995-bab0-6f25899ade91	1	4pkUzc47GBCWOgIA	\N	\N	f
zz_auth_guard_test	f	[{"parameters":{"httpMethod":"POST","path":"test_guard_jwt","responseMode":"responseNode","options":{}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-464,0],"id":"579ab58e-6416-45fa-bd7f-15c56d0d33f7","name":"Webhook","webhookId":"4fe8f441-0069-41d9-9f18-99af0ff45425"},{"parameters":{"workflowId":{"__rl":true,"value":"cywBx2YTJlWGMLcT","mode":"list","cachedResultUrl":"/workflow/cywBx2YTJlWGMLcT","cachedResultName":"auth_guard_jwt"},"workflowInputs":{"mappingMode":"defineBelow","value":{}},"options":{}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-272,0],"id":"661d612f-0c1b-4304-8f07-d54257bbf696","name":"Call 'auth_guard_jwt'"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": \\"={{$json.auth_user?.username}}\\",\\n  \\"role\\": \\"={{$json.auth_user?.role}}\\"\\n}\\n","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[160,336],"id":"5dd55aa2-df67-4891-8dfc-f121d434f31f","name":"Respond to Webhook"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"baf7d0a8-7a2b-4c10-9786-619504d96baf","leftValue":"={{$json.guard?.ok}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-64,0],"id":"bf2296af-0f8b-4eee-bb6a-a7a10b62a73d","name":"if_guard_ok"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"error\\": \\"unauthorized\\",\\n  \\"message\\": \\"={{$json.guard?.message || 'Token inválido ou expirado.'}}\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[144,96],"id":"e4cba95d-d376-428a-b340-3041baa4f812","name":"resp_401"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"user\\": \\"={{$json.auth_user?.username}}\\",\\n  \\"role\\": \\"={{$json.auth_user?.role}}\\"\\n}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[144,-64],"id":"3bba8388-5b68-42f6-8522-57db872b59d0","name":"resp_200"}]	{"Webhook":{"main":[[{"node":"Call 'auth_guard_jwt'","type":"main","index":0}]]},"Call 'auth_guard_jwt'":{"main":[[{"node":"if_guard_ok","type":"main","index":0}]]},"if_guard_ok":{"main":[[{"node":"resp_200","type":"main","index":0}],[{"node":"resp_401","type":"main","index":0}]]}}	2025-11-06 12:14:45.405+00	2025-11-13 20:05:51.588+00	{"executionOrder":"v1"}	\N	{}	a210dd45-2814-4e11-b6b4-6903865b8843	0	ZZb4Ug62C2Q437AW	\N	\N	t
Auth — Logout (POST /auth/logout)	f	[{"parameters":{"httpMethod":"POST","path":"auth/logout","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-384,0],"id":"45f20dc0-da73-47ea-b1e3-b39a61c08132","name":"Webhook","webhookId":"20fdb850-0d74-4fc9-b375-c26ae148d9e1"},{"parameters":{"workflowId":{"__rl":true,"value":"cywBx2YTJlWGMLcT","mode":"list","cachedResultUrl":"/workflow/cywBx2YTJlWGMLcT","cachedResultName":"auth_guard_jwt"},"workflowInputs":{"mappingMode":"defineBelow","value":{}},"options":{}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-208,0],"id":"c525471e-4280-41c0-9590-9d9eb56479de","name":"Call 'auth_guard_jwt'"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"6a48263f-4810-4957-9474-260124825956","leftValue":"={{$json.guard?.ok}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-48,0],"id":"46c80e58-4e4d-4b96-8a02-1238d282767c","name":"If"},{"parameters":{"operation":"executeQuery","query":"UPDATE pessoa.auth_sessions\\n   SET revoked = true\\n WHERE id = $1::bigint\\n   AND user_id = $2::uuid\\n RETURNING id;","options":{"queryReplacement":"={{$json.sid}}\\n{{$json.sub}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[160,-96],"id":"fb1ab9b5-c020-401f-a49a-cf65f24d0747","name":"revoke_session","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"respondWith":"json","responseBody":"{\\"ok\\": true}","options":{"responseCode":200}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[368,-96],"id":"1c8689a0-3597-4ac5-85b6-eddc0eaf4a29","name":"Respond 200 (JSON)"},{"parameters":{"respondWith":"json","responseBody":"={\\"error\\":\\"unauthorized\\",\\"message\\":\\"Token inválido/expirado\\"}","options":{}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[160,96],"id":"ca4e0f83-72d1-4fad-ac25-8e3e76df3a72","name":"Respond 401 (JSON)"}]	{"Webhook":{"main":[[{"node":"Call 'auth_guard_jwt'","type":"main","index":0}]]},"Call 'auth_guard_jwt'":{"main":[[{"node":"If","type":"main","index":0}]]},"If":{"main":[[{"node":"revoke_session","type":"main","index":0}],[{"node":"Respond 401 (JSON)","type":"main","index":0}]]},"revoke_session":{"main":[[{"node":"Respond 200 (JSON)","type":"main","index":0}]]}}	2025-11-12 17:32:19.247+00	2025-11-13 20:04:11.718+00	{"executionOrder":"v1"}	\N	{}	1d8f7815-d1fe-435c-a79c-d70af1f0570f	0	nrlnee2fIu0zihQe	{"templateCredsSetupCompleted":true}	\N	t
Admin — Novo Operador (POST) copy	f	[{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3d4f5a66-3333-47e1-a7a0-333333333333","leftValue":"={{ !!$json.headers?.authorization }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-1088,112],"id":"1f1b6de2-1b8d-4316-bd18-a85fd4607764","name":"IF has Authorization"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"missing_authorization\\",\\n  \\"message\\": \\"Header Authorization ausente\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-1088,272],"id":"b4a60c4b-4fa4-40c4-90c5-81970f3943c3","name":"(401 Missing Authorization)"},{"parameters":{"workflowId":{"__rl":true,"value":"cywBx2YTJlWGMLcT","mode":"list","cachedResultUrl":"/workflow/cywBx2YTJlWGMLcT","cachedResultName":"auth_guard_jwt"},"workflowInputs":{"mappingMode":"defineBelow","value":{}},"options":{"waitForSubWorkflow":true}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-880,112],"id":"d40c6b20-9460-4800-bf42-69479c8a97f0","name":"Call 'auth_guard_jwt'"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"8de42271-7777-4d07-a676-777777777777","leftValue":"={{ $json.guard?.ok === true }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-704,112],"id":"fc8e6609-e0b0-4edd-93ee-2c01b74ad667","name":"if_guard_ok"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"unauthorized\\",\\n  \\"message\\": \\"={{$json.guard?.message || $json.guard?.error || 'Token inválido ou expirado'}}\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-448,240],"id":"e88e626d-2dab-4bc2-a11a-0a135199bd93","name":"(401 Unauthorized)"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"forbidden\\",\\n  \\"message\\": \\"Somente administradores podem criar operadores.\\"\\n}","options":{"responseCode":403}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-240,144],"id":"3c2bf5bd-cc94-427b-a89f-d2a4da754b72","name":"(403 Forbidden)"},{"parameters":{"jsCode":"// Dados do body (campos de texto do formulário)\\nconst b = $json.body || {};\\n\\nfunction trim(v) {\\n  return typeof v === 'string' ? v.trim() : '';\\n}\\n\\n// Normaliza campos de texto\\nconst data = {\\n  nome_completo: trim(b.nome_completo),\\n  email_lc: trim(b.email || '').toLowerCase(),\\n  username_lc: trim(b.username || b.nome_de_usuario || '').toLowerCase(),\\n  senha: trim(b.senha || '')\\n};\\n\\n// Monta foto_url se tiver arquivo enviado em $binary.foto\\nlet foto_url = '';\\nconst bin = $binary?.foto;\\n\\nif (bin) {\\n  // tenta pegar extensão pela metadata do n8n\\n  let ext = bin.fileExtension;\\n  if (!ext && bin.fileName && bin.fileName.includes('.')) {\\n    ext = bin.fileName.split('.').pop();\\n  }\\n  if (!ext) ext = 'jpg';\\n\\n  // Caminho físico dentro do container n8n (volume /files)\\n  // e que também será gravado no banco\\n  const usernameSafe = data.username_lc || 'sem_username';\\n  const ts = Date.now(); // timestamp p/ evitar colisão de nome\\n  foto_url = `/files/operadores/${usernameSafe}_${ts}.${ext}`;\\n}\\n\\n// Guarda no objeto data\\ndata.foto_url = foto_url;\\n\\n// Checa campos obrigatórios\\nconst faltantes = [];\\nif (!data.nome_completo) faltantes.push('nome_completo');\\nif (!data.email_lc)      faltantes.push('email');\\nif (!data.username_lc)   faltantes.push('username');\\nif (!data.senha)         faltantes.push('senha');\\n\\nreturn [\\n  {\\n    json: {\\n      data,\\n      faltantes\\n    },\\n    binary: $binary   // mantém o binário disponível pros próximos nós\\n  }\\n];\\n"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-240,-96],"id":"129aed35-596f-4079-a925-a44f7cbb158f","name":"normalize_input"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"11112222-eeee-4333-aaaa-eeeeeeeeeeee","leftValue":"={{ $json.faltantes.length === 0 }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-96,-96],"id":"501f55e5-8dbd-49e7-b719-34a3dae940a5","name":"if_required_ok"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"invalid_payload\\",\\n  \\"missing\\": \\"={{ $json.faltantes.join(', ') }}\\"\\n}","options":{"responseCode":400}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[304,32],"id":"21f10609-28ef-4625-a042-7a7212f05547","name":"(400 Bad Request)"},{"parameters":{"operation":"executeQuery","query":"SELECT\\n  EXISTS(SELECT 1 FROM pessoa.operador WHERE lower(email) = lower($1)) AS email_exists,\\n  EXISTS(SELECT 1 FROM pessoa.operador WHERE lower(username) = lower($2)) AS username_exists;","options":{"queryReplacement":"={{$json.data.email_lc}}\\n{{$json.data.username_lc}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[272,-224],"id":"f615e26a-e637-4e02-9415-3ed36e86b5de","name":"pg_check_duplicates","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"55556666-2222-4777-eeee-222222222222","leftValue":"={{ $json.email_exists === true || $json.username_exists === true }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[512,-224],"id":"a193f872-47e4-44ae-b447-623a8d849cc1","name":"if_conflict"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"conflict\\",\\n  \\"message\\": \\"={{ $json.email_exists && $json.username_exists ? 'E-mail e usuário já cadastrados' : ($json.email_exists ? 'E-mail já cadastrado' : 'Nome de usuário já cadastrado') }}\\"\\n}","options":{"responseCode":409}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[720,-96],"id":"178c7dfd-7523-4ec9-acec-7e6f9680d61f","name":"(409 Conflict)"},{"parameters":{"operation":"executeQuery","query":"INSERT INTO pessoa.operador (nome_completo, email, username, password_hash, foto_url)\\n  VALUES ($1::text, lower($2::text), lower($3::text), crypt($4::text, gen_salt('bf')), NULLIF($5::text,''))\\n  RETURNING id, nome_completo, email, username, foto_url;","options":{"queryReplacement":"={{$json.data.nome_completo}}\\n{{$json.data.email_lc}}\\n{{$json.data.username_lc}}\\n{{$json.data.senha}}\\n{{$json.data.foto_url}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[720,-336],"id":"74570667-3afa-4b14-806c-92be227105a2","name":"pg_insert_operador","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"operador\\": {\\n    \\"id\\": \\"={{$json.id}}\\",\\n    \\"nome_completo\\": \\"={{$json.nome_completo}}\\",\\n    \\"email\\": \\"={{$json.email}}\\",\\n    \\"username\\": \\"={{$json.username}}\\",\\n    \\"foto_url\\": \\"={{$json.foto_url || ''}}\\"\\n  }\\n}","options":{"responseCode":201}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[928,-336],"id":"b396160b-bc5f-4a62-90c7-4a708d27f286","name":"(201 Created)"},{"parameters":{"httpMethod":"POST","path":"fa274f7b-d4dd-4653-acb8-030ced97d302","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud","binaryPropertyName":"foto"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-1296,112],"id":"c61e24a6-0794-41d6-977b-fee10c4907df","name":"Webhook1","webhookId":"fa274f7b-d4dd-4653-acb8-030ced97d302"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"92452ef6-498d-4cfc-9a62-194f030ec71f","leftValue":"={{ $json.auth_user.role }}","rightValue":"administrador","operator":{"type":"string","operation":"equals","name":"filter.operator.equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-448,16],"id":"df0d7619-5a3f-435e-b1eb-31e48e631ea7","name":"if_is_admin"}]	{"IF has Authorization":{"main":[[{"node":"Call 'auth_guard_jwt'","type":"main","index":0}],[{"node":"(401 Missing Authorization)","type":"main","index":0}]]},"Call 'auth_guard_jwt'":{"main":[[{"node":"if_guard_ok","type":"main","index":0}]]},"if_guard_ok":{"main":[[{"node":"if_is_admin","type":"main","index":0}],[{"node":"(401 Unauthorized)","type":"main","index":0}]]},"normalize_input":{"main":[[{"node":"if_required_ok","type":"main","index":0}]]},"if_required_ok":{"main":[[{"node":"pg_check_duplicates","type":"main","index":0}],[{"node":"(400 Bad Request)","type":"main","index":0}]]},"pg_check_duplicates":{"main":[[{"node":"if_conflict","type":"main","index":0}]]},"if_conflict":{"main":[[{"node":"pg_insert_operador","type":"main","index":0}],[{"node":"(409 Conflict)","type":"main","index":0}]]},"pg_insert_operador":{"main":[[{"node":"(201 Created)","type":"main","index":0}]]},"Webhook1":{"main":[[{"node":"IF has Authorization","type":"main","index":0}]]},"if_is_admin":{"main":[[{"node":"normalize_input","type":"main","index":0}],[{"node":"(403 Forbidden)","type":"main","index":0}]]}}	2025-11-14 17:10:16.485+00	2025-11-14 17:10:16.485+00	{"executionOrder":"v1"}	\N	{}	0b81ebec-1d34-448d-97da-1825084371ed	0	hkcmgIUIQyxJs6i1	\N	\N	f
auth_guard_jwt	f	[{"parameters":{"inputSource":"passthrough"},"type":"n8n-nodes-base.executeWorkflowTrigger","typeVersion":1.1,"position":[-1296,-48],"id":"1fcc8351-45c5-4846-b0af-43461b60b11b","name":"When Executed by Another Workflow"},{"parameters":{"assignments":{"assignments":[{"id":"b810eea7-5f45-45fa-afd7-ab109f656cf7","name":"authorization","value":"={{$json.headers.authorization || $json.headers.Authorization || ''}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-1120,-48],"id":"375fd22e-4d2c-43a9-a8a6-70097667bd3b","name":"set_from_incoming"},{"parameters":{"jsCode":"const auth = String($json.authorization || '').trim();\\nconst m = auth.match(/^Bearer\\\\s+(.+)$/i);\\nreturn [{ token: m ? m[1] : '' }];"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-960,-48],"id":"fdc3cb9d-7585-4a0f-99c6-f2ce83828194","name":"parse_bearer"},{"parameters":{"assignments":{"assignments":[{"id":"45ac10bf-a396-4787-bc02-b7483fb9886a","name":"jwt","value":"={{$json.token}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-784,-48],"id":"271ecf3f-904f-4275-b33a-7b730e6fcb65","name":"set_jwt"},{"parameters":{"workflowId":{"__rl":true,"value":"4BlE5Bm4TsK4DI0T","mode":"list","cachedResultUrl":"/workflow/4BlE5Bm4TsK4DI0T","cachedResultName":"auth_core_validate"},"workflowInputs":{"mappingMode":"defineBelow","value":{},"matchingColumns":[],"schema":[],"attemptToConvertTypes":false,"convertFieldsToString":true},"options":{}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-608,-48],"id":"91c214eb-9013-4342-8cdb-5c6762749e2b","name":"call_auth_core_validate"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"eed2c25a-f355-4d16-b2ca-027ee054c39f","leftValue":"={{$json.assinatura_ok}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}},{"id":"3aa93b0a-87ee-4a54-b79d-c4f4d64b1721","leftValue":"={{$json.not_expired}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}},{"id":"ab97695e-c889-4b8a-bef7-34966f0a77a8","leftValue":"={{$json.recv_prefix}}","rightValue":"={{$json.calc_prefix}}","operator":{"type":"string","operation":"equals","name":"filter.operator.equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-432,-48],"id":"fe286b3f-4a9e-47fc-8a61-c2a8da8e71b8","name":"if_token_ok"},{"parameters":{"assignments":{"assignments":[{"id":"4f93bcf6-cfa0-4a15-9da4-c7e8106e6077","name":"auth_user.id","value":"={{$json.sub}}","type":"string"},{"id":"b50dee04-8fee-49ee-bfbb-0f35927a28e2","name":"auth_user.role","value":"={{$json.perfil}}","type":"string"},{"id":"06c89c36-5367-4154-8741-e0be8905fce1","name":"auth_user.username","value":"={{$json.username}}","type":"string"},{"id":"9aa32720-3aff-4da7-8dad-c2302d15e0b0","name":"auth_user.name","value":"={{$json.nome}}","type":"string"},{"id":"62a77b73-6aa7-493c-9a99-7c99e7ca00b4","name":"auth_user.email","value":"={{$json.email}}","type":"string"},{"id":"b41179e7-771a-4361-8fca-2cb63b1b3124","name":"auth_user.exp","value":"={{$json.exp}}","type":"number"},{"id":"5120c096-e92c-4638-b905-c96c7369a26a","name":"auth_user.token_prefix_ok","value":"={{$json.recv_prefix === $json.calc_prefix}}","type":"boolean"},{"id":"868698ab-26d6-404f-8620-e583c115e2e5","name":"guard.ok","value":true,"type":"boolean"},{"id":"cf788099-cf80-47b2-9268-640f1e0666ba","name":"auth_user.sid","value":"={{$json.sid}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[112,-160],"id":"ba5a663c-5e61-4717-be90-8b0457bb8681","name":"set_auth_user"},{"parameters":{"assignments":{"assignments":[{"id":"e1f8f9bf-c0a1-4345-8e38-dbe3fe2eb014","name":"guard.ok","value":false,"type":"boolean"},{"id":"1a5c029c-fb73-4b73-a2db-179f49c3c01f","name":"guard.error","value":"unauthorized","type":"string"},{"id":"25a69e49-b7b3-4803-9342-333db5457c8a","name":"guard.message","value":"Token inválido ou expirado.","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-240,80],"id":"448b43fe-5d4f-4a43-ad51-bf608eb8189c","name":"set_guard_fail"},{"parameters":{"operation":"executeQuery","query":"WITH upd AS (\\n  UPDATE pessoa.auth_sessions\\n     SET last_activity = NOW()\\n   WHERE id      = $1::bigint\\n     AND user_id = $2::uuid\\n     AND revoked = false\\n     AND NOW() - last_activity <= INTERVAL '2 minutes'\\n   RETURNING id\\n)\\nSELECT\\n  upd.id::bigint  AS session_id,\\n  $1::bigint      AS sid,\\n  $2::uuid        AS sub,\\n  $3::text        AS perfil,\\n  $4::text        AS username,\\n  $5::text        AS nome,\\n  $6::text        AS email,\\n  $7::int         AS exp\\nFROM upd;","options":{"queryReplacement":"={{$json.sid}}\\n{{$json.sub}}\\n{{$json.perfil}}\\n{{$json.username}}\\n{{$json.nome}}\\n{{$json.email}}\\n{{$json.exp}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-240,-144],"id":"241f2bcd-797b-452d-a6b3-c56466fa9d3a","name":"session_touch","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3bc39a13-708a-4e2f-90b0-cb19a8ff08cb","leftValue":"={{$json.session_id}}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-96,-144],"id":"2cd7048c-dd2f-492a-bb93-eebef530d1a3","name":"if_session_ok"},{"parameters":{"assignments":{"assignments":[{"id":"e1f8f9bf-c0a1-4345-8e38-dbe3fe2eb014","name":"guard.ok","value":false,"type":"boolean"},{"id":"1a5c029c-fb73-4b73-a2db-179f49c3c01f","name":"guard.error","value":"unauthorized","type":"string"},{"id":"25a69e49-b7b3-4803-9342-333db5457c8a","name":"guard.message","value":"Token inválido ou expirado.","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[112,16],"id":"4911d7ad-25e9-47b4-a615-88380ed29311","name":"set_guard_fail1"}]	{"When Executed by Another Workflow":{"main":[[{"node":"set_from_incoming","type":"main","index":0}]]},"set_from_incoming":{"main":[[{"node":"parse_bearer","type":"main","index":0}]]},"parse_bearer":{"main":[[{"node":"set_jwt","type":"main","index":0}]]},"set_jwt":{"main":[[{"node":"call_auth_core_validate","type":"main","index":0}]]},"call_auth_core_validate":{"main":[[{"node":"if_token_ok","type":"main","index":0}]]},"if_token_ok":{"main":[[{"node":"session_touch","type":"main","index":0}],[{"node":"set_guard_fail","type":"main","index":0}]]},"session_touch":{"main":[[{"node":"if_session_ok","type":"main","index":0}]]},"if_session_ok":{"main":[[{"node":"set_auth_user","type":"main","index":0}],[{"node":"set_guard_fail1","type":"main","index":0}]]}}	2025-11-14 21:54:57.655+00	2025-11-14 21:56:43.559+00	{"executionOrder":"v1"}	\N	{}	cb5ab815-619d-4c9c-870c-78516e114233	0	O1dbhAXPba2j0zYd	\N	\N	t
auth_guard_jwt	f	[{"parameters":{"inputSource":"passthrough"},"type":"n8n-nodes-base.executeWorkflowTrigger","typeVersion":1.1,"position":[-720,16],"id":"1ca2aa41-c9d0-4fab-9e2a-fc9b0d362d9e","name":"When Executed by Another Workflow"},{"parameters":{"assignments":{"assignments":[{"id":"b810eea7-5f45-45fa-afd7-ab109f656cf7","name":"authorization","value":"={{$json.headers.authorization || $json.headers.Authorization || ''}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-544,16],"id":"554c6f05-caa4-40c4-9e90-8ff7646b7e6e","name":"set_from_incoming"},{"parameters":{"jsCode":"const auth = String($json.authorization || '').trim();\\nconst m = auth.match(/^Bearer\\\\s+(.+)$/i);\\nreturn [{ token: m ? m[1] : '' }];"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-384,16],"id":"d325ea86-485a-4dba-9d35-756dc6529acb","name":"parse_bearer"},{"parameters":{"assignments":{"assignments":[{"id":"45ac10bf-a396-4787-bc02-b7483fb9886a","name":"jwt","value":"={{$json.token}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[-208,16],"id":"0ce378ca-c380-4bc7-a90f-faa4f35963c0","name":"set_jwt"},{"parameters":{"workflowId":{"__rl":true,"value":"4BlE5Bm4TsK4DI0T","mode":"list","cachedResultUrl":"/workflow/4BlE5Bm4TsK4DI0T","cachedResultName":"auth_core_validate"},"workflowInputs":{"mappingMode":"defineBelow","value":{},"matchingColumns":[],"schema":[],"attemptToConvertTypes":false,"convertFieldsToString":true},"options":{}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-32,16],"id":"9bae588c-452d-4ee9-bc9b-abe5384a31d8","name":"call_auth_core_validate"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"eed2c25a-f355-4d16-b2ca-027ee054c39f","leftValue":"={{$json.assinatura_ok}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}},{"id":"3aa93b0a-87ee-4a54-b79d-c4f4d64b1721","leftValue":"={{$json.not_expired}}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}},{"id":"ab97695e-c889-4b8a-bef7-34966f0a77a8","leftValue":"={{$json.recv_prefix}}","rightValue":"={{$json.calc_prefix}}","operator":{"type":"string","operation":"equals","name":"filter.operator.equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[144,16],"id":"19b9f26e-1ae9-4b6b-b83f-5a2a2d3b0a3b","name":"if_token_ok"},{"parameters":{"assignments":{"assignments":[{"id":"4f93bcf6-cfa0-4a15-9da4-c7e8106e6077","name":"auth_user.id","value":"={{$json.sub}}","type":"string"},{"id":"b50dee04-8fee-49ee-bfbb-0f35927a28e2","name":"auth_user.role","value":"={{$json.perfil}}","type":"string"},{"id":"06c89c36-5367-4154-8741-e0be8905fce1","name":"auth_user.username","value":"={{$json.username}}","type":"string"},{"id":"9aa32720-3aff-4da7-8dad-c2302d15e0b0","name":"auth_user.name","value":"={{$json.nome}}","type":"string"},{"id":"62a77b73-6aa7-493c-9a99-7c99e7ca00b4","name":"auth_user.email","value":"={{$json.email}}","type":"string"},{"id":"b41179e7-771a-4361-8fca-2cb63b1b3124","name":"auth_user.exp","value":"={{$json.exp}}","type":"number"},{"id":"5120c096-e92c-4638-b905-c96c7369a26a","name":"auth_user.token_prefix_ok","value":"={{$json.recv_prefix === $json.calc_prefix}}","type":"boolean"},{"id":"868698ab-26d6-404f-8620-e583c115e2e5","name":"guard.ok","value":true,"type":"boolean"},{"id":"cf788099-cf80-47b2-9268-640f1e0666ba","name":"auth_user.sid","value":"={{$json.sid}}","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[688,-96],"id":"1e335c4d-8a36-49ac-9184-aa961589e341","name":"set_auth_user"},{"parameters":{"assignments":{"assignments":[{"id":"e1f8f9bf-c0a1-4345-8e38-dbe3fe2eb014","name":"guard.ok","value":false,"type":"boolean"},{"id":"1a5c029c-fb73-4b73-a2db-179f49c3c01f","name":"guard.error","value":"unauthorized","type":"string"},{"id":"25a69e49-b7b3-4803-9342-333db5457c8a","name":"guard.message","value":"Token inválido ou expirado.","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[336,144],"id":"1a14b42f-3ea8-4cef-89d6-b877e8cc4acc","name":"set_guard_fail"},{"parameters":{"operation":"executeQuery","query":"WITH upd AS (\\n  UPDATE pessoa.auth_sessions\\n     SET last_activity = NOW()\\n   WHERE id      = $1::bigint\\n     AND user_id = $2::uuid\\n     AND revoked = false\\n     AND NOW() - last_activity <= INTERVAL '15 minutes'\\n   RETURNING id\\n)\\nSELECT\\n  upd.id::bigint  AS session_id,\\n  $1::bigint      AS sid,\\n  $2::uuid        AS sub,\\n  $3::text        AS perfil,\\n  $4::text        AS username,\\n  $5::text        AS nome,\\n  $6::text        AS email,\\n  $7::int         AS exp\\nFROM upd;","options":{"queryReplacement":"={{$json.sid}}\\n{{$json.sub}}\\n{{$json.perfil}}\\n{{$json.username}}\\n{{$json.nome}}\\n{{$json.email}}\\n{{$json.exp}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[336,-80],"id":"b5f7975a-9c72-4b8a-b0b2-416d47ecc70d","name":"session_touch","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3bc39a13-708a-4e2f-90b0-cb19a8ff08cb","leftValue":"={{$json.session_id}}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[480,-80],"id":"afbc9f39-3781-451f-a735-47e00d69d5f5","name":"if_session_ok"},{"parameters":{"assignments":{"assignments":[{"id":"e1f8f9bf-c0a1-4345-8e38-dbe3fe2eb014","name":"guard.ok","value":false,"type":"boolean"},{"id":"1a5c029c-fb73-4b73-a2db-179f49c3c01f","name":"guard.error","value":"unauthorized","type":"string"},{"id":"25a69e49-b7b3-4803-9342-333db5457c8a","name":"guard.message","value":"Token inválido ou expirado.","type":"string"}]},"includeOtherFields":true,"options":{}},"type":"n8n-nodes-base.set","typeVersion":3.4,"position":[688,80],"id":"a158f905-5802-44bb-8019-8b185d042220","name":"set_guard_fail1"}]	{"When Executed by Another Workflow":{"main":[[{"node":"set_from_incoming","type":"main","index":0}]]},"set_from_incoming":{"main":[[{"node":"parse_bearer","type":"main","index":0}]]},"parse_bearer":{"main":[[{"node":"set_jwt","type":"main","index":0}]]},"set_jwt":{"main":[[{"node":"call_auth_core_validate","type":"main","index":0}]]},"call_auth_core_validate":{"main":[[{"node":"if_token_ok","type":"main","index":0}]]},"if_token_ok":{"main":[[{"node":"session_touch","type":"main","index":0}],[{"node":"set_guard_fail","type":"main","index":0}]]},"session_touch":{"main":[[{"node":"if_session_ok","type":"main","index":0}]]},"if_session_ok":{"main":[[{"node":"set_auth_user","type":"main","index":0}],[{"node":"set_guard_fail1","type":"main","index":0}]]}}	2025-11-06 10:41:34.606+00	2025-11-14 21:57:08.208+00	{"executionOrder":"v1"}	\N	{}	fac6487b-e5db-4d2c-bda1-8bc15a646cb1	0	cywBx2YTJlWGMLcT	{"templateCredsSetupCompleted":true}	\N	f
Admin — Novo Operador (POST)	f	[{"parameters":{"httpMethod":"POST","path":"admin/operadores/novo","responseMode":"responseNode","options":{"allowedOrigins":"https://senado-nusp.cloud","binaryPropertyName":"foto"}},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[-1728,320],"id":"ff446ab1-e568-40b2-9dcb-9db5d7fe3b72","name":"Webhook","webhookId":"8e77b6f0-2222-4db7-82aa-222222222222"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"3d4f5a66-3333-47e1-a7a0-333333333333","leftValue":"={{ !!$json.headers?.authorization }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-1520,320],"id":"1d420561-c9d2-46c1-acb7-d160ae8b432f","name":"IF has Authorization"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"missing_authorization\\",\\n  \\"message\\": \\"Header Authorization ausente\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-1520,480],"id":"87e55f00-7734-47c5-bebd-b565c93f7184","name":"(401 Missing Authorization)"},{"parameters":{"workflowId":{"__rl":true,"value":"cywBx2YTJlWGMLcT","mode":"list","cachedResultUrl":"/workflow/cywBx2YTJlWGMLcT","cachedResultName":"auth_guard_jwt"},"workflowInputs":{"mappingMode":"defineBelow","value":{}},"options":{"waitForSubWorkflow":true}},"type":"n8n-nodes-base.executeWorkflow","typeVersion":1.3,"position":[-1344,304],"id":"aafd2f09-cbe3-448e-ab99-82fe8e003acf","name":"Call 'auth_guard_jwt'"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"8de42271-7777-4d07-a676-777777777777","leftValue":"={{ $json.guard?.ok }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-1184,304],"id":"65c67eb7-2bc3-4220-9f73-b3a194dfc378","name":"if_guard_ok"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"unauthorized\\",\\n  \\"message\\": \\"={{$json.guard?.message || $json.guard?.error || 'Token inválido ou expirado'}}\\"\\n}","options":{"responseCode":401}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-1008,416],"id":"b1f2032f-1436-4c72-84bb-ffe0c87ed684","name":"(401 Unauthorized)"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"forbidden\\",\\n  \\"message\\": \\"Somente administradores podem criar operadores.\\"\\n}","options":{"responseCode":403}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-800,400],"id":"a9663082-1a9b-48b9-bd3d-93111ae06e3b","name":"(403 Forbidden)"},{"parameters":{"jsCode":"// Nó: normalize_input (JavaScript)\\n\\n// 1) Dados de entrada\\nconst original = $('Webhook').first();       // nome do nó é \\"Webhook\\"\\nconst root = original.json || {};\\nconst body = root.body || {};\\n\\n// 1.1) Captura robusta do binário: foto, foto0, foto1, etc.\\nfunction getFotoBinary(orig) {\\n  const b = (orig && orig.binary) || {};\\n  if (b.foto) return b.foto;\\n  const key = Object.keys(b).find(k => k === 'foto' || /^foto\\\\d+$/.test(k) || k.startsWith('foto'));\\n  return key ? b[key] : null;\\n}\\nconst bin = getFotoBinary(original);\\n\\n// 2) Helpers\\nconst trim = v => (typeof v === 'string' ? v.trim() : '');\\nfunction pick(...keys) {\\n  for (const k of keys) {\\n    const fromBody = body[k];\\n    if (typeof fromBody === 'string' && fromBody.trim() !== '') return fromBody;\\n    const fromRoot = root[k];\\n    if (typeof fromRoot === 'string' && fromRoot.trim() !== '') return fromRoot;\\n  }\\n  return '';\\n}\\n\\n// 3) Campos do formulário\\nconst data = {\\n  nome_completo: trim(pick('nome_completo')),\\n  email_lc:      trim(pick('email')).toLowerCase(),\\n  username_lc:   trim(pick('username', 'nome_de_usuario')).toLowerCase(),\\n  senha:         trim(pick('senha')),\\n};\\n\\n// 4) Construção de nomes/caminhos da foto (Opção A)\\nlet foto_filename = '';\\nlet foto_url = '';\\nlet foto_disk = '';\\n\\nif (bin) {\\n  // extensão\\n  let ext = bin.fileExtension;\\n  if (!ext && bin.fileName && bin.fileName.includes('.')) {\\n    ext = bin.fileName.split('.').pop();\\n  }\\n  if (!ext) ext = 'jpg';\\n\\n  const usernameSafe = data.username_lc || 'sem_username';\\n  const ts = Date.now();\\n  foto_filename = `${usernameSafe}_${ts}.${ext}`;\\n\\n  // URL pública para o front/banco\\n  foto_url = `/files/operadores/${foto_filename}`;\\n\\n  // Caminho físico seguro para o n8n gravar\\n  // (defina FILES_DIR no ambiente, senão cai no default)\\n  const FILES_DIR = process.env.FILES_DIR || '/home/node/.n8n/public';\\n  foto_disk = `${FILES_DIR.replace(/\\\\/$/, '')}/operadores/${foto_filename}`;\\n}\\n\\ndata.foto_filename = foto_filename;  // ex: usuario_1699999999999.jpg\\ndata.foto_url = foto_url;            // ex: /files/operadores/usuario_...jpg\\ndata.foto_disk = foto_disk;          // ex: /home/node/.n8n/public/operadores/usuario_...jpg\\n\\n// 5) Validação\\nconst faltantes = [];\\nif (!data.nome_completo) faltantes.push('nome_completo');\\nif (!data.email_lc)      faltantes.push('email');\\nif (!data.username_lc)   faltantes.push('username');\\nif (!data.senha)         faltantes.push('senha');\\n\\n// 6) Saída — mantém o binário (padronizado como `foto`)\\nreturn [{\\n  json: { data, faltantes },\\n  binary: (bin ? { foto: bin } : {})   // rebatiza como `foto` daqui pra frente\\n}];"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-800,192],"id":"772c4044-8b9d-4726-85f0-2e8100bb8f55","name":"normalize_input"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"11112222-eeee-4333-aaaa-eeeeeeeeeeee","leftValue":"={{ $json.faltantes.length === 0 }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-624,192],"id":"5b00ae00-5825-4f5b-bcd3-9fc9fe9c7502","name":"if_required_ok"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"invalid_payload\\",\\n  \\"missing\\": \\"={{ $json.faltantes.join(', ') }}\\"\\n}","options":{"responseCode":400}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[-448,352],"id":"43eeb93e-ed25-42de-bc8c-7e8765e1ae46","name":"(400 Bad Request)"},{"parameters":{"operation":"executeQuery","query":"SELECT\\n  EXISTS(SELECT 1 FROM pessoa.operador WHERE lower(email) = lower($1)) AS email_exists,\\n  EXISTS(SELECT 1 FROM pessoa.operador WHERE lower(username) = lower($2)) AS username_exists;","options":{"queryReplacement":"={{$json.data.email_lc}}\\n{{$json.data.username_lc}}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[-432,64],"id":"caa240e8-21c3-4f45-af4d-a82a51afe3d1","name":"pg_check_duplicates","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"55556666-2222-4777-eeee-222222222222","leftValue":"={{ $json.email_exists === true || $json.username_exists === true }}","rightValue":"","operator":{"type":"boolean","operation":"true","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-64,64],"id":"7a5d70fc-21ce-4d04-ae18-9129831ef5ab","name":"if_conflict"},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": false,\\n  \\"error\\": \\"conflict\\",\\n  \\"message\\": \\"={{ $json.email_exists && $json.username_exists ? 'E-mail e usuário já cadastrados' : ($json.email_exists ? 'E-mail já cadastrado' : 'Nome de usuário já cadastrado') }}\\"\\n}","options":{"responseCode":409}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[96,240],"id":"aa303840-908a-41eb-9f92-1c7712c05ecd","name":"(409 Conflict)"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"a1b2c3d4-1212-1313-1414-151515151515","leftValue":"={{$json.data.foto_url}}","rightValue":"","operator":{"type":"string","operation":"notEmpty","singleValue":true}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[112,16],"id":"67156468-4ace-45b8-9bd3-110757c599f2","name":"if_has_foto"},{"parameters":{"fileName":"={{ $json.data.foto_url }}","dataPropertyName":"foto","options":{}},"type":"n8n-nodes-base.writeBinaryFile","typeVersion":1,"position":[304,-96],"id":"1020fe89-88fb-4a8d-8745-b3a7282f13a3","name":"save_foto"},{"parameters":{"operation":"executeQuery","query":"INSERT INTO pessoa.operador\\n  (nome_completo, email, username, password_hash, foto_url)\\nVALUES\\n  ($1::text,\\n   lower($2::text),\\n   lower($3::text),\\n   /* use a mesma função de hash que você já usa no login */\\n   pessoa.crypt($4::text, pessoa.gen_salt('bf')),\\n   NULLIF(btrim($5::text), '')\\n  )\\nRETURNING id, nome_completo, email, username, foto_url;","options":{"queryReplacement":"={{$json.data.nome_completo}}\\n{{$json.data.email_lc}}\\n{{$json.data.username_lc}}\\n{{$json.data.senha}}\\n{{ $json.data.foto_url || ' ' }}"}},"type":"n8n-nodes-base.postgres","typeVersion":2.6,"position":[480,32],"id":"26f9233b-c602-489e-a458-645ced57b1ba","name":"pg_insert_operador","credentials":{"postgres":{"id":"6su8u1Ut25O71hCo","name":"Postgres account"}}},{"parameters":{"respondWith":"json","responseBody":"={\\n  \\"ok\\": true,\\n  \\"operador\\": {\\n    \\"id\\": \\"={{$json.id}}\\",\\n    \\"nome_completo\\": \\"={{$json.nome_completo}}\\",\\n    \\"email\\": \\"={{$json.email}}\\",\\n    \\"username\\": \\"={{$json.username}}\\",\\n    \\"foto_url\\": \\"={{$json.foto_url || ''}}\\"\\n  }\\n}","options":{"responseCode":201}},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[656,32],"id":"2e7372a9-4e32-453e-8f4f-6a1612c2f553","name":"(201 Created)"},{"parameters":{"conditions":{"options":{"caseSensitive":true,"leftValue":"","typeValidation":"strict","version":2},"conditions":[{"id":"70f02684-0ec7-47e9-9378-9f47233addbc","leftValue":"={{ $json.auth_user.role }}","rightValue":"administrador","operator":{"type":"string","operation":"equals","name":"filter.operator.equals"}}],"combinator":"and"},"options":{}},"type":"n8n-nodes-base.if","typeVersion":2.2,"position":[-1008,272],"id":"25287a0d-db82-45db-b9a3-5dc96c4b4eba","name":"if_is_admin"},{"parameters":{"jsCode":"// merge_duplicate_check (Code node — JavaScript, Run once for all items)\\n// Base: saída do normalize_input (tem data/faltantes e o binary.foto)\\nconst base = $('normalize_input').first();\\n\\nreturn [{\\n  json: {\\n    data: base.json.data,\\n    faltantes: base.json.faltantes,\\n    email_exists: $json.email_exists === true,\\n    username_exists: $json.username_exists === true\\n  },\\n  binary: base.binary  // mantém a foto aqui\\n}];\\n"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[-240,64],"id":"8719759c-5f69-4676-b9bc-2008d0bf16b8","name":"merge_duplicate_check"}]	{"Webhook":{"main":[[{"node":"IF has Authorization","type":"main","index":0}]]},"IF has Authorization":{"main":[[{"node":"Call 'auth_guard_jwt'","type":"main","index":0}],[{"node":"(401 Missing Authorization)","type":"main","index":0}]]},"Call 'auth_guard_jwt'":{"main":[[{"node":"if_guard_ok","type":"main","index":0}]]},"if_guard_ok":{"main":[[{"node":"if_is_admin","type":"main","index":0}],[{"node":"(401 Unauthorized)","type":"main","index":0}]]},"normalize_input":{"main":[[{"node":"if_required_ok","type":"main","index":0}]]},"if_required_ok":{"main":[[{"node":"pg_check_duplicates","type":"main","index":0}],[{"node":"(400 Bad Request)","type":"main","index":0}]]},"pg_check_duplicates":{"main":[[{"node":"merge_duplicate_check","type":"main","index":0}]]},"if_conflict":{"main":[[{"node":"(409 Conflict)","type":"main","index":0}],[{"node":"if_has_foto","type":"main","index":0}]]},"if_has_foto":{"main":[[{"node":"save_foto","type":"main","index":0}],[{"node":"pg_insert_operador","type":"main","index":0}]]},"save_foto":{"main":[[{"node":"pg_insert_operador","type":"main","index":0}]]},"pg_insert_operador":{"main":[[{"node":"(201 Created)","type":"main","index":0}]]},"if_is_admin":{"main":[[{"node":"normalize_input","type":"main","index":0}],[{"node":"(403 Forbidden)","type":"main","index":0}]]},"merge_duplicate_check":{"main":[[{"node":"if_conflict","type":"main","index":0}]]}}	2025-11-14 14:32:06.595+00	2025-11-16 18:36:40.072+00	{"executionOrder":"v1"}	\N	{}	deb79e2a-fdec-4695-8305-35a63a4b6012	1	r9WpwNYGB6LtAr5W	\N	\N	f
\.


--
-- Data for Name: workflow_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.workflow_history ("versionId", "workflowId", authors, "createdAt", "updatedAt", nodes, connections) FROM stdin;
\.


--
-- Data for Name: workflow_statistics; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.workflow_statistics (count, "latestEvent", name, "workflowId", "rootCount") FROM stdin;
\.


--
-- Data for Name: workflows_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.workflows_tags ("workflowId", "tagId") FROM stdin;
\.


--
-- Name: comissao_id_seq; Type: SEQUENCE SET; Schema: cadastro; Owner: -
--

SELECT pg_catalog.setval('cadastro.comissao_id_seq', 27, true);


--
-- Name: sala_id_seq; Type: SEQUENCE SET; Schema: cadastro; Owner: -
--

SELECT pg_catalog.setval('cadastro.sala_id_seq', 10, true);


--
-- Name: checklist_historico_id_seq; Type: SEQUENCE SET; Schema: forms; Owner: -
--

SELECT pg_catalog.setval('forms.checklist_historico_id_seq', 4, true);


--
-- Name: checklist_id_seq; Type: SEQUENCE SET; Schema: forms; Owner: -
--

SELECT pg_catalog.setval('forms.checklist_id_seq', 66, true);


--
-- Name: checklist_item_tipo_id_seq; Type: SEQUENCE SET; Schema: forms; Owner: -
--

SELECT pg_catalog.setval('forms.checklist_item_tipo_id_seq', 43, true);


--
-- Name: checklist_resposta_id_seq; Type: SEQUENCE SET; Schema: forms; Owner: -
--

SELECT pg_catalog.setval('forms.checklist_resposta_id_seq', 1050, true);


--
-- Name: checklist_sala_config_id_seq; Type: SEQUENCE SET; Schema: forms; Owner: -
--

SELECT pg_catalog.setval('forms.checklist_sala_config_id_seq', 213, true);


--
-- Name: registro_anormalidade_id_seq; Type: SEQUENCE SET; Schema: operacao; Owner: -
--

SELECT pg_catalog.setval('operacao.registro_anormalidade_id_seq', 1, true);


--
-- Name: registro_operacao_audio_id_seq; Type: SEQUENCE SET; Schema: operacao; Owner: -
--

SELECT pg_catalog.setval('operacao.registro_operacao_audio_id_seq', 16, true);


--
-- Name: registro_operacao_operador_historico_id_seq; Type: SEQUENCE SET; Schema: operacao; Owner: -
--

SELECT pg_catalog.setval('operacao.registro_operacao_operador_historico_id_seq', 1, false);


--
-- Name: registro_operacao_operador_id_seq; Type: SEQUENCE SET; Schema: operacao; Owner: -
--

SELECT pg_catalog.setval('operacao.registro_operacao_operador_id_seq', 19, true);


--
-- Name: administrador_s_id_seq; Type: SEQUENCE SET; Schema: pessoa; Owner: -
--

SELECT pg_catalog.setval('pessoa.administrador_s_id_seq', 1, false);


--
-- Name: auth_sessions_id_seq; Type: SEQUENCE SET; Schema: pessoa; Owner: -
--

SELECT pg_catalog.setval('pessoa.auth_sessions_id_seq', 248, true);


--
-- Name: operador_s_id_seq; Type: SEQUENCE SET; Schema: pessoa; Owner: -
--

SELECT pg_catalog.setval('pessoa.operador_s_id_seq', 1, false);


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 24, true);


--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_provider_sync_history_id_seq', 1, false);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_id_seq', 1, false);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_user_permissions_id_seq', 1, false);


--
-- Name: data_table_user_5EBBvwJHpAKSfA9V_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."data_table_user_5EBBvwJHpAKSfA9V_id_seq"', 1, false);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 6, true);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 18, true);


--
-- Name: execution_annotations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.execution_annotations_id_seq', 1, false);


--
-- Name: execution_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.execution_entity_id_seq', 1, false);


--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.execution_metadata_temp_id_seq', 1, false);


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.insights_by_period_id_seq', 1, false);


--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."insights_metadata_metaId_seq"', 1, false);


--
-- Name: insights_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.insights_raw_id_seq', 1, false);


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.migrations_id_seq', 106, true);


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.workflow_dependency_id_seq', 1, false);


--
-- Name: comissao comissao_pkey; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.comissao
    ADD CONSTRAINT comissao_pkey PRIMARY KEY (id);


--
-- Name: sala sala_nome_key; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.sala
    ADD CONSTRAINT sala_nome_key UNIQUE (nome);


--
-- Name: sala sala_pkey; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.sala
    ADD CONSTRAINT sala_pkey PRIMARY KEY (id);


--
-- Name: checklist_historico checklist_historico_pkey; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_historico
    ADD CONSTRAINT checklist_historico_pkey PRIMARY KEY (id);


--
-- Name: checklist_item_tipo checklist_item_tipo_pkey; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_item_tipo
    ADD CONSTRAINT checklist_item_tipo_pkey PRIMARY KEY (id);


--
-- Name: checklist checklist_pkey; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist
    ADD CONSTRAINT checklist_pkey PRIMARY KEY (id);


--
-- Name: checklist_resposta checklist_resposta_pkey; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_resposta
    ADD CONSTRAINT checklist_resposta_pkey PRIMARY KEY (id);


--
-- Name: checklist_sala_config checklist_sala_config_pkey; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_sala_config
    ADD CONSTRAINT checklist_sala_config_pkey PRIMARY KEY (id);


--
-- Name: checklist_resposta uq_cli_resp_checklist_item; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_resposta
    ADD CONSTRAINT uq_cli_resp_checklist_item UNIQUE (checklist_id, item_tipo_id);


--
-- Name: checklist_item_tipo uq_item_tipo_nome_widget; Type: CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_item_tipo
    ADD CONSTRAINT uq_item_tipo_nome_widget UNIQUE (nome, tipo_widget);


--
-- Name: registro_anormalidade_admin registro_anormalidade_admin_pkey; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade_admin
    ADD CONSTRAINT registro_anormalidade_admin_pkey PRIMARY KEY (registro_anormalidade_id);


--
-- Name: registro_anormalidade registro_anormalidade_pkey; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade
    ADD CONSTRAINT registro_anormalidade_pkey PRIMARY KEY (id);


--
-- Name: registro_operacao_audio registro_operacao_audio_pkey; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_audio
    ADD CONSTRAINT registro_operacao_audio_pkey PRIMARY KEY (id);


--
-- Name: registro_operacao_operador_historico registro_operacao_operador_historico_pkey; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador_historico
    ADD CONSTRAINT registro_operacao_operador_historico_pkey PRIMARY KEY (id);


--
-- Name: registro_operacao_operador registro_operacao_operador_pkey; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT registro_operacao_operador_pkey PRIMARY KEY (id);


--
-- Name: registro_operacao_operador uq_regopop_registro_operador_seq; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT uq_regopop_registro_operador_seq UNIQUE (registro_id, operador_id, seq);


--
-- Name: registro_operacao_operador uq_regopop_registro_ordem; Type: CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT uq_regopop_registro_ordem UNIQUE (registro_id, ordem);


--
-- Name: administrador administrador_pkey; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador
    ADD CONSTRAINT administrador_pkey PRIMARY KEY (id);


--
-- Name: administrador_s administrador_s_email_key; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador_s
    ADD CONSTRAINT administrador_s_email_key UNIQUE (email);


--
-- Name: administrador_s administrador_s_pkey; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador_s
    ADD CONSTRAINT administrador_s_pkey PRIMARY KEY (id);


--
-- Name: administrador_s administrador_s_username_key; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador_s
    ADD CONSTRAINT administrador_s_username_key UNIQUE (username);


--
-- Name: auth_sessions auth_sessions_pkey; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.auth_sessions
    ADD CONSTRAINT auth_sessions_pkey PRIMARY KEY (id);


--
-- Name: operador operador_pkey; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador
    ADD CONSTRAINT operador_pkey PRIMARY KEY (id);


--
-- Name: operador_s operador_s_email_key; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador_s
    ADD CONSTRAINT operador_s_email_key UNIQUE (email);


--
-- Name: operador_s operador_s_pkey; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador_s
    ADD CONSTRAINT operador_s_pkey PRIMARY KEY (id);


--
-- Name: operador_s operador_s_username_key; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador_s
    ADD CONSTRAINT operador_s_username_key UNIQUE (username);


--
-- Name: administrador uq_admin_email; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador
    ADD CONSTRAINT uq_admin_email UNIQUE (email);


--
-- Name: administrador uq_admin_username; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.administrador
    ADD CONSTRAINT uq_admin_username UNIQUE (username);


--
-- Name: operador uq_operador_email; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador
    ADD CONSTRAINT uq_operador_email UNIQUE (email);


--
-- Name: operador uq_operador_username; Type: CONSTRAINT; Schema: pessoa; Owner: -
--

ALTER TABLE ONLY pessoa.operador
    ADD CONSTRAINT uq_operador_username UNIQUE (username);


--
-- Name: test_run PK_011c050f566e9db509a0fadb9b9; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "PK_011c050f566e9db509a0fadb9b9" PRIMARY KEY (id);


--
-- Name: installed_packages PK_08cc9197c39b028c1e9beca225940576fd1a5804; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installed_packages
    ADD CONSTRAINT "PK_08cc9197c39b028c1e9beca225940576fd1a5804" PRIMARY KEY ("packageName");


--
-- Name: execution_metadata PK_17a0b6284f8d626aae88e1c16e4; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "PK_17a0b6284f8d626aae88e1c16e4" PRIMARY KEY (id);


--
-- Name: project_relation PK_1caaa312a5d7184a003be0f0cb6; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "PK_1caaa312a5d7184a003be0f0cb6" PRIMARY KEY ("projectId", "userId");


--
-- Name: chat_hub_sessions PK_1eafef1273c70e4464fec703412; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "PK_1eafef1273c70e4464fec703412" PRIMARY KEY (id);


--
-- Name: folder_tag PK_27e4e00852f6b06a925a4d83a3e; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "PK_27e4e00852f6b06a925a4d83a3e" PRIMARY KEY ("folderId", "tagId");


--
-- Name: role PK_35c9b140caaf6da09cfabb0d675; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT "PK_35c9b140caaf6da09cfabb0d675" PRIMARY KEY (slug);


--
-- Name: project PK_4d68b1358bb5b766d3e78f32f57; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "PK_4d68b1358bb5b766d3e78f32f57" PRIMARY KEY (id);


--
-- Name: workflow_dependency PK_52325e34cd7a2f0f67b0f3cad65; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "PK_52325e34cd7a2f0f67b0f3cad65" PRIMARY KEY (id);


--
-- Name: invalid_auth_token PK_5779069b7235b256d91f7af1a15; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invalid_auth_token
    ADD CONSTRAINT "PK_5779069b7235b256d91f7af1a15" PRIMARY KEY (token);


--
-- Name: shared_workflow PK_5ba87620386b847201c9531c58f; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "PK_5ba87620386b847201c9531c58f" PRIMARY KEY ("workflowId", "projectId");


--
-- Name: folder PK_6278a41a706740c94c02e288df8; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "PK_6278a41a706740c94c02e288df8" PRIMARY KEY (id);


--
-- Name: data_table_column PK_673cb121ee4a8a5e27850c72c51; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "PK_673cb121ee4a8a5e27850c72c51" PRIMARY KEY (id);


--
-- Name: annotation_tag_entity PK_69dfa041592c30bbc0d4b84aa00; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotation_tag_entity
    ADD CONSTRAINT "PK_69dfa041592c30bbc0d4b84aa00" PRIMARY KEY (id);


--
-- Name: chat_hub_messages PK_7704a5add6baed43eef835f0bfb; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "PK_7704a5add6baed43eef835f0bfb" PRIMARY KEY (id);


--
-- Name: execution_annotations PK_7afcf93ffa20c4252869a7c6a23; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "PK_7afcf93ffa20c4252869a7c6a23" PRIMARY KEY (id);


--
-- Name: migrations PK_8c82d7f526340ab734260ea46be; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id);


--
-- Name: installed_nodes PK_8ebd28194e4f792f96b5933423fc439df97d9689; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "PK_8ebd28194e4f792f96b5933423fc439df97d9689" PRIMARY KEY (name);


--
-- Name: shared_credentials PK_8ef3a59796a228913f251779cff; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "PK_8ef3a59796a228913f251779cff" PRIMARY KEY ("credentialsId", "projectId");


--
-- Name: test_case_execution PK_90c121f77a78a6580e94b794bce; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "PK_90c121f77a78a6580e94b794bce" PRIMARY KEY (id);


--
-- Name: user_api_keys PK_978fa5caa3468f463dac9d92e69; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "PK_978fa5caa3468f463dac9d92e69" PRIMARY KEY (id);


--
-- Name: execution_annotation_tags PK_979ec03d31294cca484be65d11f; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "PK_979ec03d31294cca484be65d11f" PRIMARY KEY ("annotationId", "tagId");


--
-- Name: webhook_entity PK_b21ace2e13596ccd87dc9bf4ea6; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT "PK_b21ace2e13596ccd87dc9bf4ea6" PRIMARY KEY ("webhookPath", method);


--
-- Name: insights_by_period PK_b606942249b90cc39b0265f0575; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "PK_b606942249b90cc39b0265f0575" PRIMARY KEY (id);


--
-- Name: workflow_history PK_b6572dd6173e4cd06fe79937b58; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "PK_b6572dd6173e4cd06fe79937b58" PRIMARY KEY ("versionId");


--
-- Name: scope PK_bfc45df0481abd7f355d6187da1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scope
    ADD CONSTRAINT "PK_bfc45df0481abd7f355d6187da1" PRIMARY KEY (slug);


--
-- Name: processed_data PK_ca04b9d8dc72de268fe07a65773; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "PK_ca04b9d8dc72de268fe07a65773" PRIMARY KEY ("workflowId", context);


--
-- Name: settings PK_dc0fe14e6d9943f268e7b119f69ab8bd; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT "PK_dc0fe14e6d9943f268e7b119f69ab8bd" PRIMARY KEY (key);


--
-- Name: data_table PK_e226d0001b9e6097cbfe70617cb; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "PK_e226d0001b9e6097cbfe70617cb" PRIMARY KEY (id);


--
-- Name: data_table_user_5EBBvwJHpAKSfA9V PK_e3f17108f246c82a2859894a7d8; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."data_table_user_5EBBvwJHpAKSfA9V"
    ADD CONSTRAINT "PK_e3f17108f246c82a2859894a7d8" PRIMARY KEY (id);


--
-- Name: user PK_ea8f538c94b6e352418254ed6474a81f; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "PK_ea8f538c94b6e352418254ed6474a81f" PRIMARY KEY (id);


--
-- Name: insights_raw PK_ec15125755151e3a7e00e00014f; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "PK_ec15125755151e3a7e00e00014f" PRIMARY KEY (id);


--
-- Name: insights_metadata PK_f448a94c35218b6208ce20cf5a1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "PK_f448a94c35218b6208ce20cf5a1" PRIMARY KEY ("metaId");


--
-- Name: role_scope PK_role_scope; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "PK_role_scope" PRIMARY KEY ("roleSlug", "scopeSlug");


--
-- Name: data_table_column UQ_8082ec4890f892f0bc77473a123; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "UQ_8082ec4890f892f0bc77473a123" UNIQUE ("dataTableId", name);


--
-- Name: data_table UQ_b23096ef747281ac944d28e8b0d; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "UQ_b23096ef747281ac944d28e8b0d" UNIQUE ("projectId", name);


--
-- Name: user UQ_e12875dfb3b1d92d7d7c5377e2; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "UQ_e12875dfb3b1d92d7d7c5377e2" UNIQUE (email);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY ("providerId", "providerType");


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_provider_sync_history auth_provider_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_provider_sync_history
    ADD CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: credentials_entity credentials_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT credentials_entity_pkey PRIMARY KEY (id);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: event_destinations event_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_destinations
    ADD CONSTRAINT event_destinations_pkey PRIMARY KEY (id);


--
-- Name: execution_data execution_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_pkey PRIMARY KEY ("executionId");


--
-- Name: execution_entity pk_e3e63bbf986767844bbe1166d4e; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT pk_e3e63bbf986767844bbe1166d4e PRIMARY KEY (id);


--
-- Name: workflow_statistics pk_workflow_statistics; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT pk_workflow_statistics PRIMARY KEY ("workflowId", name);


--
-- Name: workflows_tags pk_workflows_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT pk_workflows_tags PRIMARY KEY ("workflowId", "tagId");


--
-- Name: tag_entity tag_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_entity
    ADD CONSTRAINT tag_entity_pkey PRIMARY KEY (id);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: workflow_entity workflow_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT workflow_entity_pkey PRIMARY KEY (id);


--
-- Name: idx_checklist_historico_cid; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX idx_checklist_historico_cid ON forms.checklist_historico USING btree (checklist_id);


--
-- Name: ix_checklist_data; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_checklist_data ON forms.checklist USING btree (data_operacao);


--
-- Name: ix_checklist_data_sala; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_checklist_data_sala ON forms.checklist USING btree (data_operacao, sala_id);


--
-- Name: ix_checklist_sala; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_checklist_sala ON forms.checklist USING btree (sala_id);


--
-- Name: ix_cli_resp_checklist; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_cli_resp_checklist ON forms.checklist_resposta USING btree (checklist_id);


--
-- Name: ix_cli_resp_item; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_cli_resp_item ON forms.checklist_resposta USING btree (item_tipo_id);


--
-- Name: ix_cli_resp_status; Type: INDEX; Schema: forms; Owner: -
--

CREATE INDEX ix_cli_resp_status ON forms.checklist_resposta USING btree (status);


--
-- Name: idx_reg_op_op_historico_eid; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX idx_reg_op_op_historico_eid ON operacao.registro_operacao_operador_historico USING btree (entrada_id);


--
-- Name: idx_registro_operacao_operador_comissao; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX idx_registro_operacao_operador_comissao ON operacao.registro_operacao_operador USING btree (comissao_id);


--
-- Name: ix_reganom_data; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_reganom_data ON operacao.registro_anormalidade USING btree (data);


--
-- Name: ix_reganom_operador; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_reganom_operador ON operacao.registro_anormalidade USING btree (criado_por);


--
-- Name: ix_reganom_registro; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_reganom_registro ON operacao.registro_anormalidade USING btree (registro_id);


--
-- Name: ix_reganom_sala; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_reganom_sala ON operacao.registro_anormalidade USING btree (sala_id);


--
-- Name: ix_regop_data; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_regop_data ON operacao.registro_operacao_audio USING btree (data);


--
-- Name: ix_regop_data_sala; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_regop_data_sala ON operacao.registro_operacao_audio USING btree (data, sala_id);


--
-- Name: ix_regop_sala; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_regop_sala ON operacao.registro_operacao_audio USING btree (sala_id);


--
-- Name: ix_regopop_operador; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_regopop_operador ON operacao.registro_operacao_operador USING btree (operador_id);


--
-- Name: ix_regopop_registro; Type: INDEX; Schema: operacao; Owner: -
--

CREATE INDEX ix_regopop_registro ON operacao.registro_operacao_operador USING btree (registro_id);


--
-- Name: uq_reganom_entrada_unica; Type: INDEX; Schema: operacao; Owner: -
--

CREATE UNIQUE INDEX uq_reganom_entrada_unica ON operacao.registro_anormalidade USING btree (entrada_id) WHERE (entrada_id IS NOT NULL);


--
-- Name: uq_regop_sala_aberta; Type: INDEX; Schema: operacao; Owner: -
--

CREATE UNIQUE INDEX uq_regop_sala_aberta ON operacao.registro_operacao_audio USING btree (sala_id) WHERE em_aberto;


--
-- Name: idx_administrador_s_username; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE INDEX idx_administrador_s_username ON pessoa.administrador_s USING btree (username);


--
-- Name: idx_auth_sessions_user; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE INDEX idx_auth_sessions_user ON pessoa.auth_sessions USING btree (user_id);


--
-- Name: idx_operador_s_username; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE INDEX idx_operador_s_username ON pessoa.operador_s USING btree (username);


--
-- Name: ix_operador_email; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE INDEX ix_operador_email ON pessoa.operador USING btree (email);


--
-- Name: ix_operador_username; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE INDEX ix_operador_username ON pessoa.operador USING btree (username);


--
-- Name: uq_auth_sessions_rth; Type: INDEX; Schema: pessoa; Owner: -
--

CREATE UNIQUE INDEX uq_auth_sessions_rth ON pessoa.auth_sessions USING btree (refresh_token_hash);


--
-- Name: IDX_14f68deffaf858465715995508; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_14f68deffaf858465715995508" ON public.folder USING btree ("projectId", id);


--
-- Name: IDX_1d8ab99d5861c9388d2dc1cf73; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_1d8ab99d5861c9388d2dc1cf73" ON public.insights_metadata USING btree ("workflowId");


--
-- Name: IDX_1e31657f5fe46816c34be7c1b4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_1e31657f5fe46816c34be7c1b4" ON public.workflow_history USING btree ("workflowId");


--
-- Name: IDX_1ef35bac35d20bdae979d917a3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_1ef35bac35d20bdae979d917a3" ON public.user_api_keys USING btree ("apiKey");


--
-- Name: IDX_5f0643f6717905a05164090dde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_5f0643f6717905a05164090dde" ON public.project_relation USING btree ("userId");


--
-- Name: IDX_60b6a84299eeb3f671dfec7693; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_60b6a84299eeb3f671dfec7693" ON public.insights_by_period USING btree ("periodStart", type, "periodUnit", "metaId");


--
-- Name: IDX_61448d56d61802b5dfde5cdb00; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_61448d56d61802b5dfde5cdb00" ON public.project_relation USING btree ("projectId");


--
-- Name: IDX_63d7bbae72c767cf162d459fcc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_63d7bbae72c767cf162d459fcc" ON public.user_api_keys USING btree ("userId", label);


--
-- Name: IDX_8e4b4774db42f1e6dda3452b2a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_8e4b4774db42f1e6dda3452b2a" ON public.test_case_execution USING btree ("testRunId");


--
-- Name: IDX_97f863fa83c4786f1956508496; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_97f863fa83c4786f1956508496" ON public.execution_annotations USING btree ("executionId");


--
-- Name: IDX_UniqueRoleDisplayName; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_UniqueRoleDisplayName" ON public.role USING btree ("displayName");


--
-- Name: IDX_a3697779b366e131b2bbdae297; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_a3697779b366e131b2bbdae297" ON public.execution_annotation_tags USING btree ("tagId");


--
-- Name: IDX_a4ff2d9b9628ea988fa9e7d0bf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_a4ff2d9b9628ea988fa9e7d0bf" ON public.workflow_dependency USING btree ("workflowId");


--
-- Name: IDX_ae51b54c4bb430cf92f48b623f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_ae51b54c4bb430cf92f48b623f" ON public.annotation_tag_entity USING btree (name);


--
-- Name: IDX_c1519757391996eb06064f0e7c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_c1519757391996eb06064f0e7c" ON public.execution_annotation_tags USING btree ("annotationId");


--
-- Name: IDX_cec8eea3bf49551482ccb4933e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IDX_cec8eea3bf49551482ccb4933e" ON public.execution_metadata USING btree ("executionId", key);


--
-- Name: IDX_d6870d3b6e4c185d33926f423c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_d6870d3b6e4c185d33926f423c" ON public.test_run USING btree ("workflowId");


--
-- Name: IDX_e48a201071ab85d9d09119d640; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_e48a201071ab85d9d09119d640" ON public.workflow_dependency USING btree ("dependencyKey");


--
-- Name: IDX_e7fe1cfda990c14a445937d0b9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_e7fe1cfda990c14a445937d0b9" ON public.workflow_dependency USING btree ("dependencyType");


--
-- Name: IDX_execution_entity_deletedAt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_execution_entity_deletedAt" ON public.execution_entity USING btree ("deletedAt");


--
-- Name: IDX_role_scope_scopeSlug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_role_scope_scopeSlug" ON public.role_scope USING btree ("scopeSlug");


--
-- Name: IDX_workflow_entity_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_workflow_entity_name" ON public.workflow_entity USING btree (name);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_groups_group_id_97559544 ON public.auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON public.auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON public.auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON public.auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_username_6821ab7c_like ON public.auth_user USING btree (username varchar_pattern_ops);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: idx_07fde106c0b471d8cc80a64fc8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_07fde106c0b471d8cc80a64fc8 ON public.credentials_entity USING btree (type);


--
-- Name: idx_16f4436789e804e3e1c9eeb240; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_16f4436789e804e3e1c9eeb240 ON public.webhook_entity USING btree ("webhookId", method, "pathLength");


--
-- Name: idx_812eb05f7451ca757fb98444ce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_812eb05f7451ca757fb98444ce ON public.tag_entity USING btree (name);


--
-- Name: idx_execution_entity_stopped_at_status_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_execution_entity_stopped_at_status_deleted_at ON public.execution_entity USING btree ("stoppedAt", status, "deletedAt") WHERE (("stoppedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_wait_till_status_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_execution_entity_wait_till_status_deleted_at ON public.execution_entity USING btree ("waitTill", status, "deletedAt") WHERE (("waitTill" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_workflow_id_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_execution_entity_workflow_id_started_at ON public.execution_entity USING btree ("workflowId", "startedAt") WHERE (("startedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_workflows_tags_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workflows_tags_workflow_id ON public.workflows_tags USING btree ("workflowId");


--
-- Name: pk_credentials_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pk_credentials_entity_id ON public.credentials_entity USING btree (id);


--
-- Name: pk_tag_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pk_tag_entity_id ON public.tag_entity USING btree (id);


--
-- Name: pk_workflow_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pk_workflow_entity_id ON public.workflow_entity USING btree (id);


--
-- Name: project_relation_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_relation_role_idx ON public.project_relation USING btree (role);


--
-- Name: project_relation_role_project_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_relation_role_project_idx ON public.project_relation USING btree ("projectId", role);


--
-- Name: user_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_role_idx ON public."user" USING btree ("roleSlug");


--
-- Name: variables_global_key_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX variables_global_key_unique ON public.variables USING btree (key) WHERE ("projectId" IS NULL);


--
-- Name: variables_project_key_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX variables_project_key_unique ON public.variables USING btree ("projectId", key) WHERE ("projectId" IS NOT NULL);


--
-- Name: sala trg_sala_set_updated_at; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER trg_sala_set_updated_at BEFORE UPDATE ON cadastro.sala FOR EACH ROW EXECUTE FUNCTION cadastro.set_updated_at();


--
-- Name: checklist_item_tipo tr_item_tipo_updated; Type: TRIGGER; Schema: forms; Owner: -
--

CREATE TRIGGER tr_item_tipo_updated BEFORE UPDATE ON forms.checklist_item_tipo FOR EACH ROW EXECUTE FUNCTION forms.update_item_tipo_timestamp();


--
-- Name: checklist_sala_config tr_sala_config_updated; Type: TRIGGER; Schema: forms; Owner: -
--

CREATE TRIGGER tr_sala_config_updated BEFORE UPDATE ON forms.checklist_sala_config FOR EACH ROW EXECUTE FUNCTION forms.update_sala_config_timestamp();


--
-- Name: checklist trg_checklist_set_updated_at; Type: TRIGGER; Schema: forms; Owner: -
--

CREATE TRIGGER trg_checklist_set_updated_at BEFORE UPDATE ON forms.checklist FOR EACH ROW EXECUTE FUNCTION forms.set_updated_at();


--
-- Name: checklist_resposta trg_cli_resp_set_updated_at; Type: TRIGGER; Schema: forms; Owner: -
--

CREATE TRIGGER trg_cli_resp_set_updated_at BEFORE UPDATE ON forms.checklist_resposta FOR EACH ROW EXECUTE FUNCTION forms.set_updated_at();


--
-- Name: registro_anormalidade trg_reganom_set_updated_at; Type: TRIGGER; Schema: operacao; Owner: -
--

CREATE TRIGGER trg_reganom_set_updated_at BEFORE UPDATE ON operacao.registro_anormalidade FOR EACH ROW EXECUTE FUNCTION operacao.set_updated_at();


--
-- Name: registro_operacao_operador trg_regopop_set_updated_at; Type: TRIGGER; Schema: operacao; Owner: -
--

CREATE TRIGGER trg_regopop_set_updated_at BEFORE UPDATE ON operacao.registro_operacao_operador FOR EACH ROW EXECUTE FUNCTION operacao.set_updated_at();


--
-- Name: registro_anormalidade trg_sync_houve_anormalidade; Type: TRIGGER; Schema: operacao; Owner: -
--

CREATE TRIGGER trg_sync_houve_anormalidade AFTER INSERT OR DELETE OR UPDATE ON operacao.registro_anormalidade FOR EACH ROW EXECUTE FUNCTION operacao.sync_houve_anormalidade();


--
-- Name: administrador trg_admin_set_updated_at; Type: TRIGGER; Schema: pessoa; Owner: -
--

CREATE TRIGGER trg_admin_set_updated_at BEFORE UPDATE ON pessoa.administrador FOR EACH ROW EXECUTE FUNCTION pessoa.set_updated_at();


--
-- Name: operador trg_operador_set_updated_at; Type: TRIGGER; Schema: pessoa; Owner: -
--

CREATE TRIGGER trg_operador_set_updated_at BEFORE UPDATE ON pessoa.operador FOR EACH ROW EXECUTE FUNCTION pessoa.set_updated_at();


--
-- Name: checklist_historico checklist_historico_checklist_id_fkey; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_historico
    ADD CONSTRAINT checklist_historico_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES forms.checklist(id);


--
-- Name: checklist_resposta checklist_resposta_checklist_id_fkey; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_resposta
    ADD CONSTRAINT checklist_resposta_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES forms.checklist(id) ON DELETE CASCADE;


--
-- Name: checklist_resposta checklist_resposta_item_tipo_id_fkey; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_resposta
    ADD CONSTRAINT checklist_resposta_item_tipo_id_fkey FOREIGN KEY (item_tipo_id) REFERENCES forms.checklist_item_tipo(id);


--
-- Name: checklist checklist_sala_id_fkey; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist
    ADD CONSTRAINT checklist_sala_id_fkey FOREIGN KEY (sala_id) REFERENCES cadastro.sala(id);


--
-- Name: checklist_sala_config fk_sala_config_item_tipo; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_sala_config
    ADD CONSTRAINT fk_sala_config_item_tipo FOREIGN KEY (item_tipo_id) REFERENCES forms.checklist_item_tipo(id);


--
-- Name: checklist_sala_config fk_sala_config_sala; Type: FK CONSTRAINT; Schema: forms; Owner: -
--

ALTER TABLE ONLY forms.checklist_sala_config
    ADD CONSTRAINT fk_sala_config_sala FOREIGN KEY (sala_id) REFERENCES cadastro.sala(id);


--
-- Name: registro_anormalidade fk_reganom_entrada_operador; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade
    ADD CONSTRAINT fk_reganom_entrada_operador FOREIGN KEY (entrada_id) REFERENCES operacao.registro_operacao_operador(id) ON DELETE SET NULL;


--
-- Name: registro_operacao_operador fk_registro_operacao_operador_comissao; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT fk_registro_operacao_operador_comissao FOREIGN KEY (comissao_id) REFERENCES cadastro.comissao(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: registro_operacao_audio fk_regop_checklist_do_dia; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_audio
    ADD CONSTRAINT fk_regop_checklist_do_dia FOREIGN KEY (checklist_do_dia_id) REFERENCES forms.checklist(id) ON DELETE SET NULL;


--
-- Name: registro_anormalidade_admin registro_anormalidade_admin_atualizado_por_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade_admin
    ADD CONSTRAINT registro_anormalidade_admin_atualizado_por_fkey FOREIGN KEY (atualizado_por) REFERENCES pessoa.administrador(id);


--
-- Name: registro_anormalidade_admin registro_anormalidade_admin_criado_por_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade_admin
    ADD CONSTRAINT registro_anormalidade_admin_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES pessoa.administrador(id);


--
-- Name: registro_anormalidade_admin registro_anormalidade_admin_registro_anormalidade_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade_admin
    ADD CONSTRAINT registro_anormalidade_admin_registro_anormalidade_id_fkey FOREIGN KEY (registro_anormalidade_id) REFERENCES operacao.registro_anormalidade(id) ON DELETE CASCADE;


--
-- Name: registro_anormalidade registro_anormalidade_registro_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade
    ADD CONSTRAINT registro_anormalidade_registro_id_fkey FOREIGN KEY (registro_id) REFERENCES operacao.registro_operacao_audio(id) ON DELETE CASCADE;


--
-- Name: registro_anormalidade registro_anormalidade_sala_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_anormalidade
    ADD CONSTRAINT registro_anormalidade_sala_id_fkey FOREIGN KEY (sala_id) REFERENCES cadastro.sala(id);


--
-- Name: registro_operacao_audio registro_operacao_audio_sala_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_audio
    ADD CONSTRAINT registro_operacao_audio_sala_id_fkey FOREIGN KEY (sala_id) REFERENCES cadastro.sala(id);


--
-- Name: registro_operacao_operador registro_operacao_operador_comissao_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT registro_operacao_operador_comissao_id_fkey FOREIGN KEY (comissao_id) REFERENCES cadastro.comissao(id);


--
-- Name: registro_operacao_operador_historico registro_operacao_operador_historico_entrada_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador_historico
    ADD CONSTRAINT registro_operacao_operador_historico_entrada_id_fkey FOREIGN KEY (entrada_id) REFERENCES operacao.registro_operacao_operador(id);


--
-- Name: registro_operacao_operador registro_operacao_operador_operador_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT registro_operacao_operador_operador_id_fkey FOREIGN KEY (operador_id) REFERENCES pessoa.operador(id) ON DELETE RESTRICT;


--
-- Name: registro_operacao_operador registro_operacao_operador_registro_id_fkey; Type: FK CONSTRAINT; Schema: operacao; Owner: -
--

ALTER TABLE ONLY operacao.registro_operacao_operador
    ADD CONSTRAINT registro_operacao_operador_registro_id_fkey FOREIGN KEY (registro_id) REFERENCES operacao.registro_operacao_audio(id) ON DELETE CASCADE;


--
-- Name: processed_data FK_06a69a7032c97a763c2c7599464; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "FK_06a69a7032c97a763c2c7599464" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_1d8ab99d5861c9388d2dc1cf733; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_1d8ab99d5861c9388d2dc1cf733" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: workflow_history FK_1e31657f5fe46816c34be7c1b4b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "FK_1e31657f5fe46816c34be7c1b4b" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_1f4998c8a7dec9e00a9ab15550e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_1f4998c8a7dec9e00a9ab15550e" FOREIGN KEY ("revisionOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_2375a1eda085adb16b24615b69c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_2375a1eda085adb16b24615b69c" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_25c9736e7f769f3a005eef4b372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_25c9736e7f769f3a005eef4b372" FOREIGN KEY ("retryOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: execution_metadata FK_31d0b4c93fb85ced26f6005cda3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "FK_31d0b4c93fb85ced26f6005cda3" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_416f66fc846c7c442970c094ccf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_416f66fc846c7c442970c094ccf" FOREIGN KEY ("credentialsId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: variables FK_42f6c766f9f9d2edcc15bdd6e9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT "FK_42f6c766f9f9d2edcc15bdd6e9b" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_5f0643f6717905a05164090dde7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_5f0643f6717905a05164090dde7" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_61448d56d61802b5dfde5cdb002; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_61448d56d61802b5dfde5cdb002" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: insights_by_period FK_6414cfed98daabbfdd61a1cfbc0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "FK_6414cfed98daabbfdd61a1cfbc0" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_6afb260449dd7a9b85355d4e0c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_6afb260449dd7a9b85355d4e0c9" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: insights_raw FK_6e2e33741adef2a7c5d66befa4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "FK_6e2e33741adef2a7c5d66befa4e" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: installed_nodes FK_73f857fc5dce682cef8a99c11dbddbc969618951; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "FK_73f857fc5dce682cef8a99c11dbddbc969618951" FOREIGN KEY (package) REFERENCES public.installed_packages("packageName") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_7bc13b4c7e6afbfaf9be326c189; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_7bc13b4c7e6afbfaf9be326c189" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: folder FK_804ea52f6729e3940498bd54d78; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_804ea52f6729e3940498bd54d78" FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_812c2852270da1247756e77f5a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_812c2852270da1247756e77f5a4" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_8e4b4774db42f1e6dda3452b2af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_8e4b4774db42f1e6dda3452b2af" FOREIGN KEY ("testRunId") REFERENCES public.test_run(id) ON DELETE CASCADE;


--
-- Name: data_table_column FK_930b6e8faaf88294cef23484160; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "FK_930b6e8faaf88294cef23484160" FOREIGN KEY ("dataTableId") REFERENCES public.data_table(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_94a60854e06f2897b2e0d39edba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_94a60854e06f2897b2e0d39edba" FOREIGN KEY ("folderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: execution_annotations FK_97f863fa83c4786f19565084960; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "FK_97f863fa83c4786f19565084960" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_9f9293d9f552496c40e0d1a8f80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_9f9293d9f552496c40e0d1a8f80" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: execution_annotation_tags FK_a3697779b366e131b2bbdae2976; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_a3697779b366e131b2bbdae2976" FOREIGN KEY ("tagId") REFERENCES public.annotation_tag_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_a45ea5f27bcfdc21af9b4188560; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_a45ea5f27bcfdc21af9b4188560" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_dependency FK_a4ff2d9b9628ea988fa9e7d0bf8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "FK_a4ff2d9b9628ea988fa9e7d0bf8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: folder FK_a8260b0b36939c6247f385b8221; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_a8260b0b36939c6247f385b8221" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_acf8926098f063cdbbad8497fd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_acf8926098f063cdbbad8497fd1" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: execution_annotation_tags FK_c1519757391996eb06064f0e7c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_c1519757391996eb06064f0e7c8" FOREIGN KEY ("annotationId") REFERENCES public.execution_annotations(id) ON DELETE CASCADE;


--
-- Name: data_table FK_c2a794257dee48af7c9abf681de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "FK_c2a794257dee48af7c9abf681de" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_c6b99592dc96b0d836d7a21db91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_c6b99592dc96b0d836d7a21db91" FOREIGN KEY (role) REFERENCES public.role(slug);


--
-- Name: test_run FK_d6870d3b6e4c185d33926f423c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "FK_d6870d3b6e4c185d33926f423c8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_daa206a04983d47d0a9c34649ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_daa206a04983d47d0a9c34649ce" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_dc88164176283de80af47621746; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_dc88164176283de80af47621746" FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: user_api_keys FK_e131705cbbc8fb589889b02d457; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "FK_e131705cbbc8fb589889b02d457" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_e22538eb50a71a17954cd7e076c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e22538eb50a71a17954cd7e076c" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_e48965fac35d0f5b9e7f51d8c44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_e48965fac35d0f5b9e7f51d8c44" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_e5d1fa722c5a8d38ac204746662; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e5d1fa722c5a8d38ac204746662" FOREIGN KEY ("previousMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_e9ecf8ede7d989fcd18790fe36a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_e9ecf8ede7d989fcd18790fe36a" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: user FK_eaea92ee7bfb9c1b6cd01505d56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "FK_eaea92ee7bfb9c1b6cd01505d56" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug);


--
-- Name: role_scope FK_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_role" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: role_scope FK_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_scope" FOREIGN KEY ("scopeSlug") REFERENCES public.scope(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_identity auth_identity_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT "auth_identity_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."user"(id);


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: execution_data execution_data_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_fk FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: execution_entity fk_execution_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: webhook_entity fk_webhook_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity fk_workflow_parent_folder; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT fk_workflow_parent_folder FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: workflow_statistics fk_workflow_statistics_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT fk_workflow_statistics_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict hZVCfJrbRtudf0DaW4cbk1e0XF7nowlr7Os6D7PyyFOZwgUmfumJTcmc2kxMCYS

