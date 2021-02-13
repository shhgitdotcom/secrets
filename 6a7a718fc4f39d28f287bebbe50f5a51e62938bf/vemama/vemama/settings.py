"""
Django settings for Vemama project.
"""

import os
from decouple import config, Csv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE_DIR = os.path.join(BASE_DIR, 'templates')

SECRET_KEY = config("SECRET_KEY", default="kbj5e+y=b85!")

DEBUG = config("DEBUG", default="False", cast=bool)

ALLOWED_HOSTS = ["127.0.0.1", "vemama.pancho.cz", "testserver"]

INTERNAL_IPS = [
    '127.0.0.1',
]

DEBUG_TOOLBAR_CONFIG = {
    'SHOW_TEMPLATE_CONTEXT': True,
}

# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    "rest_framework",
    "crispy_forms",
    "simple_history",
    "core.apps.CoreConfig",
    "cars",
    "tasks",
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'simple_history.middleware.HistoryRequestMiddleware',
]

ROOT_URLCONF = 'vemama.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [TEMPLATE_DIR, ],
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

WSGI_APPLICATION = 'vemama.wsgi.application'

# Database
# https://docs.djangoproject.com/en/2.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': config("DB_NAME", default="test"),
        'USER': config("DB_USER", default="postgres"),
        'PASSWORD': config("DB_PASSWORD", default="postgres"),
        'HOST': config("DB_HOST", default="localhost"),
        'PORT': config("DB_PORT", default="5432"),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
# https://docs.djangoproject.com/en/2.2/topics/i18n/

LANGUAGE_CODE = 'cs-cz'

TIME_ZONE = 'CET'

USE_I18N = False

USE_L10N = True

USE_TZ = True

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/2.2/howto/static-files/

STATIC_URL = '/static/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static'), ]

CRISPY_TEMPLATE_PACK = 'bootstrap4'

LOGIN_URL = "/login"
LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'

THOUSAND_SEPARATOR = " "
DECIMAL_SEPARATOR = ","
USE_THOUSAND_SEPARATOR = True

# email settings

EMAIL_BACKEND = config("EMAIL_BACKEND", default="django.core.mail.backends.smtp.EmailBackend")
EMAIL_HOST = config("EMAIL_HOST", default="")
EMAIL_USE_SSL = config("EMAIL_USE_SSL", default="True", cast=bool)
EMAIL_PORT = config("EMAIL_PORT", default=0, cast=int)
EMAIL_HOST_USER = config("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = config("EMAIL_HOST_PASSWORD", default="")
DEFAULT_FROM_EMAIL = config("DEFAULT_FROM_EMAIL", default="vemama@pancho.cz")

# APP settings
ROUTINE_CHECK_INTERVAL = config("ROUTINE_CHECK_INTERVAL", default=30, cast=int)
CHECK_TASK_DUE_DATE = config("CHECK_TASK_DUE_DATE", default=15, cast=int)
CAR_SERVICE_KM_THRESHOLD = config("CAR_SERVICE_KM_THRESHOLD", default=3000, cast=int)
CAR_SERVICE_DAYS_THRESHOLD = config("CAR_SERVICE_DAYS_THRESHOLD", default=30, cast=int)
CAR_TYRE_SWITCH_DAYS_THRESHOLD = config("CAR_TYRE_SWITCH_DAYS_THRESHOLD", default=45, cast=int)
WINTER_TYRE_SWITCH_DUE_DATE = config("WINTER_TYRE_SWITCH_DUE_DATE", default="10,31", cast=Csv())
SUMMER_TYRE_SWITCH_DUE_DATE = config("SUMMER_TYRE_SWITCH_DUE_DATE", default="5,30", cast=Csv())

# Zemtu API
Z_TOKEN = config("Z_TOKEN", default="")
