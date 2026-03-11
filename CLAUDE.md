# Projeto

## Ambiente

Este é o ambiente local de desenvolvimento (macbook). Não há separação homolog/produção aqui.

## Estrutura de diretórios

- **Frontend:** `/Users/douglasantunes/senado-nusp/frontend/`
- **Backend:** `/Users/douglasantunes/senado-nusp/backend/`
- **Arquivos de mídia:** `/Users/douglasantunes/senado-nusp/files/`

## Banco de dados

- PostgreSQL local em `127.0.0.1:5432`
- Database: `n8n_data`
- Usuário: `n8n_user`
- Conexão definida no `backend/.env`

**Permissões ao criar tabelas no banco.** Ao criar tabelas usando `sudo -u postgres psql`, o owner fica como `postgres` e a aplicação (que conecta como `n8n_user`) não terá permissão. Sempre executar após o CREATE TABLE: `ALTER TABLE schema.tabela OWNER TO n8n_user;` — ou conceder permissões com `GRANT SELECT, INSERT, UPDATE ON schema.tabela TO n8n_user;` e `GRANT USAGE, SELECT ON SEQUENCE schema.tabela_id_seq TO n8n_user;`.

## Regras de trabalho

- **Trabalhar em etapas para preservar a janela de contexto.** Ao implementar funcionalidades grandes, dividir o trabalho em etapas (ex: backend primeiro, frontend depois, etc.). Ao terminar cada etapa, parar, avisar o usuário e aguardar confirmação antes de prosseguir para a próxima.
- **Cache busting obrigatório.** Sempre que alterar um arquivo JS ou CSS, atualizar o parâmetro `?v=YYYYMMDD` (data da alteração) em **todos os HTMLs que referenciam esse arquivo**. Sem isso, os navegadores continuarão servindo a versão antiga do cache.
- **Commit e push ao concluir.** Sempre fazer commit e push para o GitHub após concluir um trabalho no ambiente local, descrevendo o que foi alterado.
- **SQL para a VPS.** Se houver alterações no banco de dados (criação de tabelas, ALTER TABLE, etc.), passar ao usuário o SQL necessário ao final do trabalho, pois o banco não está no git. Lembrar de incluir ajuste de permissões para `n8n_user`.

# currentDate
Today's date is 2026-03-05.
