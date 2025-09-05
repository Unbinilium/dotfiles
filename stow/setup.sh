
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

ls "$SCRIPT_DIR/common" | xargs -I {} stow -d "$SCRIPT_DIR/common" -t "$HOME" --restow {}

case "$( uname -s )" in
  Linux*)
    ls "$SCRIPT_DIR/linux" | xargs -I {} stow -d "$SCRIPT_DIR/linux" -t "$HOME" --restow {}
    ;;
  Darwin*)
    ls "$SCRIPT_DIR/darwin" | xargs -I {} stow -d "$SCRIPT_DIR/darwin" -t "$HOME" --restow {}
    ;;
  *)
    exit 1
    ;;
esac

unset SCRIPT_DIR
