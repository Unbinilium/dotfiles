
set -o errexit -o pipefail

git submodule update --init --recursive

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"
ORDERED_SETUP_DIRS=(
  "brew"
  "stow"
  "code"
  "container"
)
SETUP_DIRS=()

for __DIR_PATH in "${ORDERED_SETUP_DIRS[@]}"; do
  if ! [[ -d "$__DIR_PATH" ]]; then
    continue
  fi
  if ! command -v "$( basename "$__DIR_PATH" )" > /dev/null 2>&1; then
    echo "Warning, command $( basename "$__DIR_PATH" ) not available."
    continue
  fi
  SETUP_DIRS+=("${SCRIPT_DIR}/${__DIR_PATH}")
done

for __DIR_PATH in "${SETUP_DIRS[@]}"; do
  if ! [[ -f "$__DIR_PATH/setup.sh" ]]; then
    continue
  fi
  (
    cd "$__DIR_PATH"
    if [[ -f setup.sh ]]; then
      ./setup.sh
    fi
  )
done

unset SCRIPT_DIR
unset ORDERED_SETUP_DIRS
unset SETUP_DIRS
unset __DIR_PATH
