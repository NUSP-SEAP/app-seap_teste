import os
from pathlib import Path

import dj_database_url
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv("SECRET_KEY", "dev-insecure-replace-me")
DEBUG = os.getenv("DEBUG", "True").lower() in ["1","true","yes","on"]
ALLOWED_HOSTS = [h for h in os.getenv("ALLOWED_HOSTS", "*").split(",") if h]

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'senado_nusp.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'senado_nusp.wsgi.application'

# Database
DATABASES = {
    'default': dj_database_url.config(
        default=os.getenv('DATABASE_URL', 'sqlite:///' + str(BASE_DIR / 'db.sqlite3')),
        conn_max_age=600,
        ssl_require=False
    )
}

# Password validation (not used; we manage our own auth for API users)
AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = str(BASE_DIR / 'staticfiles')

# --- API / CORS ---
CORS_ALLOWED_ORIGINS = [o for o in os.getenv("CORS_ALLOWED_ORIGINS", "https://senado-nusp.cloud").split(",") if o]
CORS_ALLOW_CREDENTIALS = False
CORS_ALLOW_HEADERS = [
    "accept",
    "authorization",
    "cache-control",
    "content-type",
    "expires",
    "if-modified-since",
    "if-none-match",
    "pragma",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
]

CSRF_TRUSTED_ORIGINS = [o for o in os.getenv("CSRF_TRUSTED_ORIGINS", "").split(",") if o]

# --- JWT ---
AUTH_JWT_SECRET = os.getenv("AUTH_JWT_SECRET", "dev-jwt-secret-replace")
AUTH_JWT_TTL_SEC = int(os.getenv("AUTH_JWT_TTL_SEC", "5400"))   # 1h30m padrão
AUTH_JWT_COOKIE_NAME = os.getenv("AUTH_JWT_COOKIE_NAME", "sn_auth_jwt")
AUTH_JWT_COOKIE_DOMAIN = os.getenv("AUTH_JWT_COOKIE_DOMAIN", "")

# --- Sessão ---
# Deve ter o mesmo valor que AUTH_JWT_TTL_SEC (sessão expira por inatividade, não por tempo fixo)
SESSION_TOUCH_MAX_AGE_SECONDS = int(os.getenv("SESSION_TOUCH_MAX_AGE_SECONDS", "5400"))  # 1h30m padrão

# --- Arquivos de upload (fotos) ---
FILES_DIR = os.getenv("FILES_DIR", str(BASE_DIR / "public"))
FILES_URL_PREFIX = os.getenv("FILES_URL_PREFIX", "/files/")
OPERADORES_DIRNAME = "operadores"

# Diretório será criado em api/apps.py → AppConfig.ready()
