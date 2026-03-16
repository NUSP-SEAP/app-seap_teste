document.addEventListener("DOMContentLoaded", () => {
    // Verifica se o usuário é administrador para mostrar o botão de voltar
    const btnAdmin = document.getElementById("btn-admin-dashboard");

    if (btnAdmin && window.Auth && typeof Auth.loadUser === "function") {
        const session = Auth.loadUser(); // Lê do cache local (auth_jwt.js)

        // Verifica se existe sessão e se a role é 'administrador'
        if (session && session.ok && session.role === 'administrador') {
            btnAdmin.style.display = ""; // Remove o display: none
        }
    }
});