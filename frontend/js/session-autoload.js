
/*! session-autoload.js — drop‑in de sessão para o seu site
 *  Objetivo: basta importar este arquivo em QUALQUER página para ter:
 *   - Proteção automática (login obrigatório) — inclusive detecção de página de admin
 *   - Redirecionamento automático do login quando o usuário já estiver autenticado
 *   - Auto-bind do formulário de login (#login-form) sem precisar de JS inline
 *   - Carregamento de header/footer (se ausentes, o script insere <div id="header/footer">)
 *   - Botão “Sair” funcionando (ids suportados: #btn-logout ou #btnLogout)
 *
 *  Compatível com o seu auth_jwt.js atual (window.Auth.*). Se ele não estiver carregado,
 *  este arquivo carrega automaticamente /js/auth_jwt.js e só então executa.
 *
 *  Coloque este arquivo em: /var/www/app/js/session-autoload.js
 *  Em cada página, adicione APENAS:
 *      <script src="/js/session-autoload.js"></script>
 */
(function () {
  // =======================
  // Configurações padrão
  // =======================
  var CFG = {
    authScript: "/js/auth_jwt.js",                     // caminho do seu auth (já existe no /app/js/)
    headerPaths: ["/components/header.html", "/app/components/header.html"],
    footerPaths: ["/components/footer.html", "/app/components/footer.html"],
    loginPath: "/index.html",
    homePath: "/home.html",
    adminHomePath: "/admin/",                          // redireciona para a pasta do admin
    autoInsertHeaderFooter: true,                      // cria #header/#footer se não existirem
    debug: false                                       // mude para true se quiser logs no console
  };

  // =======================
  // Utilidades
  // =======================
  function log() {
    try {
      if (CFG.debug) console.debug("[session-autoload]", ...arguments);
    } catch (_) { }
  }
  function ready(fn) { if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn); else fn(); }
  function path() { return location.pathname.replace(/\/+$/, "").toLowerCase(); }
  function isLoginPage() {
    var p = path();
    // Considera raiz ou /index.html como tela de login; também detecta pelo form
    if (p === "" || p === "/" || p.endsWith("/index.html")) return !!document.getElementById("login-form") || true;
    return !!document.getElementById("login-form");
  }
  function isAdminPage() { return /\/admin(\/|$)/.test(path()); }

  function ensureContainer(id, where) {
    var el = document.getElementById(id);
    if (!el) {
      el = document.createElement("div");
      el.id = id;
      if (where === "bottom") document.body.appendChild(el);
      else document.body.prepend(el);
    }
    return el;
  }

  async function fetchText(url) {
    try {
      var r = await fetch(url, { cache: "reload" });
      if (!r.ok) return null;
      return await r.text();
    } catch (_) { return null; }
  }

  async function loadOneOf(intoId, paths) {
    if (!document.getElementById(intoId)) return false;
    for (var i = 0; i < paths.length; i++) {
      var html = await fetchText(paths[i]);
      if (html) { document.getElementById(intoId).innerHTML = html; return true; }
    }
    return false;
  }

  function bindLogoutOnce() {
    var b = document.querySelector('#btn-logout, #btnLogout');
    if (!b || b.dataset.bound === '1') return;
    b.addEventListener('click', function (ev) {
      ev.preventDefault();
      if (window.doServerLogout) return doServerLogout();        // 1º: legado compatível
      if (window.Auth && Auth.doLogout) return Auth.doLogout();  // 2º: server-first unificado
      location.href = '/index.html';                             // fallback
    });
    b.dataset.bound = '1';
  }

  // =======================
  // Bootstrap da sessão
  // =======================
  function waitForAuth() {
    return new Promise(function (resolve) {
      if (window.Auth) return resolve();
      // injeta o auth_jwt.js se ainda não estiver presente
      var s = document.createElement("script");
      s.src = CFG.authScript;
      s.async = true;
      s.defer = true;
      s.onload = function () { resolve(); };
      s.onerror = function () { resolve(); }; // segue mesmo sem o Auth (evita travar a página)
      document.head.appendChild(s);
    });
  }

  async function redirectIfAlreadyLogged() {
    try {
      if (!window.Auth || !Auth.loadToken) return;
      var tok = (Auth.loadToken() || "").trim();
      if (!tok) return;
      // usa cache (Auth.whoAmI já usa) para decidir rota
      var me = await (Auth.whoAmI ? Auth.whoAmI({ allowCached: false }) : Promise.resolve(null));
      if (me && me.ok) {
        var role = String(me.role || (me.user && me.user.role) || "").toLowerCase();
        location.replace(role.startsWith("admin") ? CFG.adminHomePath : CFG.homePath);
      }
    } catch (e) { log("redirectIfAlreadyLogged err:", e && e.message); }
  }

  async function bindLoginForm() {
    var form = document.getElementById("login-form");
    if (!form || form.dataset.bound === "1") return;

    var userEl = document.getElementById("username") || form.querySelector("[name=usuario]");
    var passEl = document.getElementById("password") || form.querySelector("[name=senha]");
    var errorBox = document.getElementById("error-box");
    var btn = document.getElementById("submit-btn") || form.querySelector("button[type=submit]");

    var submitting = false;
    form.addEventListener("submit", async function (ev) {
      ev.preventDefault();
      if (submitting) return;
      submitting = true;
      if (errorBox) errorBox.style.display = "none";
      if (btn) btn.disabled = true;

      var usuario = (userEl && userEl.value || "").trim();
      var senha = (passEl && passEl.value || "");

      try {
        if (!window.Auth || !Auth.doLogin) throw new Error("Módulo de autenticação indisponível.");
        var res = await Auth.doLogin(usuario, senha);
        if (!res || !res.ok) throw new Error("Usuário ou senha inválidos");
        location.href = (res.isAdmin ? CFG.adminHomePath : CFG.homePath);
      } catch (e) {
        if (errorBox) { errorBox.textContent = (e && e.message) || "Usuário ou senha inválidos"; errorBox.style.display = "block"; }
        else alert((e && e.message) || "Usuário ou senha inválidos");
      } finally {
        if (btn) btn.disabled = false;
        submitting = false;
      }
    });

    form.dataset.bound = "1";
  }

  async function autoloadHeaderFooter() {
    if (!CFG.autoInsertHeaderFooter) return;
    ensureContainer("header", "top");
    var loadedHeader = await loadOneOf("header", CFG.headerPaths);
    if (loadedHeader && window.Auth && Auth.renderUserHeader) {
      try { await Auth.renderUserHeader(); } catch (_) { }
      bindLogoutOnce();
    }
    ensureContainer("footer", "bottom");
    await loadOneOf("footer", CFG.footerPaths);
  }

  async function protectPage() {
    if (!window.Auth || !Auth.protectPage) return;
    var adminOnly = isAdminPage();
    await Auth.protectPage({ adminOnly: adminOnly });
  }

  // =======================
  // Execução
  // =======================
  ready(async function () {
    await waitForAuth();

    // Se não carregou o Auth por algum motivo, não quebra a página
    if (!window.Auth) { log("Auth indisponível — pulando proteção"); return; }

    if (isLoginPage()) {
      await redirectIfAlreadyLogged();
      await bindLoginForm();
      // Em páginas públicas (login), não exigimos proteção
    } else {
      // Páginas internas
      var adminOnly = isAdminPage();
      // Pré-oculta APENAS páginas /admin — o CSS do <head> só age quando este atributo existe
      if (adminOnly) document.documentElement.setAttribute('data-auth', 'pending');

      await protectPage();            // redireciona se não autorizado
      await autoloadHeaderFooter();   // injeta header/footer e liga o Sair

      if (adminOnly) document.documentElement.removeAttribute('data-auth');
    }
  });
})();

// Garante favicon padrão em todas as páginas
(function ensureFavicon() {
  try {
    var head = document.head || document.getElementsByTagName('head')[0];
    var link = document.querySelector('link[rel="icon"]');
    if (!link) {
      link = document.createElement('link');
      link.rel = 'icon';
      head.appendChild(link);
    }
    var href = '/imgs/header-senado.png'; // ajuste se você tiver um favicon dedicado
    if (!link.href || !link.href.endsWith(href)) {
      link.href = href;
    }
  } catch (_) { }
})();
