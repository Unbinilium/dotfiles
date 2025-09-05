
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"
SETUP_DIRS=()

for __DIR_PATH in "$SCRIPT_DIR"/*; do

  if ! [[ -d "$__DIR_PATH" ]]; then
    continue
  fi

  if ! command -v "$( basename "$__DIR_PATH" )" > /dev/null 2>&1; then
    echo "Error, command $( basename "$__DIR_PATH" ) not available."
    exit 1
  fi

  SETUP_DIRS+=("$__DIR_PATH")

done

for __DIR_PATH in "${SETUP_DIRS[@]}"; do
  (
    cd "$__DIR_PATH"
    if [[ -f setup.sh ]]; then
      ./setup.sh
    fi
  )
done

unset SCRIPT_DIR
unset SETUP_DIRS
unset __DIR_PATH
