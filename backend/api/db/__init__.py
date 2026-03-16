from .utils import get_owner_id
from .auth import (
    get_user_for_login,
    create_session,
    revoke_session,
    session_touch_ok,
)
from .lookup import lookup_operadores, lookup_salas, lookup_comissoes
from .anormalidade import (
    insert_registro_anormalidade,
    get_registro_operacao_audio_for_anormalidade,
    update_registro_anormalidade,
    get_registro_anormalidade_por_entrada,
)
from .checklist import (
    insert_checklist, insert_checklist_respostas,
    get_checklist_snapshot, insert_checklist_historico,
    update_checklist, update_checklist_respostas,
    list_checklist_itens_por_sala,
)
from .pessoa import (
    exists_user,
    insert_operador,
    get_foto_url_by_id,
    insert_administrador,
)
from .operacao import (
    insert_registro_operacao_audio,
    insert_registro_operacao_operador,
    update_registro_operacao_operador,
    get_sessao_aberta_por_sala,
    listar_entradas_da_sessao,
    finalizar_sessao_operacao_audio,
    get_entrada_operacao_snapshot,
    insert_entrada_operacao_historico,
    update_entrada_operacao_detalhe,
    update_sala_registro_operacao_audio,
    count_entradas_por_sessao,
    get_registro_id_by_entrada,
    get_operador_id_by_entrada,
)
