
set -o errexit -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )"

container system start
container system status

if command -v "zsh" > /dev/null 2>&1; then
  echo "Generating container zsh completion script..."
  container --generate-completion-script zsh > "$HOME/.zshrc.d/completions/_container"
fi

for __DIR_PATH in "$SCRIPT_DIR"/*/; do
  if ! [[ -f "${__DIR_PATH}setup.sh" ]]; then
      continue
  fi
  (
      cd "${__DIR_PATH}"
      ./setup.sh && ./run.sh
  )
done

container image prune

unset SCRIPT_DIR
unset __DIR_PATH
