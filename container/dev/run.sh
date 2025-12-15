
set -o errexit -o pipefail

CONTAINER_RUN_NAME="dev"
CONTAINER_PUBLISH="127.0.0.1:10022:22"
CONTAINER_VOLUME="${HOME}/Develop:/root/dev"
CONTAINER_MEMORY="12g"
CONTAINER_CPUS="6"
CONTAINER_IMAGE_NAME="dev"

if container inspect "$CONTAINER_RUN_NAME" | jq -e '. | length == 0' > /dev/null 2>&1; then
  container run --name "$CONTAINER_RUN_NAME" \
    --publish "$CONTAINER_PUBLISH" \
    --volume "$CONTAINER_VOLUME" \
    --ssh --tty --detach \
    --memory "$CONTAINER_MEMORY" \
    --cpus "$CONTAINER_CPUS" \
    "$CONTAINER_IMAGE_NAME"
else
  echo "Container '${CONTAINER_RUN_NAME}' is already exist, skipping run."
fi

unset CONTAINER_RUN_NAME
unset CONTAINER_PUBLISH
unset CONTAINER_VOLUME
unset CONTAINER_MEMORY
unset CONTAINER_CPUS
unset CONTAINER_IMAGE_NAME
