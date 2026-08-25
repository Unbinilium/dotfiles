#!/bin/sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/helpers.sh"
. "$DIR/status.sh"

[ -n "${TMUX:-}" ] || { echo "tmux-agents: must run inside tmux" >&2; exit 1; }

if [ -n "${TMUX_AGENTS_VIEW:-}" ]; then
  tmux detach-client -s "=$TMUX_AGENTS_VIEW" 2>/dev/null
  exit 0
fi

TTY=/dev/tty
ESC="$(printf '\033')"
CR="$(printf '\r')"
SEP="$AGENTS_SEP"
TAB="$AGENTS_TAB"
OIFS="$IFS"
NL='
'
FULL_EVERY=5
FIT_MAX=8
STYLE_ASK="sel${TAB}#{E:@agents-style-selection}
sel${TAB}#{E:mode-style}
sel${TAB}bold,fg=cyan
chrome${TAB}#{E:@agents-style-chrome}
chrome${TAB}#{E:popup-border-style}
chrome${TAB}#{E:pane-border-style}
chrome${TAB}dim
msg${TAB}#{E:@agents-style-message}
msg${TAB}#{E:message-style}${TAB}fg
msg${TAB}fg=yellow
busy${TAB}#{E:@agents-style-busy}
busy${TAB}fg=green
wait${TAB}#{E:@agents-style-waiting}
wait${TAB}fg=yellow
idle${TAB}#{E:@agents-style-idle}
idle${TAB}fg=brightblack"
OPT_ASK="${SEP}#{@agents-patterns}${SEP}#{@agents-refresh-interval}${SEP}#{@agents-tick}${SEP}#{@agents-stamp-options}${SEP}#{@agents-return-to-dashboard}${SEP}#{@agents-preview-embed}${SEP}#{@agents-preview-dwell}${SEP}#{@agents-preview-cache}${SEP}#{@agents-capture-lines}${SEP}#{@agents-busy-regex}${SEP}#{@agents-waiting-regex}${SEP}#{@agents-cpu-busy}${SEP}#{@agents-session-prefix}${SEP}#{@agents-recenter}${SEP}#{@agents-transports}${SEP}#{@agents-remote-titles}${SEP}#{@agents-glyphs}${SEP}#{@agents-popup-border}${SEP}#{display-time}${SEP}#{popup-border-lines}${SEP}#{@agents-debug}${SEP}#{@agents-view-status}"
o_patterns='' o_interval='' o_tick='' o_stamp=''
o_return='' o_embed='' o_dwell='' o_cache='' o_capture=''
o_busy='' o_wait='' o_cpu='' o_prefix='' o_recenter=''
o_transports='' o_titles='' o_glyphs='' o_border='' o_bline='' o_dtime='' o_debug=''
o_vstat=''
STYLE_RAW='' SWEEP_ROWS='' CLIENT='' CLIENT_GEO=''
_sid="${TMUX##*,}"
case "$_sid" in '' | *[!0-9]*) _sid='' ;; *) _sid="\$$_sid" ;; esac
eval "$(tmux display-message -p "$OPT_ASK" \; \
  display-message -p '==STY==' \; display-message -p "$STYLE_ASK" \; \
  display-message -p '==CLI==' \; \
  list-clients -F "#{client_name}${TAB}#{session_id}${TAB}#{client_width} #{client_height}" \; \
  display-message -p '==SES==' \; \
  list-sessions -F "#{session_name}${TAB}#{session_attached}${TAB}#{session_created}${TAB}#{@agents_owned}${TAB}#{@agents_owner}${TAB}#{@agents_home}${TAB}#{@agents_swap}" \
  2>/dev/null |
  awk -F "$TAB" -v sid="$_sid" -v want="${AGENTS_CLIENT:-}" -v sep="$SEP" -f "$DIR/boot.awk")"

AGENTS_PATTERNS="${o_patterns:-$AGENTS_DEFAULT_PATTERNS}"
AGENTS_TRANSPORTS="${o_transports:-$AGENTS_DEFAULT_TRANSPORTS}"
AGENTS_TITLES="${o_titles:-$AGENTS_DEFAULT_TITLES}"
export AGENTS_PATTERNS AGENTS_TRANSPORTS AGENTS_TITLES
AGENTS_DEBUG="${o_debug:-}"
export AGENTS_DEBUG
prefix="${o_prefix:-_agents}"
agents_int_var "${o_interval:-2}" 2 0 3600
interval="$AGENTS_IV"
agents_int_var "${o_tick:-4}" 4 1 50
tick="$AGENTS_IV"
stamp_opt="${o_stamp:-off}"
return_dash="${o_return:-on}"
preview_embed="${o_embed:-on}"
agents_int_var "${o_dwell:-1}" 1 1 100
dwell_need="$AGENTS_IV"
agents_int_var "${o_cache:-3}" 3 1 16
pool_max="$AGENTS_IV"
recenter="${o_recenter:-on}"
vstat_rows=1
[ "${o_vstat:-on}" = off ] && vstat_rows=0

[ "$recenter" = on ] || CLIENT='' CLIENT_GEO=''
[ -n "$CLIENT_GEO" ] || CLIENT=''

if [ "$interval" -eq 0 ]; then
  deci=0
  status_every=1
else
  deci=$tick
  status_every=$(((interval * 10 + tick - 1) / tick))
fi
status_init "${o_capture:-}" "${o_busy:-}" "${o_wait:-}" "${o_cpu:-}"

AGENTS_S_SEL='' AGENTS_S_CHROME='' AGENTS_S_MSG=''
AGENTS_S_BUSY='' AGENTS_S_WAIT='' AGENTS_S_IDLE=''
export AGENTS_S_SEL AGENTS_S_CHROME AGENTS_S_MSG
export AGENTS_S_BUSY AGENTS_S_WAIT AGENTS_S_IDLE

styles_apply() {
  while IFS="$TAB" read -r _sk _sv; do
    case "$_sk" in
    sel) AGENTS_S_SEL="$_sv" ;;
    chrome) AGENTS_S_CHROME="$_sv" ;;
    msg) AGENTS_S_MSG="$_sv" ;;
    busy) AGENTS_S_BUSY="$_sv" ;;
    wait) AGENTS_S_WAIT="$_sv" ;;
    idle) AGENTS_S_IDLE="$_sv" ;;
    esac
  done <<EOF
$1
EOF
}

styles_load() {
  styles_apply "$(tmux display-message -p "$STYLE_ASK" 2>/dev/null | awk -F "$TAB" -f "$DIR/style.awk")"
}

marks_load() {
  if [ "${1:-}" = fresh ]; then
    agents_marks
    AGENTS_M_RULE="$(agents_rule_mark)"
  else
    agents_marks "${o_glyphs:-ascii}"
    AGENTS_M_RULE="$(agents_rule_mark "$(agents_popup_border "$o_border" "$o_bline")")"
  fi
  export AGENTS_M_RULE
}

marks_load

CLIENT_SEEN='' recenter_poll=0 recenter_held=0
RECENTER_HOLD=2

agents_tmp_dir
ASYNC_D="$AGENTS_TMP"
ASYNC_F="$ASYNC_D/tmux-agents-collect.$$"
CACHE_F=''
agents_kick_path && CACHE_F="$AGENTS_CACHE_PATH"
[ -n "${AGENTS_KICK:-}" ] || AGENTS_KICK="${AGENTS_KICK_PATH:-}"
apid='' scan_ticks=0
if ! (: >"$ASYNC_F.probe") 2>/dev/null; then
  ASYNC_D=/tmp
  ASYNC_F="$ASYNC_D/tmux-agents-collect.$$"
fi
rm -f "$ASYNC_F.probe" 2>/dev/null
FRAME_F="$ASYNC_D/tmux-agents-frame.$$"
rm -f "$FRAME_F" 2>/dev/null
AGENTS_FRAME_F="$FRAME_F"
export AGENTS_FRAME_F

kick_consume() {
  [ -n "${AGENTS_KICK:-}" ] || return 1
  _kn="$(date +%s)"
  _ki=0
  while [ ! -f "$AGENTS_KICK" ] && [ "$_ki" -lt 12 ]; do
    sleep 0.01 2>/dev/null || return 1
    _ki=$((_ki + 1))
  done
  [ -f "$AGENTS_KICK" ] || return 1
  _kh=''
  IFS= read -r _kh <"$AGENTS_KICK" 2>/dev/null
  case "$_kh" in '#'*) ;; *) return 1 ;; esac
  _ke="${_kh#?}"
  case "$_ke" in '' | *[!0-9]*) return 1 ;; esac
  if [ $((_kn - _ke)) -gt 5 ]; then
    rm -f "$AGENTS_KICK" "$AGENTS_KICK.err" 2>/dev/null
    return 1
  fi
  mv "$AGENTS_KICK" "$ASYNC_F" 2>/dev/null || return 1
  mv "$AGENTS_KICK.err" "$ASYNC_F.err" 2>/dev/null
  agents_dbg "kick consumed age=$((_kn - _ke))s"
  apid=kick
  scan_ticks=0
  return 0
}

cache_write() {
  [ -n "$CACHE_F" ] || return 0
  {
    printf '#%s\n' "${_now:-$(date +%s)}"
    printf '%s' "$ROWS"
  } >"$CACHE_F.part" 2>/dev/null && mv "$CACHE_F.part" "$CACHE_F" 2>/dev/null
  return 0
}

warm_load() {
  [ -n "$CACHE_F" ] && [ -f "$CACHE_F" ] || return 1
  _wh=''
  IFS= read -r _wh <"$CACHE_F" 2>/dev/null
  case "$_wh" in '#'*) ;; *) return 1 ;; esac
  _we="${_wh#?}"
  case "$_we" in '' | *[!0-9]*) return 1 ;; esac
  [ "$(($(date +%s) - _we))" -le 600 ] || return 1
  while IFS= read -r _wl; do
    [ -z "$_wl" ] && continue
    case "$_wl" in '#'*) continue ;; esac
    add_row "$_wl"
  done <"$CACHE_F"
  [ "$N" -gt 0 ] || { ROWS=''; return 1; }
  sel_restore
  notice 'refreshing...'
  agents_dbg "warm start n=$N age=$(($(date +%s) - _we))s"
  return 0
}

kick_collect() {
  [ -n "$apid" ] && return 0
  rm -f "$ASYNC_F" "$ASYNC_F.err" 2>/dev/null
  AGENTS_KICK_OUT="$ASYNC_F" sh "$DIR/collect.sh" </dev/null >/dev/null 2>&1 &
  apid=$!
  agents_dbg "scan started pid=$apid"
  scan_ticks=0
  return 0
}

[ -n "${AGENTS_KICK:-}" ] || kick_collect

saved_stty="$(stty -g <"$TTY" 2>/dev/null)"

tty_restore() {
  [ -n "$apid" ] && kill "$apid" 2>/dev/null
  rm -f "$ASYNC_F" "$ASYNC_F.part" "$ASYNC_F.err" "$FRAME_F" 2>/dev/null
  [ -n "$saved_stty" ] && stty "$saved_stty" <"$TTY" 2>/dev/null
  printf '%s[?2004l%s[?25h%s[?7h%s[0m' "$ESC" "$ESC" "$ESC" "$ESC" >"$TTY"
}

cleanup() {
  cache_write
  pool_restore_all
  tty_restore
}

trap cleanup EXIT
trap 'exit 130' INT TERM HUP
resized=0
trap 'resized=1' WINCH

raw_stty() {
  if [ "${1:-}" = block ] || [ "$deci" -eq 0 ]; then
    stty -icanon -echo -icrnl min 1 time 0 <"$TTY"
  else
    stty -icanon -echo -icrnl min 0 time "$deci" <"$TTY"
  fi
}

raw_on() {
  raw_stty
  printf '%s[?2004h%s[?25l' "$ESC" "$ESC" >"$TTY"
}

ROWS='' N=0 sel=1 msg='' msg_transient='' msg_ttl=0 msg_plain=0 ticks=0 frame=0 scanning=1
lift_next=1
agents_int_var "${o_dtime:-750}" 750 0 600000
_dt="$AGENTS_IV"
msg_ticks=1
[ "$deci" -gt 0 ] && msg_ticks=$(((_dt + deci * 100 - 1) / (deci * 100)))
[ "$msg_ticks" -lt 1 ] && msg_ticks=1

notice() {
  msg="$1" msg_transient=1 msg_ttl="$msg_ticks" msg_plain=1
  return 0
}

ask() {
  msg="$1" msg_transient='' msg_ttl=0 msg_plain=1
  return 0
}

alert() {
  msg="$1" msg_transient='' msg_ttl=0 msg_plain=0
  return 0
}

msg_clear() {
  msg='' msg_transient='' msg_ttl=0 msg_plain=0
  return 0
}

sel_pane="${AGENTS_SELECT:-}"
auto_attach="${AGENTS_ATTACH:-}"
LINES_C=24 COLS_C=80
POOL='' dwell=0
POOL_W=0 POOL_H=0
SKIP=''
fit_pane='' fit_ticks=0
SCLIST=''
NOW_TICK="$(date +%s)"
pvcap_pane='' pvcap_at=0

class_prune() {
  set -f
  set -- $SCLIST
  set +f
  [ "$#" -gt 256 ] || return 0
  for _e in "$@"; do unset "SC_$_e" "SA_$_e" "LACT_$_e" 2>/dev/null || true; done
  SCLIST=''
  return 0
}

hold_pane='' hold_pv='' hold_aw=0 hold_ah=0 hold_ti=''
LAST_SIG=''

frame_invalidate() {
  LAST_SIG=''
  rm -f "$FRAME_F" 2>/dev/null
  return 0
}

settle_pane='' settle_cap='' settle_ticks=0
SETTLE_MAX=8

settle_mark() {
  settle_pane="$1" settle_cap="$2" settle_ticks=0
  return 0
}

settle_clear() {
  settle_pane='' settle_cap='' settle_ticks=0
  return 0
}

CHROME_ROWS=1
PREV_SHARE=3

layout() {
  _lm=$((LINES_C - CHROME_ROWS))
  [ "$_lm" -lt 0 ] && _lm=0
  _keep=$((_lm / PREV_SHARE))
  [ "$_keep" -lt 3 ] && _keep=0
  _max=$((_lm - _keep))
  LIST_SHOWN=$N
  [ "$LIST_SHOWN" -gt "$_max" ] && LIST_SHOWN=$_max
  PREV_ROWS=$((_lm - LIST_SHOWN))
  LIST_FIRST=1
  if [ "$N" -gt "$LIST_SHOWN" ] && [ "$LIST_SHOWN" -gt 0 ]; then
    LIST_FIRST=$((sel - LIST_SHOWN / 2))
    [ "$LIST_FIRST" -lt 1 ] && LIST_FIRST=1
    [ $((LIST_FIRST + LIST_SHOWN - 1)) -gt "$N" ] && LIST_FIRST=$((N - LIST_SHOWN + 1))
  fi
  return 0
}

term_size() {
  _sz="$(stty size <"$TTY" 2>/dev/null)" || _sz="24 80"
  _nl="${_sz%% *}"
  _nc="${_sz##* }"
  case "$_nl$_nc" in '' | *[!0-9]*) _nl=24 _nc=80 ;; esac
  [ "$_nc" = "$COLS_C" ] && [ "$_nl" = "$LINES_C" ] && return 0
  LINES_C="$_nl"
  COLS_C="$_nc"
  frame_invalidate
  SKIP=''
  pvcap_pane=''
  return 0
}

recenter_check() {
  [ -n "$CLIENT" ] || return 0
  agents_client_geo "$CLIENT" || return 0
  _cg="$AGENTS_GEO"
  if [ "$_cg" = "$CLIENT_GEO" ]; then
    CLIENT_SEEN='' recenter_poll=0 recenter_held=0
    return 0
  fi
  recenter_poll=1
  if [ "$_cg" != "$CLIENT_SEEN" ]; then
    CLIENT_SEEN="$_cg" recenter_held=0
    return 0
  fi
  recenter_held=$((recenter_held + 1))
  [ "$recenter_held" -ge "$RECENTER_HOLD" ] || return 0
  recenter_now
  return 0
}

recenter_now() {
  [ -n "$CLIENT" ] || return 1
  sel_row_pane
  _rp="$(agents_shquote "$DIR/popup.sh")" || return 1
  _rc="$(agents_shquote "$CLIENT")" || return 1
  _rs="$(agents_shquote "$SEL_PANE")" || return 1
  agents_dbg "recenter handover client=$CLIENT${1:+ reattach}"
  tmux run-shell -b "sh $_rp $_rc $$ $_rs ${1:-}" 2>/dev/null || return 1
  exit 0
}

add_row() {
  N=$((N + 1))
  eval "ROW_$N=\$1"
  ROWS="$ROWS$1$NL"
}

statuses_resolve() {
  _srnow="${2:-}"
  _need=''
  while IFS= read -r _l; do
    [ -z "$_l" ] && continue
    case "$_l" in *"$SEP?$SEP"*) ;; *) continue ;; esac
    _need="$_need ${_l%%"$SEP"*}"
  done <<EOF
$1
EOF
  if [ -n "$_need" ]; then
    while IFS="$TAB" read -r _bp _bs; do
      [ -n "$_bp" ] && eval "ST_${_bp#%}=\$_bs"
    done <<EOF
$(agents_status_batch $_need)
EOF
  fi
  ROWS='' N=0
  while IFS= read -r _l; do
    [ -z "$_l" ] && continue
    case "$_l" in
    *"$SEP?$SEP"*)
      set -f
      IFS="$SEP"
      set -- $_l
      IFS="$OIFS"
      set +f
      eval "_rs=\${ST_${1#%}:-idle}"
      [ "$_rs" = idle ] && { agents_status_cpu "${10}"; _rs="$AGENTS_ST"; }
      if [ -n "$_srnow" ]; then
        eval "SC_${1#%}=\$_rs SA_${1#%}=\$_srnow"
        case " $SCLIST " in *" ${1#%} "*) ;; *) SCLIST="$SCLIST ${1#%}" ;; esac
      fi
      add_row "$1$SEP$2$SEP$3$SEP$_rs$SEP$5$SEP$6$SEP$7$SEP$8$SEP$9$SEP${10}$SEP${11:-}$SEP${12:-}"
      ;;
    *) add_row "$_l" ;;
    esac
  done <<EOF
$1
EOF
  for _e in $_need; do unset "ST_${_e#%}" 2>/dev/null || true; done
  return 0
}

rows_reorder() {
  _new="$1"
  _out=''
  _ids=''
  while IFS= read -r _nl; do
    [ -z "$_nl" ] && continue
    _np="${_nl%%"$SEP"*}"
    _np="${_np#%}"
    case "$_np" in '' | *[!0-9]*) continue ;; esac
    eval "NR_$_np=\$_nl"
    _ids="$_ids $_np"
  done <<EOF
$_new
EOF
  while IFS= read -r _pl; do
    [ -z "$_pl" ] && continue
    _pp="${_pl%%"$SEP"*}"
    _pp="${_pp#%}"
    case "$_pp" in '' | *[!0-9]*) continue ;; esac
    eval "_row=\${NR_$_pp:-}"
    [ -n "$_row" ] || continue
    _out="$_out$_row$NL"
    eval "NR_$_pp="
  done <<EOF
$ROWS
EOF
  for _e in $_ids; do
    eval "_row=\${NR_$_e:-}"
    [ -n "$_row" ] && _out="$_out$_row$NL"
    unset "NR_$_e" 2>/dev/null || true
  done
  printf '%s' "$_out"
}

rows_lift() {
  [ -n "$ROWS" ] || return 0
  _lf="$(printf '%s' "$ROWS" | awk -F "$SEP" '
  { r[NR] = $0; w[NR] = ($4 == "waiting") }
  END {
    for (i = 1; i <= NR; ++i) if (w[i]) print r[i]
    for (i = 1; i <= NR; ++i) if (!w[i]) print r[i]
  }')" || return 0
  [ -n "$_lf" ] && ROWS="$_lf$NL"
  return 0
}

poll_collect() {
  [ -n "$apid" ] || return 0
  [ -f "$ASYNC_F" ] || return 0
  wait "$apid" 2>/dev/null
  apid=''
  ticks=0
  scanning=0
  SKIP=''
  sel_remember
  _efirst='' _rc=0 _eline='' _el='' _ecount=0
  while IFS= read -r _el || [ -n "$_el" ]; do
    _ecount=$((_ecount + 1))
    [ "$_ecount" = 1 ] && _efirst="$_el"
    _eline="$_el"
    _el=''
  done <"$ASYNC_F.err" 2>/dev/null
  _rc="$_eline"
  case "$_rc" in '' | *[!0-9]*) _rc=0 ;; esac
  _now="$(date +%s)"
  NOW_TICK="$_now"
  class_prune
  _raw=''
  _batch=''
  while IFS="$SEP" read -r _pane _apid2 _name _ups _pcpu _cwd _ses _wix _wid _stamp _br _title; do
    [ -z "$_pane" ] && continue
    case "$_pane" in '#'*) continue ;; esac
    agents_status_stamp "$_stamp" "$_ups" "$_now"
    _st="$AGENTS_ST"
    _raw="$_raw$_pane$SEP$_apid2$SEP$_name$SEP$_st$SEP$_ups$SEP$_cwd$SEP$_ses$SEP$_wix$SEP$_wid$SEP$_pcpu$SEP$_br$SEP$_title$NL"
    [ "$stamp_opt" = on ] && _batch="$_batch${_batch:+ \\; }set-option -p -t $_pane @agent_name $_name \\; set-option -p -t $_pane @agent_uptime $_ups"
  done <"$ASYNC_F"
  rm -f "$ASYNC_F" "$ASYNC_F.err" 2>/dev/null
  _raw="$(rows_reorder "$_raw")"
  statuses_resolve "$_raw" "$_now"
  if [ "$lift_next" = 1 ]; then
    rows_lift
    lift_next=0
  fi
  if [ -n "$_batch" ]; then
    eval "tmux $_batch" 2>/dev/null
  fi
  if [ "$N" -eq 0 ] && [ "$_rc" -ne 0 ]; then
    alert "scan failed: $_efirst"
  fi
  agents_dbg "scan landed n=$N rc=$_rc"
  cache_write
  sel_restore
  return 0
}

collect_light() {
  _panes="$(tmux list-panes -a -F "#{pane_id}${TAB}.#{@agent_status}${TAB}#{session_name}${TAB}#{window_index}${TAB}#{window_id}${TAB}#{?@agents_owned,1,0}${TAB}#{window_activity}${TAB}#{?#{==:#{pane_title},#{host}},,#{pane_title}}" 2>/dev/null)" || return 0
  _now="$(date +%s)"
  NOW_TICK="$_now"
  _oldN=$N
  sel_remember
  _live='' _ncap=0 _nre=0
  while IFS="$TAB" read -r _pane _stamp _ses _wix _wid _own _act _title; do
    [ -z "$_pane" ] && continue
    _idn="${_pane#%}"
    case " $_live " in *" $_idn "*) continue ;; esac
    _live="$_live $_idn"
    _stamp="${_stamp#.}"
    while :; do
      case "$_title" in
      *"$TAB"*) _title="${_title%%"$TAB"*} ${_title#*"$TAB"}" ;;
      *"$SEP"*) _title="${_title%%"$SEP"*} ${_title#*"$SEP"}" ;;
      *) break ;;
      esac
    done
    eval "LSTAMP_$_idn=\$_stamp LACT_$_idn=\$_act LTITLE_$_idn=\$_title"
    if [ "$_own" != 1 ]; then
      eval "LSES_$_idn=\$_ses LWIX_$_idn=\$_wix LWID_$_idn=\$_wid"
    fi
  done <<EOF
$_panes
EOF
  _raw=''
  while IFS= read -r _row; do
    [ -z "$_row" ] && continue
    set -f
    IFS="$SEP"
    set -- $_row
    IFS="$OIFS"
    set +f
    _idn="${1#%}"
    case " $_live " in *" $_idn "*) ;; *) continue ;; esac
    eval "_stamp=\${LSTAMP_$_idn:-} _ses=\${LSES_$_idn:-\$7} _wix=\${LWIX_$_idn:-\$8} _wid=\${LWID_$_idn:-\$9} _lti=\${LTITLE_$_idn:-}"
    _ups=$(($5 + interval))
    agents_status_stamp "$_stamp" "$_ups" "$_now"
    _st="$AGENTS_ST"
    if [ "$_st" = '?' ]; then
      eval "_pa=\${LACT_$_idn:-} _sa=\${SA_$_idn:-} _sc=\${SC_$_idn:-}"
      case "$_pa" in '' | *[!0-9]*) _pa='' ;; esac
      case "$_sa" in '' | *[!0-9]*) _sa='' ;; esac
      if [ -n "$_pa" ] && [ -n "$_sa" ] && [ -n "$_sc" ] && [ "$_pa" -lt "$_sa" ]; then
        _st="$_sc"
        _nre=$((_nre + 1))
      else
        _ncap=$((_ncap + 1))
      fi
    fi
    _raw="$_raw$1$SEP$2$SEP$3$SEP$_st$SEP$_ups$SEP$6$SEP$_ses$SEP$_wix$SEP$_wid$SEP${10}$SEP${11:-}$SEP$_lti$NL"
  done <<EOF
$ROWS
EOF
  statuses_resolve "$_raw" "$_now"
  agents_dbg "light n=$N cap=$_ncap reuse=$_nre"
  for _e in $_live; do unset "LSTAMP_$_e" "LSES_$_e" "LWIX_$_e" "LWID_$_e" "LTITLE_$_e" 2>/dev/null || true; done
  sel_restore
  [ "$N" -lt "$_oldN" ] && kick_collect
  return 0
}

clamp() {
  [ "$sel" -gt "$N" ] && sel=$N
  [ "$sel" -lt 1 ] && sel=1
}

wrap_move() { # wrap_move <signed step count> - j/k moves wrap around the ends
  [ "$N" -gt 0 ] || { sel=1; return 0; }
  sel=$(((sel - 1 + $1) % N))
  [ "$sel" -lt 0 ] && sel=$((sel + N))
  sel=$((sel + 1))
  return 0
}

sel_remember() {
  sel_row_pane
  [ -n "$SEL_PANE" ] && sel_pane="$SEL_PANE"
  return 0
}

sel_restore() {
  [ -n "$sel_pane" ] || { clamp; return 0; }
  _i=0
  while IFS= read -r _l; do
    [ -z "$_l" ] && continue
    _i=$((_i + 1))
    case "$_l" in "$sel_pane$SEP"*)
      sel=$_i
      clamp
      return 0
      ;;
    esac
  done <<EOF
$ROWS
EOF
  clamp
  return 0
}

sel_row_pane() {
  eval "_r=\${ROW_$sel:-}"
  SEL_PANE="${_r%%"$SEP"*}"
  _t="${_r#*"$SEP"}"
  _t="${_t#*"$SEP"}"
  _t="${_t#*"$SEP"}"
  SEL_ST="${_t%%"$SEP"*}"
  return 0
}

pool_get() {
  _pn="${1#%}"
  eval "_pv=\${PV_$_pn:-} _pph=\${PH_$_pn:-} _phome=\${PHOME_$_pn:-}"
  [ -n "$_pv" ]
}

list_drop() {
  LIST_D=''
  for _ld in $2; do [ "$_ld" = "$1" ] || LIST_D="$LIST_D $_ld"; done
  return 0
}

pool_forget() {
  list_drop "$1" "$POOL"
  POOL="$LIST_D"
  unset "PV_$1" "PH_$1" "PHOME_$1" 2>/dev/null || true
  return 0
}

pool_touch() {
  list_drop "$1" "$POOL"
  POOL="$LIST_D $1"
  return 0
}

pool_restore() {
  eval "_rv=\${PV_$1:-} _rph=\${PH_$1:-} _rh=\${PHOME_$1:-}"
  pool_forget "$1"
  [ -n "$_rv" ] || return 0
  if agents_restore_pane "%$1" "$_rph" "$_rv" "$_rh"; then
    tmux kill-session -t "=$_rv" 2>/dev/null
  fi
  settle_mark "%$1" "$(tmux capture-pane -p -e -t "%$1" 2>/dev/null)"
  return 0
}

pool_restore_all() {
  for _e in ${POOL:-}; do pool_restore "$_e"; done
  POOL=''
  return 0
}

pool_refit() {
  [ -n "$POOL" ] || return 0
  layout
  _vh=$((LINES_C - vstat_rows))
  [ "$COLS_C" = "$POOL_W" ] && [ "$_vh" = "$POOL_H" ] && return 0
  if [ "$PREV_ROWS" -lt 3 ]; then
    pool_restore_all
    return 0
  fi
  _cmd=''
  for _e in $POOL; do
    eval "_v=\${PV_$_e:-}"
    [ -n "$_v" ] || continue
    _cmd="$_cmd${_cmd:+ \\; }resize-window -t \"=$_v:\" -x $COLS_C -y $_vh"
  done
  [ -n "$_cmd" ] || return 0
  sel_row_pane
  _sp=''
  [ -n "$SEL_PANE" ] && case " $POOL " in
  *" ${SEL_PANE#%} "*) _sp="$SEL_PANE" ;;
  esac
  if [ -n "$_sp" ]; then
    settle_mark "$_sp" "$(eval "tmux $_cmd \\; capture-pane -p -e -t '$_sp'" 2>/dev/null)"
  else
    eval "tmux $_cmd" 2>/dev/null
  fi
  POOL_W="$COLS_C" POOL_H="$_vh"
  return 0
}

POOL_HOLD=2
pool_seen_w=0 pool_seen_h=0 pool_held=0

pool_follow() {
  [ -n "$POOL" ] || return 0
  _vh=$((LINES_C - vstat_rows))
  if [ "$COLS_C" = "$POOL_W" ] && [ "$_vh" = "$POOL_H" ]; then
    pool_held=0
    return 0
  fi
  if [ "$COLS_C" != "$pool_seen_w" ] || [ "$_vh" != "$pool_seen_h" ]; then
    pool_seen_w="$COLS_C" pool_seen_h="$_vh" pool_held=0
    return 0
  fi
  pool_held=$((pool_held + 1))
  [ "$pool_held" -ge "$POOL_HOLD" ] || return 0
  pool_held=0
  pool_refit
  return 0
}

pool_trim() {
  while :; do
    set -f
    set -- $POOL
    set +f
    [ "$#" -gt "$pool_max" ] || break
    pool_restore "$1"
  done
  return 0
}

pool_sync() {
  [ -n "$POOL" ] || return 0
  _alive="$(tmux list-panes -a -F "#{pane_id}${TAB}#{session_name}" 2>/dev/null)"
  for _e in $POOL; do
    eval "_sv=\${PV_$_e:-}"
    [ -n "$_sv" ] || { pool_forget "$_e"; continue; }
    case "$_alive" in
    *"%$_e$TAB$_sv$NL"* | *"%$_e$TAB$_sv") ;;
    *) pool_forget "$_e" ;;
    esac
  done
  return 0
}

embed_now() {
  [ "$preview_embed" = on ] || return 0
  [ "$N" -gt 0 ] || return 0
  sel_row_pane
  _p="$SEL_PANE"
  [ -n "$_p" ] || return 0
  if pool_get "$_p"; then
    pool_touch "${_p#%}"
    return 0
  fi
  _pn="${_p#%}"
  case " $SKIP " in *" $_pn "*) return 0 ;; esac
  pool_refit
  layout
  [ "$PREV_ROWS" -ge 3 ] || return 0
  eval "_row=\${ROW_$sel:-}"
  set -f
  IFS="$SEP"
  set -- $_row
  IFS="$OIFS"
  set +f
  _ses="$7" _wid="$9"
  _geo="$(tmux display-message -p -t "$_p" '#{pane_id} #{pane_width} #{?@agents_owned,1,0} #{?window_zoomed_flag,1,0}' 2>/dev/null)"
  set -f
  set -- $_geo
  set +f
  SKIP="$SKIP $_pn"
  [ "$#" -ge 4 ] || return 0
  [ "$1" = "$_p" ] || return 0
  [ "$3" = 1 ] && return 0
  [ "$4" = 1 ] && return 0
  [ "$2" = "$COLS_C" ] && return 0
  _vh=$((LINES_C - vstat_rows))
  _nv="$(agents_new_view "${prefix}_prev_$$_$_pn" "$COLS_C" "$_vh" 'agent is open in the tmux-agents popup - it returns here shortly')" || return 0
  _view="${_nv%% *}"
  _ph="${_nv#* }"
  [ -n "$_ph" ] || { tmux kill-session -t "=$_view" 2>/dev/null; return 0; }
  agents_mark_view "$_view" "$_p" "$_ph" "$_ses" "$$"
  if _sc="$(tmux swap-pane -d -s "$_p" -t "$_ph" \; capture-pane -p -e -t "$_p" 2>/dev/null)"; then
    eval "PV_$_pn=\$_view PH_$_pn=\$_ph PHOME_$_pn=\$_ses"
    POOL_W="$COLS_C" POOL_H="$_vh"
    pool_touch "$_pn"
    list_drop "$_pn" "$SKIP"
    SKIP="$LIST_D"
    pool_trim
    settle_mark "$_p" "$_sc"
  else
    tmux kill-session -t "=$_view" 2>/dev/null
  fi
  return 0
}

preview_can_fit() {
  [ "$preview_embed" = on ] || return 1
  [ "$deci" -gt 0 ] || return 1
  case " $SKIP " in *" ${1#%} "*) return 1 ;; esac
  return 0
}

preview_hold() {
  hold_pane="$1" hold_pv="$2" hold_aw="$3" hold_ah="$4" hold_ti="$5"
  return 0
}

render() {
  layout
  _avail="$PREV_ROWS"
  _pv='' _aw=0 _ah=0 _exact=0 _fit=0 _held=0 _ti=''
  if [ "$N" -gt 0 ] && [ "$_avail" -ge 3 ]; then
    sel_row_pane
    _pvpane="$SEL_PANE"
    [ "$_pvpane" = "$fit_pane" ] || { fit_pane="$_pvpane" fit_ticks=0; }
    _cap=''
    _do_cap=1
    if [ "$_pvpane" = "$pvcap_pane" ] && [ "${SEL_ST:-}" != busy ] && [ "$_pvpane" != "$settle_pane" ] && [ "$_pvpane" = "$hold_pane" ]; then
      eval "_pa=\${LACT_${_pvpane#%}:-}"
      case "$_pa" in
      '' | *[!0-9]*) ;;
      *) [ "$_pa" -lt "$((pvcap_at - 2))" ] && _do_cap=0 ;;
      esac
    fi
    if [ "$_do_cap" = 1 ]; then
      _cap="$(agents_capture_meta "$_pvpane")"
      pvcap_pane="$_pvpane"
      pvcap_at="$NOW_TICK"
    fi
    case "$_cap" in
    *"$NL"*)
      _geo="${_cap%%"$NL"*}"
      _rest="${_cap#*"$NL"}"
      case "$_rest" in
      *"$NL"*) _ti="${_rest%%"$NL"*}" _rest="${_rest#*"$NL"}" ;;
      *) _ti="$_rest" _rest='' ;;
      esac
      _aw="${_geo%% *}"
      _ah="${_geo##* }"
      case "$_aw" in '' | *[!0-9]*) _aw=0 ;; esac
      case "$_ah" in '' | *[!0-9]*) _ah=0 ;; esac
      [ "$_aw" -gt 0 ] && _pv="$_rest"
      ;;
    *) _aw=0 ;;
    esac
    if [ "$_aw" -eq 0 ]; then
      _held=1
    elif [ "$_pvpane" = "$settle_pane" ]; then
      if [ "$_pv" = "$settle_cap" ] && [ "$settle_ticks" -lt "$SETTLE_MAX" ]; then
        settle_ticks=$((settle_ticks + 1))
        _held=1
      else
        settle_clear
      fi
    fi
    if [ "$_held" -eq 0 ]; then
      preview_hold "$_pvpane" "$_pv" "$_aw" "$_ah" "$_ti"
    elif [ "$_pvpane" = "$hold_pane" ]; then
      _pv="$hold_pv" _aw="$hold_aw" _ah="$hold_ah" _ti="$hold_ti"
    else
      _pv='' _aw=0 _ah=0 _ti=''
    fi
    [ "$_aw" -gt 0 ] && [ "$_aw" -eq "$COLS_C" ] && { _exact=1; fit_ticks=0; }
    if [ "$_exact" -eq 0 ] && preview_can_fit "$_pvpane" && [ "$fit_ticks" -lt "$FIT_MAX" ]; then
      _fit=1
      fit_ticks=$((fit_ticks + 1))
    fi
  fi

  _sig="$sel|$COLS_C|$LINES_C|$LIST_FIRST|$LIST_SHOWN|$msg|$msg_plain|$_exact|$_aw|$_ah|$_avail|$_fit|$_ti|$ROWS|$_pv"
  [ "$_sig" = "$LAST_SIG" ] && return 0
  LAST_SIG="$_sig"
  AGENTS_MSG="$msg"
  AGENTS_PV_TITLE="$_ti"
  export AGENTS_MSG AGENTS_PV_TITLE
  {
    printf '%s\n' "$ROWS"
    printf '==PV==\n'
    [ -n "$_pv" ] && printf '%s\n' "$_pv"
  } | awk -F "$SEP" -v sel="$sel" -v cols="$COLS_C" \
    -v plain="${msg_plain:-0}" \
    -v exact="$_exact" -v aw="$_aw" -v ah="$_ah" -v avail="$_avail" \
    -v fitting="$_fit" -v first="$LIST_FIRST" -v shown="$LIST_SHOWN" \
    -f "$DIR/render.awk" >"$TTY"
}

read_key() {
  KEY=timeout
  [ "${1:-}" = block ] && raw_stty block
  _b="$(dd bs=1 count=1 2>/dev/null <"$TTY")"
  if [ "$_b" = "$ESC" ]; then
    _seq='' _pst=0
    stty -icanon -echo -icrnl min 0 time 1 <"$TTY"
    while :; do
      _c="$(dd bs=512 count=1 2>/dev/null <"$TTY" | tr -d '\0')"
      [ -z "$_c" ] && break
      [ "${#_seq}" -lt 512 ] && _seq="$_seq$_c"
      case "$_seq" in '[200~'*) _pst=1 ;; esac
      case "$_c" in *'[201~'*) _pst=0 ;; esac
      [ "$_pst" = 1 ] && continue
      [ "${#_c}" -lt 512 ] && break
    done
    raw_stty "${1:-}"
    _up=0 _dn=0 _pu=0 _pd=0 _hm=0 _en=0 _rest="$_seq"
    while [ -n "$_rest" ]; do
      case "$_rest" in
      '[A'* | 'OA'*) _up=$((_up + 1)) _rest="${_rest#??}" ;;
      '[B'* | 'OB'*) _dn=$((_dn + 1)) _rest="${_rest#??}" ;;
      '[5~'*) _pu=$((_pu + 1)) _rest="${_rest#???}" ;;
      '[6~'*) _pd=$((_pd + 1)) _rest="${_rest#???}" ;;
      '[1~'* | '[7~'*) _hm=1 _rest="${_rest#???}" ;;
      '[4~'* | '[8~'*) _en=1 _rest="${_rest#???}" ;;
      '[H'* | 'OH'*) _hm=1 _rest="${_rest#??}" ;;
      '[F'* | 'OF'*) _en=1 _rest="${_rest#??}" ;;
      *) _rest="${_rest#?}" ;;
      esac
    done
    if [ "$_en" = 1 ]; then KEY=end
    elif [ "$_hm" = 1 ]; then KEY=home
    elif [ "$_pd" -gt 0 ] && [ "$_pd" -ge "$_pu" ]; then KEY="pgdn:$_pd"
    elif [ "$_pu" -gt 0 ]; then KEY="pgup:$_pu"
    elif [ "$_up" -gt 0 ] && [ "$_up" -ge "$_dn" ]; then KEY="up:$_up"
    elif [ "$_dn" -gt 0 ]; then KEY="down:$_dn"
    elif [ -z "$_seq" ]; then KEY=esc
    else KEY=other
    fi
    return 0
  fi
  [ "${1:-}" = block ] && raw_stty
  case "$_b" in
  '') KEY=timeout ;;
  "$CR") KEY=enter ;;
  j) KEY=down:1 ;;
  k) KEY=up:1 ;;
  [0-9] | q | r | x | y | n) KEY="$_b" ;;
  *) KEY=other ;;
  esac
}

do_attach() {
  [ "$N" -eq 0 ] && return 0
  eval "_row=\${ROW_$sel:-}"
  [ -z "$_row" ] && return 0
  set -f
  IFS="$SEP"
  set -- $_row
  IFS="$OIFS"
  set +f
  _pane="$1" _name="$3" _ses="$7" _wid="$9"
  _apv='' _aph=''
  pool_get "$_pane" && { _apv="$_pv" _aph="$_pph"; }
  tty_restore
  apid=''
  agents_dbg "attach $_pane $_name${_apv:+ embedded}"
  _err="$(AGENTS_NAME="$_name" AGENTS_CLIENT="$CLIENT" sh "$DIR/attach.sh" "$_pane" "$_ses" "$_wid" "$COLS_C" "$LINES_C" "$_apv" "$_aph" 2>&1 1>"$TTY")"
  _rc=$?
  agents_dbg "attach rc=$_rc"
  [ -n "$_apv" ] && pool_restore "${_pane#%}"
  dwell=0
  fit_pane='' fit_ticks=0
  pvcap_pane=''
  raw_on
  term_size
  frame_invalidate
  if [ "$_rc" -eq 10 ] || [ "$return_dash" != on ]; then
    exit 0
  fi
  msg_clear
  [ "$_rc" -eq 3 ] && alert 'that agent is gone'
  [ "$_rc" -eq 4 ] && alert "view failed: $(printf '%s' "$_err" | sed -n 1p)"
  [ "$_rc" -eq 5 ] && alert 'already being viewed in another popup'
  [ "$_rc" -eq 12 ] && alert 'cannot jump: client unknown'
  agents_sweep
  kick_collect
  return 0
}

do_kill() {
  [ "$N" -eq 0 ] && return 0
  eval "_row=\${ROW_$sel:-}"
  [ -z "$_row" ] && return 0
  set -f
  IFS="$SEP"
  set -- $_row
  IFS="$OIFS"
  set +f
  _pane="$1" _kpid="$2" _name="$3" _cwd="$6"
  case "$_cwd" in
  @*) _far="${_cwd#@}" ;;
  *) _far='' ;;
  esac
  dwell=0
  if [ -n "$_far" ]; then
    ask "close the connection to $_far? $_name keeps running. y/N"
  else
    ask "kill $_name (pid $_kpid)? y/N"
  fi
  render
  read_key block
  _k="$KEY"
  if [ "$_k" = y ]; then
    pool_get "$_pane" && pool_restore "${_pane#%}"
    if ps -p "$_kpid" -o args= 2>/dev/null | grep -qF -- "${_far:-$_name}"; then
      if [ -n "$_far" ]; then
        kill -TERM "$_kpid" 2>/dev/null && notice "closed the connection to $_far" || alert 'kill failed'
      else
        kill -TERM "$_kpid" 2>/dev/null && notice "sent SIGTERM to $_name" || alert 'kill failed'
      fi
    elif [ -n "$_far" ]; then
      alert 'that pid is no longer the connection'
    else
      alert 'that pid is no longer the agent'
    fi
    kick_collect
  else
    notice 'kill cancelled'
  fi
  return 0
}

styles_apply "$(printf '%s\n' "$STYLE_RAW" | awk -F "$TAB" -f "$DIR/style.awk")"
agents_dbg "boot client=${CLIENT:-none} interval=$interval tick=$tick embed=$preview_embed"
agents_sweep "$SWEEP_ROWS"
term_size
if [ -n "${AGENTS_KICK:-}" ]; then kick_consume || kick_collect; fi
_i=0 _iw=16
[ "$deci" -eq 0 ] && _iw=30
warm_load && _iw=0
while [ -n "$apid" ] && [ ! -f "$ASYNC_F" ] && [ "$_i" -lt "$_iw" ]; do
  if [ "$_i" -lt 12 ]; then
    sleep 0.01 2>/dev/null || _i="$_iw"
  else
    sleep 0.05 2>/dev/null || _i="$_iw"
  fi
  _i=$((_i + 1))
done
raw_on
while :; do
  [ "$resized" = 1 ] && { resized=0; term_size; recenter_poll=1; }
  poll_collect
  if [ -n "$auto_attach" ] && [ "$scanning" = 0 ]; then
    _aa="$auto_attach" auto_attach=''
    sel_pane="$_aa"
    sel_restore
    sel_row_pane
    [ "$SEL_PANE" = "$_aa" ] && do_attach
  fi
  [ -n "$auto_attach" ] || render
  read_key
  _key="$KEY"
  _cnt="${_key#*:}"
  case "$_key" in *:*) _key="${_key%%:*}" ;; *) _cnt=1 ;; esac
  case "$_key" in
  timeout)
    frame=$((frame + 1))
    if [ -n "$msg_transient" ] && [ "$msg_ttl" -gt 0 ]; then
      msg_ttl=$((msg_ttl - 1))
      [ "$msg_ttl" -eq 0 ] && msg_clear
    fi
    if [ -n "$apid" ]; then
      scan_ticks=$((scan_ticks + 1))
      if [ "$scan_ticks" -gt $((status_every * 30)) ]; then
        kill "$apid" 2>/dev/null
        apid=''
        scanning=0
        agents_dbg "scan timed out"
        alert 'scan timed out'
      fi
    fi
    if [ $((frame % status_every)) -eq 0 ]; then
      ticks=$((ticks + 1))
      term_size
      pool_sync
      if [ -z "$apid" ] && [ -n "${AGENTS_KICK:-}" ] &&
        [ -f "$AGENTS_KICK" ] && kick_consume; then
        :
      elif [ "$ticks" -ge "$FULL_EVERY" ]; then kick_collect; else collect_light; fi
    fi
    pool_follow
    if [ "$recenter_poll" = 1 ] || [ $((frame % status_every)) -eq 0 ]; then
      recenter_check
    fi
    if [ "$preview_embed" = on ] && [ "$N" -gt 0 ]; then
      sel_row_pane
      _selpane="$SEL_PANE"
      if [ -n "$_selpane" ] && ! pool_get "$_selpane"; then
        dwell=$((dwell + 1))
        if [ "$dwell" -ge "$dwell_need" ]; then
          embed_now
          dwell=0
        fi
      else
        dwell=0
      fi
    fi
    ;;
  up)
    dwell=0
    wrap_move "-$_cnt"
    msg_clear
    ;;
  down)
    dwell=0
    wrap_move "$_cnt"
    msg_clear
    ;;
  pgup | pgdn)
    dwell=0
    _step="$LIST_SHOWN"
    [ "$_step" -lt 1 ] && _step=1
    if [ "$_key" = pgup ]; then sel=$((sel - _step * _cnt)); else sel=$((sel + _step * _cnt)); fi
    clamp
    msg_clear
    ;;
  home)
    dwell=0
    sel=1
    clamp
    msg_clear
    ;;
  end)
    dwell=0
    sel=$N
    clamp
    msg_clear
    ;;
  enter) do_attach ;;
  r)
    term_size
    styles_load
    marks_load fresh
    pvcap_pane=''
    frame_invalidate
    notice 'refreshing...'
    lift_next=1
    kick_collect
    ;;
  x) do_kill ;;
  q | esc) exit 0 ;;
  [1-9])
    if [ "$_key" -le "$N" ]; then
      sel="$_key"
      do_attach
    fi
    ;;
  esac
done
