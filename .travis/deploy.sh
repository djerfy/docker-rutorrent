#!/bin/bash

IMAGE_TAG="$1"
IMAGE_NAME="rutorrent"

do_tag(){
    local SRC=$1
    local DST=$2
    docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${SRC} ${DOCKER_USERNAME}/${IMAGE_NAME}:${DST}
}

do_push(){
    local TAG=$1
    docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}
    echo "Publish image ${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG} to Docker Hub"
}

case "${IMAGE_TAG}" in
    nightly)
        # push image with tag 'nightly' only
        do_tag ${TRAVIS_COMMIT} nightly
        do_push nightly
        ;;
    latest)
        [ -z "${TRAVIS_TAG}" ] && echo "Error variable TRAVIS_TAG is not defined" && exit 1
        # push image with tags 'nightly', tag version and 'latest'
        for TARGET in nightly ${TRAVIS_TAG} latest; do
            do_tag ${TRAVIS_COMMIT} ${TARGET}
            do_push ${TARGET}
        done
        ;;
    *)
        echo "Usage: $0 [nightly|latest]"
        exit 1
        ;;
esac
