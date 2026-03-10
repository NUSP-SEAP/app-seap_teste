function doServerLogout() {
  if (window.Auth && typeof Auth.doLogout === 'function') return Auth.doLogout();
  // Fallback emergencial
  localStorage.removeItem('auth_token');
  localStorage.removeItem('auth_user');
  location.href = '/index.html';
}
window.doServerLogout = doServerLogout;
