# .zshrc

# enable auto cd
setopt AUTO_CD
setopt CDABLE_VARS

# enable extended globbing
setopt EXTENDED_GLOB

# append to the history file without duplicates
setopt APPEND_HISTORY
setopt HIST_SAVE_NO_DUPS

# enable version control information
autoload -Uz vcs_info

# set the format for the git branch information
zstyle ':vcs_info:git:*' formats '[%b] '

# update the prompt with the current git branch information
precmd () {
  vcs_info
}
setopt PROMPT_SUBST

# set the prompt string
PROMPT='%B%F{240}%2~%f%b ${vcs_info_msg_0_}%(?.%F{green}%#.%F{red}(%?%) %#)%f '

# add user local bin directories to PATH
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# load additional zsh configuration files
if [[ -d "$HOME/.zshrc.d" ]]; then
  for __RC in "$HOME/.zshrc.d"/*; do
    if [[ -f "$__RC" ]]; then
      . "$__RC"
    fi
  done
  unset __RC
fi

# start a tmux session if not already inside one
if [[ "$TERM_PROGRAM" != "vscode" ]] && command -v "tmux" > /dev/null 2>&1; then
  if ! tmux has-session; then
    tmux
  elif [ -z "$TMUX" ]; then
    tmux attach
  fi
fi
