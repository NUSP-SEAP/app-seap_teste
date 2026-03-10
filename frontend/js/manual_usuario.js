/* ==========================================================
   Manual do Usuário — link + alerta de atualização
   Inclua <script src="/js/manual_usuario.js"></script>
   em qualquer página para exibir o botão no canto superior
   direito. Não requer CSS externo.
   ========================================================== */
(function () {
  'use strict';

  var PDF_URL = '/manual/Manual_NUSP.pdf';
  var STORAGE_KEY = 'manual_lastModified';

  /* ---------- CSS (injetado uma única vez) ---------- */
  var css =
    '.manual-nav{position:fixed;top:16px;right:20px;z-index:100;transition:top .2s ease}' +
    '.manual-link{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;' +
    'font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,sans-serif;' +
    'font-size:.8125rem;font-weight:600;color:#475569;text-decoration:none;' +
    'background:#fff;border:1px solid #e2e8f0;border-radius:10px;' +
    'box-shadow:0 2px 8px rgba(0,0,0,.06);' +
    'transition:color .15s,border-color .15s,box-shadow .15s}' +
    '.manual-link:hover{color:#2563eb;border-color:#2563eb;box-shadow:0 2px 12px rgba(37,99,235,.12)}' +
    '.manual-link svg{flex-shrink:0}' +
    '.manual-badge{display:none;font-size:.6875rem;font-weight:700;color:#fff;' +
    'background:#f59e0b;padding:1px 7px;border-radius:999px;line-height:1.4;' +
    'animation:manual-pulse 2s ease-in-out 3}' +
    '.manual-badge.visible{display:inline-block}' +
    '@keyframes manual-pulse{0%,100%{opacity:1}50%{opacity:.5}}';

  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  /* ---------- HTML ---------- */
  var nav = document.createElement('nav');
  nav.className = 'manual-nav';
  nav.innerHTML =
    '<a href="' + PDF_URL + '" id="manual-link" class="manual-link" target="_blank" rel="noopener">' +
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" ' +
    'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
    '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>' +
    '<path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>' +
    '</svg>' +
    'Manual do Usu\u00e1rio' +
    '<span id="manual-badge" class="manual-badge">Atualizado!</span>' +
    '</a>';
  document.body.insertBefore(nav, document.body.firstChild);

  /* ---------- Reposicionar abaixo do header (carregado dinamicamente) ---------- */
  function adjustPosition() {
    var header = document.querySelector('.site-header');
    if (header) {
      nav.style.top = (header.offsetHeight + 10) + 'px';
      return true;
    }
    return false;
  }

  if (!adjustPosition()) {
    var obs = new MutationObserver(function () {
      if (adjustPosition()) obs.disconnect();
    });
    obs.observe(document.body, { childList: true, subtree: true });
  }

  /* ---------- Detecção de atualização ---------- */
  var badge = document.getElementById('manual-badge');
  var link = document.getElementById('manual-link');

  var checkUrl = PDF_URL + '?_t=' + Date.now();
  fetch(checkUrl, { method: 'HEAD', cache: 'no-store' })
    .then(function (r) {
      var lastMod = r.headers.get('Last-Modified');
      if (!lastMod) return;
      var saved = localStorage.getItem(STORAGE_KEY);
      if (saved && saved !== lastMod) {
        badge.classList.add('visible');
      } else if (!saved) {
        localStorage.setItem(STORAGE_KEY, lastMod);
      }
    })
    .catch(function () {});

  link.addEventListener('click', function () {
    fetch(PDF_URL + '?_t=' + Date.now(), { method: 'HEAD', cache: 'no-store' })
      .then(function (r) {
        var lastMod = r.headers.get('Last-Modified');
        if (lastMod) localStorage.setItem(STORAGE_KEY, lastMod);
      })
      .catch(function () {});
    badge.classList.remove('visible');
  });
})();
