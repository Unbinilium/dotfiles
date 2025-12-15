#!/bin/zsh

# cargo configuration
if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# brew packages configuration
if command -v "brew" > /dev/null 2>&1; then

  # brew environment variables
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1

  __BREW_PREFIX="$(brew --prefix)"

  # llvm configuration
  export PATH="${__BREW_PREFIX}/opt/llvm/bin:$PATH"
  export LDFLAGS="-L${__BREW_PREFIX}/opt/llvm/lib"
  export CPPFLAGS="-I${__BREW_PREFIX}/opt/llvm/include"

  # nvm configuration
  export NVM_DIR="$HOME/.nvm"
  [ -s "${__BREW_PREFIX}/opt/nvm/nvm.sh" ] && \. "${__BREW_PREFIX}/opt/nvm/nvm.sh"
  [ -s "${__BREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm" ] && \. "${__BREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm"

  # load zsh-completions
  ZSH_DISABLE_COMPFIX=true
  FPATH="${__BREW_PREFIX}/share/zsh-completions:$HOME/.zshrc.d/completions:$FPATH"
  autoload -Uz compinit
  compinit

  # load zsh-autosuggestions
  if [[ -f "${__BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${__BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  # load zsh-syntax-highlighting
  if [[ -f "${__BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="${__BREW_PREFIX}/share/zsh-syntax-highlighting/highlighters"
    source "${__BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi

  # load zsh-history-substring-search
  if [[ -f "${__BREW_PREFIX}/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "${__BREW_PREFIX}/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
  fi

  unset __BREW_PREFIX

fi
