#!/usr/bin/env sh

TMP_ENV_FILE=.owl_env.tmp
IMAGE_NAME=open_owl-owl

store_relevant_env_variables() {
  printenv|grep OWL > $TMP_ENV_FILE
}

exists_docker_image() {
  docker image ls -q $IMAGE_NAME:latest 2> /dev/null
}

build_docker_image() {
  docker build -t $IMAGE_NAME:latest .
}

store_relevant_env_variables

if [ "$(exists_docker_image)" == "" ]; then
  echo "Docker image does not exist yet, creating one..."
  build_docker_image
fi

docker run --rm -it \
           -v `pwd`/auth_cache:/app/auth_cache \
           -v `pwd`/results:/app/results \
           -v `pwd`/recipes.yml:/app/recipes.yml \
           --env-file $TMP_ENV_FILE \
           $IMAGE_NAME $@
result=$?

rm -f $TMP_ENV_FILE

exit $result