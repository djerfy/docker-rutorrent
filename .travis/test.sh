#!/bin/bash

IMAGE_NAME="rutorrent"

if [ ! -z "${DOCKER_USERNAME}" ]; then
    # maintainer
    echo "Build type: maintainer"
    docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
    docker build --cache-from ${DOCKER_USERNAME}/${IMAGE_NAME}:latest -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${TRAVIS_COMMIT} .
    docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${TRAVIS_COMMIT} ${DOCKER_USERNAME}/${IMAGE_NAME}:nightly
else
    # other
    echo "Build type: other"
    docker build -t local/${IMAGE_NAME}:${TRAVIS_COMMIT}
fi

docker volume create volume_data
docker container run -d --name rutorrent -p 8080:8080 -v volume_data:/data -e DEBUG=${DEBUG:-false} -e GEOIP_ACCOUNT_ID=${GEOIP_ACCOUNT_ID} -e GEOIP_LICENSE_KEY=${GEOIP_LICENSE_KEY} ${DOCKER_USERNAME:-local}/${IMAGE_NAME}:${TRAVIS_COMMIT}
sleep 60
docker ps | grep ${IMAGE_NAME} && echo "Container running successfully"
curl -sL http://127.0.0.1:8080/ | egrep "theUILang.Loading" && echo "ruTorrent running successfully"
docker logs ${IMAGE_NAME}
