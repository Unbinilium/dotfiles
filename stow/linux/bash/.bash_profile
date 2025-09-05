# default umask
umask 022

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

# get the aliases and functions
if [[ -f "$HOME/.bashrc" ]]; then
  . "$HOME/.bashrc"
fi
