#!/bin/sh

status_init() { # status_init <capture_lines> <busy_re> <waiting_re> <cpu_busy>
  agents_int_var "${1:-15}" 15 1 500
  AGENTS_CAPTURE_LINES="$AGENTS_IV"
  AGENTS_BUSY_RE="$2"
  AGENTS_WAIT_RE="$3"
  agents_int_var "${4:-30}" 30 1 100
  cpu_busy="$AGENTS_IV"
  [ -n "$AGENTS_BUSY_RE" ] || AGENTS_BUSY_RE='esc to interrupt|ctrl\+c to cancel|ctrl\+c to stop'
  [ -n "$AGENTS_WAIT_RE" ] || AGENTS_WAIT_RE='esc to cancel|do you want|\[y/n\]|\(y/n\)|press enter to continue'
  export AGENTS_BUSY_RE AGENTS_WAIT_RE AGENTS_CAPTURE_LINES
}

agents_status_stamp() { # agents_status_stamp <stamp> <uptime_secs> <now> -> AGENTS_ST
  AGENTS_ST='?'
  case "$1" in *:*) ;; *) return 1 ;; esac
  _sst="${1%%:*}"
  _sts="${1#*:}"
  case "$_sts" in '' | *[!0-9]*) return 1 ;; esac
  case "$2" in '' | *[!0-9]*) return 1 ;; esac
  [ "$_sts" -ge "$(($3 - $2 - 2))" ] || return 1
  case "$_sst" in
  busy | waiting | idle)
    AGENTS_ST="$_sst"
    return 0
    ;;
  esac
  return 1
}

agents_status_batch() { # agents_status_batch <pane_id>...
  [ "$#" -gt 0 ] || return 0
  _bcmd=""
  for _bp in "$@"; do
    _bcmd="$_bcmd${_bcmd:+ \\; }display-message -p -t $_bp '==AGENT #{pane_id}==' \\; capture-pane -p -t $_bp"
  done
  eval "tmux $_bcmd" 2>/dev/null | awk '
  BEGIN {
    busy = tolower(ENVIRON["AGENTS_BUSY_RE"])
    wait = tolower(ENVIRON["AGENTS_WAIT_RE"])
    n = ENVIRON["AGENTS_CAPTURE_LINES"] + 0
    if (n < 1) n = 15
  }
  function flush(i, s, start, st) {
    if (pane == "") return
    start = nb - n + 1
    if (start < 1) start = 1
    s = ""
    for (i = start; i <= nb; ++i) s = s "\n" tolower(buf[i])
    st = "idle"
    if (busy != "" && s ~ busy) st = "busy"
    else if (wait != "" && s ~ wait) st = "waiting"
    printf "%s\t%s\n", pane, st
  }
  /^==AGENT %[0-9]+==$/ {
    flush()
    pane = substr($0, 9, length($0) - 10)
    nb = 0
    next
  }
  { buf[++nb] = $0 }
  END { flush() }'
}

agents_status_cpu() { # agents_status_cpu <pcpu> -> AGENTS_ST
  _c="${1%%[.,]*}"
  case "$_c" in
  '' | *[!0-9]*) AGENTS_ST=idle ;;
  *) if [ "$_c" -ge "$cpu_busy" ]; then AGENTS_ST=busy; else AGENTS_ST=idle; fi ;;
  esac
  return 0
}
