cd php81
docker build . -t registry.gitlab.com/prochazka-dominik/docker/php-application:8.1 --no-cache
docker push registry.gitlab.com/prochazka-dominik/docker/php-application:8.1
