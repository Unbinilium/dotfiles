#!/bin/sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/helpers.sh"

client="${1:-}"
oldpid="${2:-}"
want="${3:-}"
attach="${4:-}"
[ -n "$client" ] || exit 0

_i=0
while [ -n "$oldpid" ] && [ "$_i" -lt 100 ] && kill -0 "$oldpid" 2>/dev/null; do
  sleep 0.05 2>/dev/null || _i=100
  _i=$((_i + 1))
done

tmux display-popup -C -c "$client" 2>/dev/null

_e3=0
[ "$(agents_vnum)" -ge 303 ] && _e3=1
eval "set -- $(agents_popup_args)"
[ -n "$attach" ] && [ "$_e3" = 1 ] && set -- "$@" -e "AGENTS_ATTACH=$want"
if agents_kick_path; then
  AGENTS_KICK_OUT="$AGENTS_KICK_PATH" sh "$DIR/collect.sh" </dev/null >/dev/null 2>&1 &
  [ "$_e3" = 1 ] && set -- "$@" -e "AGENTS_KICK=$AGENTS_KICK_PATH"
fi
[ "$_e3" = 1 ] && set -- "$@" -e "AGENTS_CLIENT=$client" -e "AGENTS_SELECT=$want"

tmux display-popup -c "$client" "$@" "exec sh '$DIR/dashboard.sh'" 2>/dev/null
