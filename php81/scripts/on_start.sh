#!/bin/bash
set -e

#stop apache2 in case it ran before
service apache2 stop

##### evosoft THIS MUST BE HERE TO CLEANUP FOR ANOTHER RUN OF APACHE
### COPIED FROM OFFICIAL IMAGE https://github.com/docker-library/php/blob/master/7.3/buster/apache/apache2-foreground
# Note: we don't just use "apache2ctl" here because it itself is just a shell-script wrapper around apache2 which provides extra functionality like "apache2ctl start" for launching apache2 in the background.
# (also, when run as "apache2ctl <apache args>", it does not use "exec", which leaves an undesirable resident shell process)

: "${APACHE_CONFDIR:=/etc/apache2}"
: "${APACHE_ENVVARS:=$APACHE_CONFDIR/envvars}"
if test -f "$APACHE_ENVVARS"; then
	. "$APACHE_ENVVARS"
fi

# Apache gets grumpy about PID files pre-existing
: "${APACHE_RUN_DIR:=/var/run/apache2}"
: "${APACHE_PID_FILE:=$APACHE_RUN_DIR/apache2.pid}"
rm -f "$APACHE_PID_FILE"

# create missing directories
# (especially APACHE_RUN_DIR, APACHE_LOCK_DIR, and APACHE_LOG_DIR)
for e in "${!APACHE_@}"; do
	if [[ "$e" == *_DIR ]] && [[ "${!e}" == /* ]]; then
		# handle "/var/lock" being a symlink to "/run/lock", but "/run/lock" not existing beforehand, so "/var/lock/something" fails to mkdir
		#   mkdir: cannot create directory '/var/lock': File exists
		dir="${!e}"
		while [ "$dir" != "$(dirname "$dir")" ]; do
			dir="$(dirname "$dir")"
			if [ -d "$dir" ]; then
				break
			fi
			absDir="$(readlink -f "$dir" 2>/dev/null || :)"
			if [ -n "$absDir" ]; then
				mkdir -p "$absDir"
			fi
		done

		mkdir -p "${!e}"
	fi
done
###

PHP_WWW_PATH="/var/www/evo"

# Create application folders and set permissions
mkdir -p -m 777 $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq
chmod -R g+s $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq
chmod -R 777 $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq

# Default permissions for owning user, group, other
setfacl -d -m u::rwx $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq 2>/dev/null
setfacl -d -m g::rwx $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq 2>/dev/null
setfacl -d -m o::rwx $PHP_WWW_PATH/temp/cache $PHP_WWW_PATH/log $PHP_WWW_PATH/log/supervisor $PHP_WWW_PATH/log/rabbitmq 2>/dev/null


# Copy htaccess-example as htaccess
[ ! -f $PHP_WWW_PATH/www/.htaccess ] && cp $PHP_WWW_PATH/www/.htaccess-example $PHP_WWW_PATH/www/.htaccess

# Run DB migrations
php $PHP_WWW_PATH/bin/console.php migrations:continue

# Declare rabbitmq queues
php $PHP_WWW_PATH/bin/console.php rabbitmq:declareQueuesAndExchanges

# Disable maintenance mode
[ -f $PHP_WWW_PATH/www/maintenance.php ] && mv $PHP_WWW_PATH/www/maintenance.php $PHP_WWW_PATH/www/.maintenance.php

# Dont ask, this must be here for another run
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
