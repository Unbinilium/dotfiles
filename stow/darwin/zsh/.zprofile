# language encoding
export LANG="en_US.UTF-8"

# ignore duplicate entries and commands starting with space in history
export HISTCONTROL=ignoreboth

# terminal texts color
export CLICOLOR="1"

# file listing colors
export LSCOLORS="ExFxBxDxCxegedabagacad"

# gcc color output
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# cargo configuration
if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# brew configuration
export PATH="/opt/homebrew/sbin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"

# brew packages configuration
if command -v "brew" > /dev/null 2>&1; then
  # brew environment variables
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1

  # llvm configuration
  export PATH="$(brew --prefix)/opt/llvm/bin:$PATH"
  export LDFLAGS="-L$(brew --prefix)/opt/llvm/lib"
  export CPPFLAGS="-I$(brew --prefix)/opt/llvm/include"

  # container configuration
  if command -v "container" > /dev/null 2>&1; then
    [ ! -f "$(brew --prefix)/share/zsh-completions/_container" ] && container --generate-completion-script zsh > "$(brew --prefix)/share/zsh-completions/_container"
  fi

  # nvm configuration
  export NVM_DIR="$HOME/.nvm"
  [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
  [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

  # load zsh-completions
  ZSH_DISABLE_COMPFIX=true
  FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
  autoload -Uz compinit
  compinit

  # load zsh-autosuggestions
  if [[ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  # load zsh-syntax-highlighting
  if [[ -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="$(brew --prefix)/share/zsh-syntax-highlighting/highlighters"
    source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi

  # load zsh-history-substring-search
  if [[ -f "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
  fi

fi
