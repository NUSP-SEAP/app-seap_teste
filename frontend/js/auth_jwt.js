// ==== Helpers ====
const clean = v => (typeof v === 'string' && v.startsWith('=')) ? v.slice(1) : v;
function deepClean(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  const out = Array.isArray(obj) ? [] : {};
  for (const k of Object.keys(obj)) {
    const val = obj[k];
    out[k] = (val && typeof val === 'object') ? deepClean(val) : clean(val);
  }
  return out;
}
function parseJwt(token) {
  try {
    const parts = token.split('.');
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = '='.repeat((4 - (b64.length % 4)) % 4);
    const json = decodeURIComponent(atob(b64 + pad).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join(''));
    return JSON.parse(json);
  } catch { return null; }
}

// ==== Storage ====
function saveToken(t) { try { localStorage.setItem('auth_token', t); } catch (_) { } }
function loadToken() { try { return localStorage.getItem('auth_token'); } catch (_) { return null; } }
function clearToken() { try { localStorage.removeItem('auth_token'); localStorage.removeItem('auth_user'); } catch (_) { } }
function saveUser(me) { try { localStorage.setItem('auth_user', JSON.stringify(me || {})); } catch (_) { } }
function loadUser() { try { return JSON.parse(localStorage.getItem('auth_user') || 'null'); } catch (_) { return null; } }

// ==== Anti-cache headers ====
function buildNoCacheHeaders(h = new Headers()) {
  h.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  h.set('Pragma', 'no-cache');
  h.set('Expires', '0');
  h.set('If-None-Match', '"0"');
  h.set('If-Modified-Since', '0');
  return h;
}

// ==== Fetch autenticado ====
async function authFetch(url, options = {}) {
  const token = loadToken();
  const headers = buildNoCacheHeaders(new Headers(options.headers || {}));
  if (token) headers.set('Authorization', `Bearer ${token}`);
  return fetch(url, { cache: 'reload', ...options, headers, credentials: 'omit' });
}

// ==== WhoAmI (single-flight) ====
let __whoamiPromise = null;
async function whoAmI({ refresh = false, allowCached = true } = {}) {
  const token = loadToken();
  if (!token) return { ok: false, status: 401 };

  if (!refresh && __whoamiPromise) return __whoamiPromise;

  if (allowCached) {
    const cached = loadUser();
    if (cached && cached.ok) return cached;
  }

  __whoamiPromise = (async () => {
    const url = AppConfig.apiUrl(AppConfig.endpoints.auth.whoami);
    const resp = await authFetch(url + `?ts=${Date.now()}`, { method: 'GET' });
    if (resp.status === 401) {
      clearToken();                 // ← limpa auth_token
      saveUser(null);               // ← limpa auth_user
      __whoamiPromise = null;       // ← evita reuso de uma promessa “negativa”
      return { ok: false, status: 401 };
    }
    if (!resp.ok) return { ok: false, status: resp.status, error: await resp.text() };
    const data = deepClean(await resp.json());
    const me = { ok: true, ...data };
    saveUser(me);
    return me;
  })();

  return __whoamiPromise;
}

// ==== Proteger página ====
async function protectPage({ adminOnly = false } = {}) {
  try {
    const me = await whoAmI({ allowCached: false });
    if (!me.ok) {
      clearToken(); saveUser(null);
      window.location.replace('/index.html');  // 1 só volta, sem empilhar histórico
      return;
    }
    const roleRaw = clean((me.role ?? me.user?.role ?? '') + '').trim().toLowerCase();
    const isAdmin = roleRaw === 'administrador' || roleRaw.startsWith('admin');
    if (adminOnly && !isAdmin) { window.location.replace('/home.html'); return; }
    window.__currentUser = me;
  } catch {
    clearToken(); saveUser(null);
    window.location.replace('/index.html');
  }
}

// ==== Login ====
async function doLogin(usuario, senha) {
  const url = AppConfig.apiUrl(AppConfig.endpoints.auth.login);
  const resp = await fetch(url, {
    method: 'POST',
    headers: buildNoCacheHeaders(new Headers({ 'Content-Type': 'application/json' })),
    body: JSON.stringify({ usuario, senha })
  });
  const text = await resp.text();
  if (!resp.ok) throw new Error(`Falha no login (${resp.status}) ${text || ''}`);
  let data; try { data = JSON.parse(text || '{}'); } catch { throw new Error(`Resposta do login não é JSON: ${text?.slice(0, 200) || '(vazio)'}`); }
  if (!data.token) throw new Error('Token não recebido');

  // Guarda token e inicia refresh automático
  saveToken(data.token);
  startRefreshTimer();

  // Deriva usuário e role direto do JWT (sem chamar whoami para decidir rota)
  const claims = deepClean(parseJwt(data.token) || {});
  const roleRaw = clean((claims.perfil || claims.role || '') + '').trim().toLowerCase();
  const isAdmin = roleRaw === 'administrador' || roleRaw.startsWith('admin');

  const cachedMe = {
    ok: true,
    user: {
      id: claims.sub || '',
      username: claims.username || '',
      name: claims.nome || claims.name || '',
      email: claims.email || ''
    },
    role: roleRaw || 'operador',
    exp: claims.exp || null
  };
  saveUser(cachedMe);
  window.__currentUser = cachedMe;

  return { ok: true, isAdmin };
}

// ==== Logout ====
async function doLogout() {
  try {
    const token = (Auth.loadToken && Auth.loadToken()) || localStorage.getItem('auth_token') || '';
    if (token) {
      const url = AppConfig.apiUrl(AppConfig.endpoints.auth.logout);
      await fetch(url, {
        method: 'POST',
        headers: { 'Authorization': 'Bearer ' + token }
      });
    }
  } catch (_) {
    // Mesmo se o servidor falhar, seguimos limpando o cliente
  } finally {
    stopRefreshTimer();
    try { Auth.clearToken && Auth.clearToken(); } catch { }
    try { Auth.saveUser && Auth.saveUser(null); } catch { }
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    location.replace('/index.html');
  }
}

// ==== Header ====
async function renderUserHeader() {
  try {
    const token = loadToken();
    if (!token) return; // não consulta servidor se não houver token
    const current = window.__currentUser || loadUser();
    if (current && current.ok) { paintHeader(current); return; }
    const me = await whoAmI({ allowCached: false });
    if (me && me.ok) paintHeader(me);
  } catch { }
}
function paintHeader(me) {
  const avatarEl = document.getElementById('user-avatar');
  const nameEl = document.querySelector('#user-greeting, [data-user-name]');
  const roleEl = document.querySelector('#user-role, [data-user-role]');
  const logoutEl = document.querySelector('#btn-logout, #btnLogout');
  const name = clean(me.user?.name || me.user?.username || '');
  const role = clean(me.role || '');
  const fotoUrl = clean(me.user?.foto_url || '');
  if (avatarEl && fotoUrl) { avatarEl.src = fotoUrl; avatarEl.alt = name; avatarEl.style.display = ''; }
  if (nameEl) { nameEl.textContent = name; nameEl.style.display = ''; }
  if (roleEl && role) { roleEl.textContent = role; roleEl.style.display = ''; }
  if (logoutEl) { logoutEl.style.display = ''; }
}

// ==== Refresh silencioso (mantém sessão ativa enquanto houver atividade) ====
let __refreshTimer = null;
let __lastUserActivity = Date.now();

// Rastreia atividade do usuário (mouse, teclado, toque)
function _trackActivity() { __lastUserActivity = Date.now(); }
['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll'].forEach(evt =>
  document.addEventListener(evt, _trackActivity, { passive: true, capture: true })
);

// Margem antes da expiração para disparar o refresh (5 minutos)
const REFRESH_MARGIN_SEC = 300;
// Intervalo de checagem (60 segundos)
const REFRESH_CHECK_INTERVAL_MS = 60000;
// Tempo máximo de inatividade para considerar o usuário "ausente" (1h30m = 5400s)
const INACTIVITY_LIMIT_MS = 5400 * 1000;

async function _tryRefreshToken() {
  try {
    const token = loadToken();
    if (!token) return;

    // Se o usuário está inativo há mais que o limite, não renova
    const idleMs = Date.now() - __lastUserActivity;
    if (idleMs > INACTIVITY_LIMIT_MS) return;

    // Verifica se o token está próximo de expirar
    const claims = parseJwt(token);
    if (!claims || !claims.exp) return;
    const nowSec = Math.floor(Date.now() / 1000);
    const remaining = claims.exp - nowSec;

    // Só renova se faltar menos que a margem
    if (remaining > REFRESH_MARGIN_SEC) return;

    // Chama o endpoint de refresh
    const url = AppConfig.apiUrl(AppConfig.endpoints.auth.refresh);
    const resp = await authFetch(url, { method: 'POST' });
    if (!resp.ok) {
      if (resp.status === 401) {
        clearToken(); saveUser(null);
        window.location.replace('/index.html');
      }
      return;
    }
    const data = await resp.json();
    if (data.token) {
      saveToken(data.token);
      // Atualiza o exp no cache do usuário
      const cached = loadUser();
      if (cached) { cached.exp = data.exp; saveUser(cached); }
    }
  } catch (_) { /* falha silenciosa */ }
}

function startRefreshTimer() {
  if (__refreshTimer) return;
  __refreshTimer = setInterval(_tryRefreshToken, REFRESH_CHECK_INTERVAL_MS);
  // Checa imediatamente também
  _tryRefreshToken();
}

function stopRefreshTimer() {
  if (__refreshTimer) { clearInterval(__refreshTimer); __refreshTimer = null; }
}

// Inicia o timer automaticamente se houver token
if (loadToken()) startRefreshTimer();

window.Auth = { saveToken, loadToken, clearToken, saveUser, loadUser, authFetch, whoAmI, protectPage, doLogin, doLogout, renderUserHeader, startRefreshTimer, stopRefreshTimer };
