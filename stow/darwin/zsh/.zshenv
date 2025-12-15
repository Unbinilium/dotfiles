#!/bin/zsh

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

# brew configuration
export PATH="/opt/homebrew/sbin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
