#!/bin/sh

[ -n "${TMUX_PANE:-}" ] || exit 0
[ -n "${TMUX:-}" ] || exit 0
[ -n "${1:-}" ] || exit 0
exec tmux set-option -p -t "$TMUX_PANE" @agent_status "$1:$(date +%s)"
