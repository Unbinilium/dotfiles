
set -o errexit -o pipefail

do_setup() {
  local __script_dir="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"
  local __setup_dir_path

  for __setup_dir_path in "$__script_dir"/*/; do
    if ! [[ -f "${__setup_dir_path}setup.sh" ]]; then
        continue
    fi
    (
        cd "${__setup_dir_path}"
        ./setup.sh && ./run.sh
    )
  done
}

container system start
container system status

if command -v "zsh" > /dev/null 2>&1; then
  echo "Generating container zsh completion script..."
  container --generate-completion-script zsh > "$HOME/.zshrc.d/completions/_container"
fi

do_setup

container image prune
