
set -o errexit -o pipefail

git submodule update --init --recursive

usage() {
  cat <<'EOF'
Usage: setup.sh [options]

Options:
  -i, --ignore DIR   Skip running DIR/setup.sh even if present (can be repeated)
  -h, --help         Show this help message
EOF
}

ORDERED_SETUP_DIRS=(
  "brew"
  "stow"
  "code"
  "container"
  "zed"
)
IGNORED_SETUP_DIRS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--ignore)
      shift
      if [[ -z "$1" ]]; then
        echo "Missing directory name for --ignore"
        usage
        exit 1
      fi
      IGNORED_SETUP_DIRS+=("$1")
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

is_ignored() {
  local __target="$1"
  local __ignored
  for __ignored in "${IGNORED_SETUP_DIRS[@]}"; do
    if [[ "$__ignored" == "$__target" ]]; then
      return 0
    fi
  done
  return 1
}


do_setup() {
  local __script_dir="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"
  local __setup_dirs=()
  local __setup_dir_path

  for __setup_dir_path in "${ORDERED_SETUP_DIRS[@]}"; do
    local __dir_name="$( basename "$__setup_dir_path" )"
    if is_ignored "$__dir_name"; then
      continue
    fi
    if ! [[ -d "$__setup_dir_path" ]]; then
      continue
    fi
    if ! command -v "$__dir_name" > /dev/null 2>&1; then
      echo "Warning, command '$__dir_name' not available."
      continue
    fi
    __setup_dirs+=("${__script_dir}/${__setup_dir_path}")
  done

  for __setup_dir_path in "${__setup_dirs[@]}"; do
    if ! [[ -f "$__setup_dir_path/setup.sh" ]]; then
      continue
    fi
    (
      cd "$__setup_dir_path"
      if [[ -f setup.sh ]]; then
        ./setup.sh
      fi
    )
  done
}

do_setup

unset ORDERED_SETUP_DIRS
unset IGNORED_SETUP_DIRS
