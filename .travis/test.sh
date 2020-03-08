#!/bin/bash

IMAGE_NAME="rutorrent"

if [ ! -z "${DOCKER_USERNAME}" ]; then
    echo "Build type: maintainer"
    # download previous image for reuse cache
    docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
    docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:nofilebot
    # build image with filebot
    docker build --cache-from ${DOCKER_USERNAME}/${IMAGE_NAME}:latest -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${TRAVIS_COMMIT} .
    docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${TRAVIS_COMMIT} ${DOCKER_USERNAME}/${IMAGE_NAME}:nightly
    # build image without filebot
    docker build --cache-from ${DOCKER_USERNAME}/${IMAGE_NAME}:nofilebot -t ${DOCKER_USERNAME}:${IMAGE_NAME}:${TRAVIS_COMMIT}-nofilebot .
    docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${TRAVIS_COMMIT}-nofilebot ${DOCKER_USERNAME}/${IMAGE_NAME}:nightly-nofilebot
else
    echo "Build type: other"
    # build image with filebot
    INSTALL_FILEBOT=yes docker build -t local/${IMAGE_NAME}:${TRAVIS_COMMIT}
    # build image without filebot
    INSTAL_FILEBOT=no docker build -t local/${IMAGE_NAME}:${TRAVIS_COMMIT}-nofilebot
fi

# test image with filebot
echo "Run test: ${IMAGE_NAME}:${TRAVIS_COMMIT}"
docker volume create volume_data_default
docker container run -d --name rutorrent -p 8080:8080 -v volume_data_default:/data -e DEBUG=${DEBUG:-false} ${DOCKER_USERNAME:-local}/${IMAGE_NAME}:${TRAVIS_COMMIT}
sleep 60
docker ps | grep ${IMAGE_NAME} && echo "Container running successfully"
curl -sL http://127.0.0.1:8080/ | egrep "theUILang.Loading" && echo "ruTorrent running successfully"
docker logs ${IMAGE_NAME}
docker stop rutorrent
docker rm rutorrent

# test image without filebot
echo "Run test: ${IMAGE_NAME}:${TRAVIS_COMMIT}-nofilebot"
docker volume create volume_data_nofilebot
docker container run -d --name rutorrent-nofilebot -p 8080:8080 -v volume_data_nofilebot:/data -e DEBUG=${DEBUG:-false} ${DOCKER_USERNAME:-local}/${IMAGE_NAME}:${TRAVIS_COMMIT}-nofilebot
sleep 60
docker ps | grep ${IMAGE_NAME}-nofilebot && echo "Container running successfully"
curl -sL http://127.0.0.1:8080/ | egrep "theUILang.Loading" && echo "ruTorrent running successfully"
docker logs ${IMAGE_NAME}-nofilebot
docker stop rutorrent-nofilebot
docker rm rutorrent-nofilebot