
import django_heroku
from pathlib import Path


# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/3.1/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'fqq4ai8f_-r^6duq*vkgrvx14a!l1=#&oav1@cgq17#4@o-@gg'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = []


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'leaderboard',
    'django_guid',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django_guid.middleware.guid_middleware',
]

ROOT_URLCONF = 'gjg.urls'

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

WSGI_APPLICATION = 'gjg.wsgi.application'


# Database
# https://docs.djangoproject.com/en/3.1/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


DJANGO_GUID = {
    'GUID_HEADER_NAME': 'Correlation-ID',
    'VALIDATE_GUID': True,
    'RETURN_HEADER': True,
    'EXPOSE_HEADER': True,
    'INTEGRATIONS': [],
    'IGNORE_URLS': [],
    'UUID_LENGTH': 32,
}

REDIS_HOST = 'localhost'
REDIS_PORT = 6379


CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://127.0.0.1:6379/",
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient"
        }
    }
}

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'filters': {
        'correlation_id': {'()': 'django_guid.log_filters.CorrelationId'},  # <-- Add correlation ID
        'celery_tracing': {'()': 'django_guid.integrations.celery.log_filters.CeleryTracing'},  # <-- Add celery IDs
    },
    'formatters': {
        # Basic log format without django-guid filters
        'basic_format': {'format': '%(levelname)s %(asctime)s %(name)s - %(message)s'},

        # Format with correlation ID output to the console
        'correlation_id_format': {'format': '%(levelname)s %(asctime)s [%(correlation_id)s] %(name)s - %(message)s'},

        # Format with correlation ID plus a celery process' parent ID and a unique current ID that will
        # become the parent ID of any child processes that are created (most likely you won't want to
        # display these values in your formatter, but include them just as a filter)
        'celery_depth_format': {
            'format': '%(levelname)s [%(correlation_id)s] [%(celery_parent_id)s-%(celery_current_id)s] %(name)s - %(message)s'
        },
    },
    'handlers': {
        'correlation_id_handler': {
            'class': 'logging.StreamHandler',
            'formatter': 'correlation_id_format',
            # Here we include the filters on the handler - this means our IDs are included in the logger extra data
            # and *can* be displayed in our log message if specified in the formatter - but it will be
            # included in the logs whether shown in the message or not.
            'filters': ['correlation_id', 'celery_tracing'],
        },
        'celery_depth_handler': {
            'class': 'logging.StreamHandler',
            'formatter': 'celery_depth_format',
            'filters': ['correlation_id', 'celery_tracing'],
        },
    },
    'loggers': {
        'django': {
            'handlers': ['correlation_id_handler'],
            'level': 'INFO'
        },
        'demoproj': {
            'handlers': ['correlation_id_handler'],
            'level': 'DEBUG'
        },
        'django_guid': {
            'handlers': ['correlation_id_handler'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'django_guid.celery': {
            'handlers': ['celery_depth_handler'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'celery': {
            'handlers': ['celery_depth_handler'],
            'level': 'INFO',
        },
    }
}


# Password validation
# https://docs.djangoproject.com/en/3.1/ref/settings/#auth-password-validators

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
# https://docs.djangoproject.com/en/3.1/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_L10N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/3.1/howto/static-files/
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATIC_URL = '/static/'

django_heroku.settings(locals())
