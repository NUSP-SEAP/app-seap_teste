
(function () {
  let ran = false;
  function setup() {
    if (ran) return; ran = true;
    const btn = document.querySelector('#btn-logout, #btnLogout');
    if (btn && !btn.dataset.bound) {
      btn.dataset.bound = '1';
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        if (window.Auth) Auth.doLogout(); else location.href = '/index.html';
      });
    }
    // Só tenta renderizar header se houver token; usa cache/variável global primeiro
    if (window.Auth && Auth.loadToken && Auth.renderUserHeader) {
      const hasToken = !!(Auth.loadToken() || '').trim();
      if (hasToken) Auth.renderUserHeader();
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', setup); else setup();
})();