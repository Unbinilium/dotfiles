
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"
OS_PREFIX="$( uname | tr '[:upper:]' '[:lower:]' )"
SRC_FILE="$SCRIPT_DIR/$OS_PREFIX/Brewfile"

if [[ -f "$SRC_FILE" ]]; then
  brew bundle install --file="$SRC_FILE"
fi

unset SCRIPT_DIR
unset OS_PREFIX
unset SRC_FILE
