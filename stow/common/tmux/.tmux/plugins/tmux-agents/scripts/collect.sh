#!/bin/sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/helpers.sh"

_pf=''
trap 'rm -f "$_pf" 2>/dev/null' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

AGENTS_PATTERNS="${AGENTS_PATTERNS:-}"
AGENTS_TRANSPORTS="${AGENTS_TRANSPORTS:-}"
AGENTS_TITLES="${AGENTS_TITLES:-}"

if [ -z "$AGENTS_PATTERNS" ] || [ -z "$AGENTS_TRANSPORTS" ] || [ -z "$AGENTS_TITLES" ]; then
  _ov="$(tmux display-message -p "${AGENTS_SEP}#{@agents-patterns}${AGENTS_SEP}#{@agents-transports}${AGENTS_SEP}#{@agents-remote-titles}" 2>/dev/null)"
  agents_opt_flavour "$_ov"
  _s="$AGENTS_OS" _ov="$AGENTS_OV"
  [ -n "$AGENTS_PATTERNS" ] || AGENTS_PATTERNS="${_ov%%"$_s"*}"
  _ov="${_ov#*"$_s"}"
  [ -n "$AGENTS_TRANSPORTS" ] || AGENTS_TRANSPORTS="${_ov%%"$_s"*}"
  [ -n "$AGENTS_TITLES" ] || AGENTS_TITLES="${_ov#*"$_s"}"
fi
AGENTS_PATTERNS="${AGENTS_PATTERNS:-$AGENTS_DEFAULT_PATTERNS}"
AGENTS_TRANSPORTS="${AGENTS_TRANSPORTS:-$AGENTS_DEFAULT_TRANSPORTS}"
AGENTS_TITLES="${AGENTS_TITLES:-$AGENTS_DEFAULT_TITLES}"
export AGENTS_PATTERNS
case "$AGENTS_TRANSPORTS" in off | none) AGENTS_TRANSPORTS='' ;; esac
export AGENTS_TRANSPORTS AGENTS_TITLES
[ -n "${AGENTS_M_ELL:-}" ] || agents_marks
T="$AGENTS_TAB"
export AGENTS_SEP

collect_run() {
  agents_tmp_dir
  _pf="$AGENTS_TMP/tmux-agents-ps.$$"
  {
    ps -eo pid=,ppid=,etime=,pcpu=,args= >"$_pf" 2>/dev/null &
    _pspid=$!
    tmux list-panes -a -F "#{pane_id}${T}#{pane_pid}${T}#{session_name}${T}#{window_index}${T}#{window_id}${T}#{@agent_status}${T}#{@agents_owned}${T}#{@agents_swap}${T}#{pane_current_path}${T}#{?#{==:#{pane_title},#{host}},,#{pane_title}}" 2>/dev/null
    echo "==PS=="
    wait "$_pspid" 2>/dev/null
    cat "$_pf" 2>/dev/null
  } | awk -F "$T" -f "$DIR/collect.awk"
  _rc=$?
  rm -f "$_pf" 2>/dev/null
  return "$_rc"
}

if [ -n "${AGENTS_KICK_OUT:-}" ]; then
  _ko="$AGENTS_KICK_OUT"
  _know="$(date +%s)"
  if [ -f "$_ko" ]; then
    _kh=''
    IFS= read -r _kh <"$_ko" 2>/dev/null
    case "$_kh" in
    '#'*)
      _khe="${_kh#?}"
      case "$_khe" in
      '' | *[!0-9]*) ;;
      *) [ "$((_know - _khe))" -le 1 ] && exit 0 ;;
      esac
      ;;
    esac
  fi
  rm -f "$_ko" "$_ko.part" "$_ko.err" 2>/dev/null
  {
    printf '#%s\n' "$_know"
    collect_run
  } >"$_ko.part" 2>"$_ko.err"
  printf '%s' "$?" >>"$_ko.err"
  mv "$_ko.part" "$_ko" 2>/dev/null
  exit 0
fi
collect_run
