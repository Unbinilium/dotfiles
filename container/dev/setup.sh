
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

if [ ! -f ${HOME}/.ssh/container ]; then
  ssh-keygen -t ed25519 -f ${HOME}/.ssh/container -N "" && \
  rm -rf ${HOME}/.ssh/container.pub
fi
ssh-keygen -y -f ${HOME}/.ssh/container > "${SCRIPT_DIR}/authorized_keys"

container build --tag dev --file "${SCRIPT_DIR}/Dockerfile" "$SCRIPT_DIR"

unset SCRIPT_DIR
