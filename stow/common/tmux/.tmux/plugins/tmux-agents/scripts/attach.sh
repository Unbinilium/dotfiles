#!/bin/sh
# attach.sh <pane_id> <session> <window_id> [cols] [lines] [view] [placeholder]
# exit:
#   - 0 back to the dashboard
#   - 3 the agent is gone
#   - 4 the view failed
#   - 5 held by another popup
#   - 10 close the popup
#   - 12 a jump with nowhere to go
#   - 13 the terminal changed size and the popup must be rebuilt.

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/helpers.sh"

pane="$1" session="$2" win_id="$3"
cols="${4:-100}" lines="${5:-30}"
pre_view="${6:-}" pre_ph="${7:-}"
sock="${TMUX%%,*}"
T="$AGENTS_TAB"
S="$AGENTS_SEP"
NL='
'

_all="$(tmux display-message -p -t "$pane" "P$T#{?@agents_owned,1,0}$T#{session_name}" \; \
  display-message -p -t "$win_id" "W$T#{window_index}$T#{window_zoomed_flag}$T#{pane_id}$T#{?automatic-rename,,#{window_name}}" \; \
  display-message -p -t "=$session:" "S$T#{session_name}" \; \
  display-message -p '==OPT==' \; \
  display-message -p "$S#{prefix}$S#{mode-style}$S#{@agents-key}$S#{@agents-readonly}$S#{@agents-glyphs}$S#{@agents-view-style}$S#{@agents-view-keys}$S#{@agents-view-status}$S#{@agents-view-git}$S#{@agents-recenter}$S#{@agents-session-prefix}" \; \
  display-message -p '==KEYS==' \; \
  list-keys -T root 2>/dev/null)"
keys_blob=''
case "$_all" in
*"$NL==KEYS==$NL"*)
  keys_blob="${_all#*"$NL==KEYS==$NL"}"
  _all="${_all%%"$NL==KEYS==$NL"*}"
  ;;
*) _all="${_all%%"$NL==KEYS=="*}" ;;
esac
_opt=''
case "$_all" in
*"$NL==OPT==$NL"*)
  _opt="${_all#*"$NL==OPT==$NL"}"
  _all="${_all%%"$NL==OPT==$NL"*}"
  ;;
*) _all="${_all%%"$NL==OPT=="*}" ;;
esac
pane_ln='' win_ln='' ses_ok=0
while IFS= read -r _l; do
  case "$_l" in
  "P$T"*) pane_ln="$_l" ;;
  "W$T"*) win_ln="$_l" ;;
  "S$T"*) [ "${_l#S"$T"}" = "$session" ] && ses_ok=1 ;;
  esac
done <<EOF
$_all
EOF
agents_opt_flavour "$_opt"
S="$AGENTS_OS" _opt="$AGENTS_OV"
o_pk="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_msty="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_hk="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_ro="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_glyphs="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_vsty="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_vkeys="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_vstat="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_vgit="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_recenter="${_opt%%"$S"*}"; _opt="${_opt#*"$S"}"
o_sprefix="$_opt"

[ "$ses_ok" = 1 ] || exit 3
[ -n "$pane_ln" ] || exit 3
_r="${pane_ln#P"$T"}"
pane_owned="${_r%%"$T"*}"
pane_ses="${_r#*"$T"}"
[ -n "$pane_ses" ] || exit 3
if [ "$pane_owned" = 1 ] && [ "$pane_ses" != "$pre_view" ]; then
  agents_reclaim "$pane" "$pane_ses" || exit 5
fi
[ -n "$win_ln" ] || exit 3
_r="${win_ln#W"$T"}"
win_idx="${_r%%"$T"*}"
_r="${_r#*"$T"}"
prev_zoom="${_r%%"$T"*}"
_r="${_r#*"$T"}"
prev_zoom_pane="${_r%%"$T"*}"
win_name="${_r#*"$T"}"
[ -n "$win_idx" ] || exit 3
[ "$prev_zoom" = 1 ] && tmux resize-pane -Z -t "$win_id" 2>/dev/null

pk="${o_pk:-C-b}"
[ "$pk" != None ] || pk=C-b
hk="${o_hk:-a}"
ro=0
[ "${o_ro:-off}" = on ] && ro=1

mset="${o_glyphs:-ascii}"
case "$mset" in unicode | dot) ;; *) mset=ascii ;; esac
agents_marks "$mset"
sep="$AGENTS_M_SEP"

vsty="$o_vsty"
[ -n "$vsty" ] || vsty="$o_msty"
[ -n "$vsty" ] || vsty='fg=black,bg=yellow'

view_keys() { # view_keys <view session> <the root table, as list-keys wrote it>
  [ -n "$2" ] || return 1
  _kb="$(printf '%s\n' "$2" | awk '
    $1 == "bind-key" && $2 == "-T" && $3 == "root" {
      k = $4
      sub(/^([CMS]-)+/, "", k)
      if (k ~ /^(Wheel|Mouse|DoubleClick|TripleClick|SecondClick)/) {
        sub(/^bind-key +-T root +/, "bind-key -T agents-root ")
        print
      }
    }')"
  agents_tmp_dir
  _kf="$AGENTS_TMP/tmux-agents-keys.$$"
  {
    printf '%s\n' "bind-key -T agents-root F12 detach-client"
    printf '%s\n' "unbind-key -a -T agents-root"
    printf '%s\n' "bind-key -T agents-view F12 detach-client"
    printf '%s\n' "unbind-key -a -T agents-view"
    printf '%s\n' "$_kb"
    printf '%s\n' "bind-key -T agents-root $pk switch-client -T agents-view"
    printf '%s\n' "bind-key -T agents-view $pk send-keys $pk"
    printf '%s\n' "bind-key -T agents-view $hk detach-client"
    printf '%s\n' "bind-key -T agents-view d detach-client"
    printf '%s\n' "bind-key -T agents-view j set-option @agents_action jump \\; detach-client"
    printf '%s\n' "bind-key -T agents-view q set-option @agents_action close \\; detach-client"
    printf '%s\n' "bind-key -T agents-view [ copy-mode"
    printf '%s\n' "bind-key -T agents-view ] paste-buffer -p"
    printf '%s\n' "bind-key -T agents-view PPage copy-mode -u"
    printf '%s\n' "bind-key -T agents-view : command-prompt"
  } >"$_kf" 2>/dev/null
  [ -s "$_kf" ] || { rm -f "$_kf"; return 1; }
  tmux source-file "$_kf" 2>/dev/null || { rm -f "$_kf"; return 1; }
  rm -f "$_kf"
  tmux set-option -t "$1" key-table agents-root \; set-option -t "$1" prefix None \; set-option -t "$1" prefix2 None 2>/dev/null
}

view_status() { # view_status <view session> <1 if the view has its own keys>
  _loc="$session:$win_idx"
  _wn="$win_name"
  [ -n "$_wn" ] && [ "$((${#_loc} + 1 + ${#_wn}))" -le 24 ] && _loc="$_loc:$_wn"
  _tight="#{e|<:#{client_width},90}"
  _narrow="#{e|<:#{client_width},80}"
  _flag=''
  [ "${o_vgit:-on}" = on ] && _flag=' git'
  _info="#{?$_tight,,#(sh $(agents_shquote "$DIR/viewinfo.sh") #{q:pane_current_path} $mset$_flag)}"
  _pkh="$(agents_fmt_literal "$pk")"
  case "$_pkh" in *,*) _pkh='' ;; esac
  if [ "$2" = 1 ]; then
    _wide=" $_pkh d back / j jump / q close"
    _keys="#{?$_narrow, d back / j jump / q close,$_wide}"
  elif [ "$ro" = 1 ]; then
    _wide=" read-only $sep $_pkh d back"
    _keys="$_wide"
  else
    _wide=" $_pkh d back / $_pkh $(agents_fmt_literal "$hk") dashboard"
    _keys="$_wide"
  fi
  _rlen=${#_wide}
  [ "$_rlen" -lt 10 ] && _rlen=10
  _llen=$((cols - _rlen - 1))
  [ "$_llen" -lt 24 ] && _llen=24
  tmux set-option -t "$1" status on \; \
    set-option -t "$1" status-style "$vsty" \; \
    set-option -t "$1" status-left-style default \; \
    set-option -t "$1" status-right-style default \; \
    set-option -t "$1" status-interval 5 \; \
    set-option -t "$1" status-left \
    "$(agents_fmt_literal "${AGENTS_NAME:-agent}") $sep $(agents_fmt_literal "$_loc")$_info " \; \
    set-option -t "$1" status-left-length "$_llen" \; \
    set-option -t "$1" status-right "$_keys" \; \
    set-option -t "$1" status-right-length "$_rlen" \; \
    set-option -t "$1" window-status-format '' \; \
    set-option -t "$1" window-status-current-format '' 2>/dev/null
}

view_watch() { # view_watch <view session> <client> <geometry now>
  _ww="$1" _wc="$2" _wg="$3" _seen=''
  while tmux has-session -t "=$_ww" 2>/dev/null; do
    sleep 1 2>/dev/null || return 0
    agents_client_geo "$_wc" || return 0
    _g="$AGENTS_GEO"
    if [ "$_g" = "$_wg" ]; then
      _seen=''
      continue
    fi
    [ "$_g" = "$_seen" ] || { _seen="$_g"; continue; }
    tmux set-option -t "$_ww" @agents_action resize 2>/dev/null
    tmux detach-client -s "=$_ww" 2>/dev/null
    return 0
  done
}

embedded=0
if [ -n "$pre_view" ] && [ -n "$pre_ph" ] && [ "$pane_ses" = "$pre_view" ]; then
  view="$pre_view"
  ph="$pre_ph"
  embedded=1
else
  _nv="$(agents_new_view "${o_sprefix:-_agents}_view_$$_$(date +%s)" "$cols" "$lines" 'agent is open in the tmux-agents popup - it returns here on detach')" || exit 4
  view="${_nv%% *}"
  ph="${_nv#* }"
fi

agents_mark_view "$view" "$pane" "$ph" "$session" "$$" \; \
  set-option -w -t "=$view:" window-size latest \; \
  set-option -t "$view" detach-on-destroy on \; \
  set-option -t "$view" @agents_action '' \; \
  set-environment -t "$view" TMUX_AGENTS_VIEW "$view"
keys=0
[ "$ro" = 0 ] && [ "${o_vkeys:-on}" = on ] &&
  view_keys "$view" "$keys_blob" && keys=1
if [ "${o_vstat:-on}" = on ]; then
  view_status "$view" "$keys"
else
  tmux set-option -t "$view" status off 2>/dev/null
fi

if [ "$embedded" -eq 0 ]; then
  if ! tmux swap-pane -d -s "$pane" -t "$ph"; then
    tmux kill-session -t "=$view" 2>/dev/null
    exit 4
  fi
fi

set --
[ "$ro" = 1 ] && set -- -r

watch=''
if [ "${o_recenter:-on}" = on ] && [ -n "${AGENTS_CLIENT:-}" ] &&
  agents_client_geo "$AGENTS_CLIENT"; then
  view_watch "$view" "$AGENTS_CLIENT" "$AGENTS_GEO" </dev/null >/dev/null 2>&1 &
  watch=$!
fi

TMUX= tmux -S "$sock" attach-session "$@" -t "=$view"
rc=$?
[ -n "$watch" ] && kill "$watch" 2>/dev/null

act="$(tmux show-options -t "$view" -qv @agents_action 2>/dev/null)"
agents_dbg "attach.sh view=$view rc=$rc act=${act:-none}"

if agents_restore_pane "$pane" "$ph" "$view" "$session"; then
  tmux kill-session -t "=$view" 2>/dev/null
fi
if [ "$prev_zoom" = 1 ] && [ -n "$prev_zoom_pane" ] &&
  agents_pane_alive "$prev_zoom_pane" &&
  [ "$(tmux display-message -p -t "$win_id" '#{window_zoomed_flag}' 2>/dev/null)" = 0 ]; then
  tmux resize-pane -Z -t "$prev_zoom_pane" 2>/dev/null
fi
[ "$rc" -ne 0 ] && exit 3

case "$act" in
jump)
  [ -n "${AGENTS_CLIENT:-}" ] || exit 12
  _tgt="$(tmux display-message -p -t "$win_id" '#{session_name}:#{window_index}' 2>/dev/null)"
  [ -n "$_tgt" ] || exit 12
  tmux switch-client -c "$AGENTS_CLIENT" -t "$_tgt" 2>/dev/null || exit 12
  agents_pane_alive "$pane" && tmux select-pane -t "$pane" 2>/dev/null
  exit 10
  ;;
close) exit 10 ;;
resize) exit 13 ;;
esac
exit 0
