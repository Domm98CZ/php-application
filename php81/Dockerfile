ARG PHP_SERVER_VERSION

FROM registry.gitlab.com/prochazka-dominik/docker/php-server:${PHP_SERVER_VERSION:-1.0}

ARG PHP_GITLAB_BRANCH
ARG PHP_ENVIRONMENT
ARG PHP_USE_PROXY
ARG PHP_ENV_PROXY
ARG PHP_GITLAB_PATH
ARG PHP_GITLAB_TOKEN_USER
ARG PHP_GITLAB_TOKEN
ARG PHP_DEBUG
ARG PHP_URL
ARG PHP_APPLICATION

# Config
ENV     PHP_APPLICATION_DIR /var/www/app

# PHP Settings
COPY    ./php_settings/php_custom_settings.ini ${PHP_PHP_INI_DIR}/conf.d/
RUN     chmod 644 ${PHP_PHP_INI_DIR}/conf.d/php_custom_settings.ini

# Check if variables are present in .env file
RUN     if [ -z "${PHP_APPLICATION}" ]  || [ -z "${PHP_URL}" ]  || [ -z "${PHP_DEBUG}" ]  || [ -z "${PHP_GITLAB_BRANCH}" ] || [ -z "${PHP_ENVIRONMENT}" ] || [ -z "${PHP_USE_PROXY}" ] || [ -z "${PHP_GITLAB_PATH}" ] || [ -z "${PHP_GITLAB_TOKEN_USER}" ] || [ -z "${PHP_GITLAB_TOKEN}" ]; then exit 1; fi

# Apache Settings
COPY    ./apache_settings/apache_http.conf /etc/apache2/sites-available/apache_http.conf
RUN     cd /etc/apache2/sites-available && a2dissite --quiet * \
        && a2enmod --quiet rewrite \
        && a2enmod --quiet expires \
        && a2enmod --quiet headers \
        && a2ensite --quiet apache_http.conf

# SUPERVISOR
COPY    ./supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY    ./supervisor/scripts/default.conf /etc/supervisor/conf.d/default.conf
COPY    ./supervisor/scripts/services.conf /etc/supervisor/conf.d/services.conf

# CRONTAB
COPY    ./cronjobs/crontab /tmp/crontab
RUN     crontab /tmp/crontab \
        && rm /tmp/crontab

# Prepare proxy
RUN     if [ "${PHP_USE_PROXY}" = true ]; then export HTTP_PROXY="http://${PHP_ENV_PROXY}/" && export HTTPS_PROXY="http://${PHP_ENV_PROXY}/"; else echo ""; fi

# Prepare application
RUN     mkdir -p ${PHP_APPLICATION_DIR} \
        && if [ "${PHP_USE_PROXY}" = true ]; then git config --global http.proxy "${PHP_ENV_PROXY}"; else echo ""; fi \
        && git clone --branch "${PHP_GITLAB_BRANCH}" "${PHP_GITLAB_PATH%%:*}://${PHP_GITLAB_TOKEN_USER}:${PHP_GITLAB_TOKEN}@${PHP_GITLAB_PATH#*://}" ${PHP_APPLICATION_DIR}

# Setup application maintenance
RUN     mv ${PHP_APPLICATION_DIR}/www/.maintenance.php ${PHP_APPLICATION_DIR}/www/maintenance.php

# Touch config.local.neon
RUN     touch ${PHP_APPLICATION_DIR}/config/local.neon

# Composer
RUN     cd ${PHP_APPLICATION_DIR} && composer install --no-dev --prefer-dist

# NPM
RUN     if [ "${PHP_USE_PROXY}" = true ]; then npm config set https-proxy http://${PHP_ENV_PROXY}/ else echo ""; fi
RUN     cd ${PHP_APPLICATION_DIR}/www && npm install --only=prod

# Debug
RUN     if [ "${PHP_DEBUG}" = "true" ]; then touch ${PHP_APPLICATION_DIR}/app/.debug; else echo ""; fi

# Startup script
COPY    ./scripts/on_start.sh /usr/local/sbin/
RUN     chmod +x /usr/local/sbin/on_start.sh

CMD     on_start.sh && /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

WORKDIR ${PHP_APPLICATION_DIR}
