#!/bin/sh

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$CURRENT_DIR/scripts/helpers.sh"
agents_marks

if [ "$(agents_vnum)" -lt 302 ]; then
  tmux display-message "tmux-agents: tmux >= 3.2 required (found $(tmux -V 2>/dev/null || echo unknown))"
  exit 0
fi

key="$(agents_opt @agents-key a)"
_ee=''
[ "$(agents_vnum)" -ge 303 ] && _ee=y
if agents_kick_path &&
  _kq="$(agents_shquote "$AGENTS_KICK_PATH")" &&
  _dq="$(agents_shquote "$CURRENT_DIR/scripts")"; then
  _env=''
  for _kv in \
    "AGENTS_PATTERNS=$(agents_opt @agents-patterns "$AGENTS_DEFAULT_PATTERNS")" \
    "AGENTS_TRANSPORTS=$(agents_opt @agents-transports "$AGENTS_DEFAULT_TRANSPORTS")" \
    "AGENTS_TITLES=$(agents_opt @agents-remote-titles "$AGENTS_DEFAULT_TITLES")" \
    "AGENTS_M_ELL=$AGENTS_M_ELL"; do
    _vq="$(agents_shquote "${_kv#*=}")" || continue
    _env="$_env${_kv%%=*}=$_vq "
  done
  [ -n "$_ee" ] && _ee="-e 'AGENTS_KICK=$AGENTS_KICK_PATH' "
  tmux bind-key "$key" "run-shell -b \"$_env AGENTS_KICK_OUT=$_kq exec sh $_dq/collect.sh\" ; display-popup $(agents_popup_args) $_ee\"exec sh $_dq/dashboard.sh\""
  _hk="run-shell -b \"$_env AGENTS_KICK_OUT=$_kq exec sh $_dq/collect.sh\""
  _hkb="run-shell -b \"sleep 0.4; $_env AGENTS_KICK_OUT=$_kq exec sh $_dq/collect.sh\""
  tmux set-hook -g 'pane-exited[4242]' "$_hk" 2>/dev/null
  for _hn in after-new-session after-new-window after-split-window; do
    tmux set-hook -g "${_hn}[4242]" "$_hkb" 2>/dev/null
  done
else
  eval "set -- $(agents_popup_args)"
  tmux bind-key "$key" display-popup "$@" "exec sh '$CURRENT_DIR/scripts/dashboard.sh'"
fi
