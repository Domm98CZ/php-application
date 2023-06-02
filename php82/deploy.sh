#/bin/sh

if [ ! -f "./.env" ]; then
    echo ".env file is missing!" >&2;
    exit 1
fi

source .env

docker network inspect evo_network >/dev/null 2>&1 || docker network create --driver bridge evo_network
docker-compose build --no-cache $(awk '!/(^#)|(^$)/ { printf " --build-arg %s", $0  } END { print ""  }' $@ .env)

if [[ $? -eq 0 ]]; then

    if [ "$EVO_EXPOSE_METHOD" = "traefik" ]; then
        COMPOSESTRING="-f docker-compose.yml -f docker-compose.traefik.yml";
    elif [ "$EVO_EXPOSE_METHOD" = "reverseproxy" ]; then
        COMPOSESTRING="-f docker-compose.yml -f docker-compose.reverseproxy.yml";
    elif [ "$EVO_EXPOSE_METHOD" = "basic" ]; then
        COMPOSESTRING="-f docker-compose.yml -f docker-compose.basic.yml";
    else
        echo "expose method is invalid!" >&2;
        exit 1
    fi

    docker-compose down
    docker-compose $COMPOSESTRING --env-file .env up -d
fi
