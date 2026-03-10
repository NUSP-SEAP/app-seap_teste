// Carrega fragmentos HTML (header/footer)
async function loadComponent(id, file) {
    try {
        const response = await fetch(file);
        const html = await response.text();
        const host = document.getElementById(id);
        if (host) host.innerHTML = html;
    } catch (e) {
        console.error(`Erro ao carregar ${file}:`, e);
    }
}

// Utilitário opcional (mantido caso você precise carregar JS após os componentes)
function loadScript(src) {
    const script = document.createElement('script');
    script.src = src;
    script.defer = true;
    document.body.appendChild(script);
}

// Inicialização: injeta header/footer
async function initializePage() {
    await Promise.all([
        loadComponent("header", "/components/header.html"),
        loadComponent("footer", "/components/footer.html"),
    ]);
    // Intencionalmente NÃO carregamos initHeader.js no login
    // para não “pintar” saudação/logout nesta tela.
}

initializePage();

// Tudo após o DOM estar pronto
document.addEventListener('DOMContentLoaded', () => {
    // 1) Pular login se já estiver logado (whoAmI)
    (async () => {
        if (!window.Auth) return;
        try {
            const me = await Auth.whoAmI(); // mantém sua verificação
            if (me.ok && me.user) {
                const roleRaw = (me.user.role || '').toString().toLowerCase();
                const isAdmin = roleRaw === 'administrador';
                window.location.replace(isAdmin ? '/admin/index.html' : '/home.html');
            }
        } catch (e) {
            console.warn('whoAmI check failed, showing login page.', e);
        }
    })();

    // 2) Lógica do formulário de login (preservada)
    const form = document.getElementById('login-form');
    const inputUser = document.getElementById('username');
    const inputPass = document.getElementById('password');
    const errorBox = document.getElementById('error-box');
    const btn = document.getElementById('submit-btn');

    if (!form || form.dataset.bound === '1') return;
    form.dataset.bound = '1';

    let loggingIn = false;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (loggingIn) return;
        loggingIn = true;

        if (errorBox) errorBox.style.display = 'none';
        if (btn) btn.disabled = true;

        const usuario = (inputUser?.value || '').trim();
        const senha = inputPass?.value || '';

        try {
            // POST /webhook/login → salva token → redireciona por role
            await Auth.doLogin(usuario, senha);
            return; // o próprio doLogin redireciona
        } catch (err) {
            if (errorBox) {
                errorBox.textContent =
                    (err && err.message) ? err.message : 'Usuário ou senha inválidos';
                errorBox.style.display = 'block';
            } else {
                alert(err?.message || 'Usuário ou senha inválidos');
            }
            if (btn) btn.disabled = false;
            loggingIn = false;
        }
    });
});
