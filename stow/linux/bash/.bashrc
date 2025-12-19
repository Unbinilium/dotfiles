# .bashrc

# return if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

# avoid duplicate entries
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# enable automatic window resizing
shopt -s checkwinsize

# enable recursive globbing
shopt -s globstar

# make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt
case "$TERM" in
  xterm-color|*-256color) color_prompt=yes;;
esac

force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
  else
    color_prompt=
  fi
fi
if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# if this is an xterm set the title to user@host:dir
case "$TERM" in
  xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" ;;
  *) ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias dir='dir --color=auto'
  alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# add an "alert" alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# alias definitions
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# add user local bin directories to PATH
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# load additional bash configuration files
if [[ -d "$HOME/.bashrc.d" ]]; then
  for __RC in "$HOME/.bashrc.d"/*; do
    if [[ -f "$__RC" ]]; then
      . "$__RC"
    fi
  done
  unset __RC
fi

# start a tmux session if not already inside one
if command -v "tmux" > /dev/null 2>&1 && [[ -z "$SSH_CONNECTION" ]] && [[ ! "$TERM_PROGRAM" =~ "(vscode|zed)" ]]; then
  if ! tmux has-session; then
    tmux
  elif [ -z "$TMUX" ]; then
    tmux attach
  fi
fi
