#!/bin/sh

AGENTS_SEPS_="$(printf '\037\t')"
AGENTS_SEP="${AGENTS_SEPS_%?}"
AGENTS_TAB="${AGENTS_SEPS_#?}"
unset AGENTS_SEPS_
AGENTS_DEFAULT_PATTERNS='claude pi codex aider opencode gemini amp goose cursor-agent copilot'
AGENTS_DEFAULT_TRANSPORTS='ssh slogin autossh mosh-client mosh et telnet rlogin docker podman kubectl lxc incus distrobox-enter toolbox nsenter machinectl'
AGENTS_DEFAULT_TITLES='pi=(^|[^a-z0-9])(π|pi)([^a-z0-9]|$)'

agents_opt() { # agents_opt <@option> <default>
  _v="$(tmux show-option -gqv "$1" 2>/dev/null)"
  printf '%s' "${_v:-$2}"
}

agents_opt_flavour() { # agents_opt_flavour <answer led by AGENTS_SEP>
  AGENTS_OS="$AGENTS_SEP" AGENTS_OV="$1"
  case "$1" in
  "$AGENTS_SEP"*) AGENTS_OV="${1#"$AGENTS_SEP"}" ;;
  '\037'*) AGENTS_OS='\037' AGENTS_OV="${1#\\037}" ;;
  esac
}

agents_dbg() { # agents_dbg <words...>
  [ -n "${AGENTS_DEBUG:-}" ] || return 0
  printf '%s %s %s\n' "$(date +%s)" "$$" "$*" >>"$AGENTS_DEBUG" 2>/dev/null || :
  return 0
}

agents_int_var() { # agents_int_var <value> <default> [min] [max] -> AGENTS_IV
  AGENTS_IV="$1"
  case "$AGENTS_IV" in '' | *[!0-9]*) AGENTS_IV="$2" ;; esac
  while :; do
    case "$AGENTS_IV" in
    0) break ;;
    0*) AGENTS_IV="${AGENTS_IV#0}" ;;
    *) break ;;
    esac
  done
  [ -n "$AGENTS_IV" ] || AGENTS_IV=0
  [ -n "${3:-}" ] && [ "$AGENTS_IV" -lt "$3" ] && AGENTS_IV="$3"
  [ -n "${4:-}" ] && [ "$AGENTS_IV" -gt "$4" ] && AGENTS_IV="$4"
  return 0
}

agents_marks() { # agents_marks [ascii|dot|unicode] (default: the option)
  _mk="${1:-}"
  [ -n "$_mk" ] || _mk="$(agents_opt @agents-glyphs ascii)"
  case "$_mk" in
  unicode)
    AGENTS_M_BUSY='●' AGENTS_M_WAIT='◆' AGENTS_M_IDLE='○'
    AGENTS_M_ELL='…'
    AGENTS_M_AHEAD='↑' AGENTS_M_BEHIND='↓'
    ;;
  dot)
    AGENTS_M_BUSY='•' AGENTS_M_WAIT='‣' AGENTS_M_IDLE='◦'
    AGENTS_M_ELL='…'
    AGENTS_M_AHEAD='↑' AGENTS_M_BEHIND='↓'
    ;;
  *)
    AGENTS_M_BUSY='*' AGENTS_M_WAIT='!' AGENTS_M_IDLE='-'
    AGENTS_M_ELL='...'
    AGENTS_M_AHEAD='+' AGENTS_M_BEHIND='-'
    ;;
  esac
  AGENTS_M_SEP='·'
  export AGENTS_M_BUSY AGENTS_M_WAIT AGENTS_M_IDLE AGENTS_M_ELL AGENTS_M_SEP AGENTS_M_AHEAD AGENTS_M_BEHIND
}

agents_rule_mark() { # agents_rule_mark [<border>]
  case "${1:-$(agents_popup_border)}" in
  double) printf '%s' '═' ;;
  heavy) printf '%s' '━' ;;
  simple) printf '%s' '-' ;;
  *) printf '%s' '─' ;;
  esac
}

agents_client_geo() { # agents_client_geo <client name> -> AGENTS_GEO
  AGENTS_GEO=''
  while IFS= read -r _cgl; do
    case "$_cgl" in
    "$1$AGENTS_TAB"*)
      AGENTS_GEO="${_cgl#*"$AGENTS_TAB"}"
      break
      ;;
    esac
  done <<EOF
$(tmux list-clients -F "#{client_name}${AGENTS_TAB}#{client_width} #{client_height}" 2>/dev/null)
EOF
  [ -n "$AGENTS_GEO" ]
}

agents_tmp_dir() { # -> AGENTS_TMP
  [ -n "${AGENTS_TMP:-}" ] && return 0
  AGENTS_TMP="${XDG_RUNTIME_DIR:-${TMPDIR:-}}"
  if [ -z "$AGENTS_TMP" ]; then
    AGENTS_TMP="/tmp/tmux-agents-$(id -u 2>/dev/null || echo 0)"
    mkdir -m 700 "$AGENTS_TMP" 2>/dev/null
    chmod 700 "$AGENTS_TMP" 2>/dev/null || AGENTS_TMP=/tmp
  fi
  export AGENTS_TMP
  return 0
}

agents_kick_path() { # -> AGENTS_KICK_PATH, AGENTS_CACHE_PATH
  AGENTS_KICK_PATH=''
  case "${TMUX:-}" in *,*,*) ;; *) return 1 ;; esac
  _kpp="${TMUX#*,}"
  _kpp="${_kpp%%,*}"
  case "$_kpp" in '' | *[!0-9]*) return 1 ;; esac
  agents_tmp_dir
  AGENTS_KICK_PATH="$AGENTS_TMP/tmux-agents-kick.$_kpp"
  AGENTS_CACHE_PATH="$AGENTS_TMP/tmux-agents-cache.$_kpp"
}

agents_vnum() {
  set -- $(tmux -V 2>/dev/null | sed 's/[^0-9.]/ /g')
  _vv="${1:-0}"
  case "$_vv" in *.*) ;; *) _vv="$_vv.0" ;; esac
  _vmaj="${_vv%%.*}"
  _vmin="${_vv#*.}"
  _vmin="${_vmin%%.*}"
  case "$_vmaj$_vmin" in *[!0-9]* | '') _vmaj=0 _vmin=0 ;; esac
  printf '%s' "$((_vmaj * 100 + _vmin))"
}

agents_popup_border() { # agents_popup_border [<@agents-popup-border> <popup-border-lines>]
  if [ "$#" -ge 2 ]; then
    _pb="$1" _pbl="$2"
  else
    _pb="$(agents_opt @agents-popup-border '')"
    _pbl=''
    [ -n "$_pb" ] || _pbl="$(tmux show-options -gwqv popup-border-lines 2>/dev/null)"
  fi
  if [ -z "$_pb" ]; then
    _pb="$_pbl"
    [ -n "$_pb" ] && [ "$_pb" != single ] || _pb=rounded
  fi
  case "$_pb" in
  single | double | heavy | simple | rounded | padded | none) ;;
  *) _pb=rounded ;;
  esac
  printf '%s' "$_pb"
}

agents_popup_size() { # agents_popup_size <value> <default>
  case "${1%\%}" in
  '' | *[!0-9]*) printf '%s' "$2" ;;
  *) printf '%s' "$1" ;;
  esac
}

agents_popup_args() { # -> display-popup flags, quoted for `eval set -- ...`
  _pw="$(agents_popup_size "$(agents_opt @agents-popup-width 90%)" 90%)"
  _ph="$(agents_popup_size "$(agents_opt @agents-popup-height 90%)" 90%)"
  printf '%s' "-E -w '$_pw' -h '$_ph'"
  [ "$(agents_vnum)" -ge 303 ] && printf ' %s' "-b '$(agents_popup_border)'" "-T ' agents '"
  printf ' %s' \
    "-x '#{e|/:#{e|-:#{client_width},#{popup_width}},2}'" \
    "-y '#{e|/:#{e|+:#{client_height},#{popup_height}},2}'"
  printf '\n'
}

agents_fmt_literal() { # agents_fmt_literal <value>
  case "$1" in
  *'#'*) printf '%s' "$1" | sed 's/#/##/g' ;;
  *) printf '%s' "$1" ;;
  esac
}

agents_shquote() { # agents_shquote <value>
  case "$1" in *\'*) return 1 ;; esac
  case "$1" in
  *'#'*) printf "'%s'" "$(printf '%s' "$1" | sed 's/#/##/g')" ;;
  *) printf "'%s'" "$1" ;;
  esac
}

agents_rows() { # agents_rows <tmux args...> (format must use AGENTS_TAB)
  tmux "$@" 2>/dev/null | tr "$AGENTS_TAB" "$AGENTS_SEP"
}

agents_pane_alive() { [ -n "$(tmux display-message -p -t "$1" '#{pane_id}' 2>/dev/null)" ]; }
agents_pane_session() { tmux display-message -p -t "$1" '#{session_name}' 2>/dev/null; }

agents_capture_meta() { # agents_capture_meta <pane_id>
    tmux display-message -p -t "$1" '#{pane_width} #{pane_height}' \; capture-pane -p -e -t "$1" 2>/dev/null
}

agents_mark_view() { # agents_mark_view <session> <agent_pane> <placeholder> <home_session> <owner_pid> [\; more...]
  _mvs="$1" _mvsw="$2 $3" _mvh="$4" _mvo="$5"
  shift 5
  tmux set-option -t "$_mvs" @agents_owned 1 \; \
    set-option -t "$_mvs" @agents_swap "$_mvsw" \; \
    set-option -t "$_mvs" @agents_home "$_mvh" \; \
    set-option -t "$_mvs" @agents_owner "$_mvo" "$@" 2>/dev/null
}

agents_view_session() { # agents_view_session <name> <cols> <rows> <note> -> pane id
  tmux new-session -d -s "$1" -x "$2" -y "$3" \
    sh -c 'printf "\n  \033[2m%s\033[0m\n" "$1"; while :; do sleep 3600; done' placeholder "$4" \; \
    set-option -t "=$1:" destroy-unattached off \; \
    set-option -w -t "=$1:" pane-border-status off \; \
    resize-window -x "$2" -y "$3" -t "=$1:" \; \
    display-message -p -t "=$1:" '#{pane_id}' 2>/dev/null
}

agents_new_view() { # agents_new_view <name_var_is_echoed> <cols> <rows> <note>
  _vn="$1" _vc="$2" _vr="$3" _vm="$4"
  tmux kill-session -t "=$_vn" 2>/dev/null
  _vp="$(agents_view_session "$_vn" "$_vc" "$_vr" "$_vm")"
  if [ -z "$_vp" ]; then
    tmux kill-session -t "=$_vn" 2>/dev/null # half-built, and ours to clear
    _vn="${_vn}_$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -dc 0-9)"
    tmux kill-session -t "=$_vn" 2>/dev/null
    _vp="$(agents_view_session "$_vn" "$_vc" "$_vr" "$_vm")"
    [ -n "$_vp" ] || { tmux kill-session -t "=$_vn" 2>/dev/null; return 1; }
  fi
  printf '%s %s' "$_vn" "$_vp"
  return 0
}

agents_restore_pane() { # agents_restore_pane <agent_pane> <placeholder> <view_session> <home_session>
  _ap="$1" _pp="$2" _vs="$3" _hs="$4"
  if [ -z "$_ap" ] || ! agents_pane_alive "$_ap"; then
    [ -n "$_pp" ] && agents_pane_alive "$_pp" && tmux kill-pane -t "$_pp" 2>/dev/null
    return 0
  fi
  [ "$(agents_pane_session "$_ap")" = "$_vs" ] || return 0 # already home
  if [ -n "$_pp" ] && agents_pane_alive "$_pp" &&
    tmux swap-pane -d -s "$_ap" -t "$_pp" 2>/dev/null; then
    return 0
  fi
  if [ -n "$_hs" ] && tmux has-session -t "=$_hs" 2>/dev/null &&
    tmux break-pane -d -s "$_ap" -t "=$_hs:" 2>/dev/null; then
    return 0
  fi
  [ "$(agents_pane_session "$_ap")" = "$_vs" ] && return 1
  return 0
}

agents_sweep() { # agents_sweep [<pre-fetched session rows>]
  _now="$(date +%s)"
  _self=$$
  if [ "$#" -ge 1 ]; then
    _swr="$1"
  else
    _swr="$(agents_rows list-sessions -F "#{session_name}${AGENTS_TAB}#{session_attached}${AGENTS_TAB}#{session_created}${AGENTS_TAB}#{@agents_owned}${AGENTS_TAB}#{@agents_owner}${AGENTS_TAB}#{@agents_home}${AGENTS_TAB}#{@agents_swap}")"
  fi
  while IFS="$AGENTS_SEP" read -r _n _a _c _o _own _home _swap; do
    [ "$_o" = 1 ] || continue
    [ "$_a" = 0 ] || continue
    case "$_c" in '' | *[!0-9]*) continue ;; esac
    [ "$((_now - _c))" -ge 15 ] || continue
    if [ -n "$_own" ] && [ "$_own" != "$_self" ]; then
      case "$_own" in
      '' | *[!0-9]*) ;;
      *) kill -0 "$_own" 2>/dev/null && continue ;;
      esac
    fi
    _sap="${_swap%% *}"
    _spp=""
    case "$_swap" in *' '*) _spp="${_swap#* }" ;; esac
    if [ -n "$_sap" ]; then
      agents_restore_pane "$_sap" "$_spp" "$_n" "$_home" || continue
    fi
    agents_dbg "sweep reaped $_n"
    tmux kill-session -t "=$_n" 2>/dev/null
  done <<EOF
$_swr
EOF
  return 0
}
