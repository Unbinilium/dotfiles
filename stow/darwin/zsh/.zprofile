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

  local __BREW_PREFIX="$(brew --prefix)"

  # llvm configuration
  export PATH="${__BREW_PREFIX}/opt/llvm/bin:$PATH"
  export LDFLAGS="-L${__BREW_PREFIX}/opt/llvm/lib"
  export CPPFLAGS="-I${__BREW_PREFIX}/opt/llvm/include"

  # load zsh-completions
  ZSH_DISABLE_COMPFIX=true
  FPATH="${__BREW_PREFIX}/share/zsh-completions:$HOME/.zshrc.d/completions:$FPATH"
  autoload -Uz compinit
  if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' $HOME/.zcompdump 2>/dev/null)" ]; then
    compinit
  else
    compinit -C
  fi

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
