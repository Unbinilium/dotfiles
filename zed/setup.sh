
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

cp -f "$SCRIPT_DIR/settings.json" "$HOME/.config/zed/settings.json"

unset SCRIPT_DIR
