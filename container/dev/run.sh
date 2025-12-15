
set -o errexit -o pipefail

CONTAINER_IMAGE_NAME="dev"
CONTAINER_RUN_NAME="dev"
CONTAINER_MEMORY_LIMIT="12g"
CONTAINER_CPU_LIMIT="6"

if container ls --format table | grep -q "^${CONTAINER_RUN_NAME}$"; then
  echo "Container ${CONTAINER_RUN_NAME} is already running, skipping run."
  exit 0
fi

container run --name "$CONTAINER_RUN_NAME" \
  --publish 127.0.0.1:10022:22 \
  --volume "${HOME}/Develop:/root/dev" \
  --ssh --tty --detach \
  --memory "$CONTAINER_MEMORY_LIMIT" \
  --cpus "$CONTAINER_CPU_LIMIT" \
  "$CONTAINER_IMAGE_NAME"

unset CONTAINER_IMAGE_NAME
unset CONTAINER_RUN_NAME
unset CONTAINER_MEMORY_LIMIT
unset CONTAINER_CPU_LIMIT
