#!/bin/sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/helpers.sh"

p="${1:-}"
[ -n "$p" ] && [ -d "$p" ] || exit 0

agents_marks "${2:-}"

_d="$p"
if [ -n "${HOME:-}" ] && [ "$HOME" != / ]; then
  case "$_d" in
  "$HOME") _d='~' ;;
  "$HOME"/*) _d="~${_d#"$HOME"}" ;;
  esac
fi
if [ "${#_d}" -gt 28 ]; then
  _leaf="${_d##*/}"
  _rest="${_d%/*}"
  case "$_rest" in */*) _d="$AGENTS_M_ELL/${_rest##*/}/$_leaf" ;; esac
fi
case "$_d" in *'#'*) _d="$(agents_fmt_literal "$_d")" ;; esac
printf ' %s %s' "$AGENTS_M_SEP" "$_d"

[ "${3:-}" = git ] || exit 0
command -v git >/dev/null 2>&1 || exit 0

NL='
'

_g=''
if [ -n "${GIT_DIR:-}${GIT_WORK_TREE:-}${GIT_CEILING_DIRECTORIES:-}${GIT_COMMON_DIR:-}" ]; then
  _g="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || exit 0
  [ -n "$_g" ] || exit 0
  case "$_g" in /*) ;; *) _g="$p/$_g" ;; esac
else
  _wd="$p" _up=0
  while :; do
    if [ -e "$_wd/.git/HEAD" ] && [ -d "$_wd/.git/objects" ] && [ -d "$_wd/.git/refs" ]; then
      _g="$_wd/.git"
      break
    fi
    if [ -f "$_wd/.git" ]; then
      _gl=''
      IFS= read -r _gl <"$_wd/.git" 2>/dev/null
      case "$_gl" in
      'gitdir: '*)
        _g="${_gl#gitdir: }"
        case "$_g" in /*) ;; *) _g="$_wd/$_g" ;; esac
        ;;
      esac
      break
    fi
    case "$_wd" in */*) ;; *) break ;; esac
    _nx="${_wd%/*}"
    [ -n "$_nx" ] && [ "$_nx" != "$_wd" ] || break
    _wd="$_nx"
    _up=$((_up + 1))
    [ "$_up" -lt 24 ] || break
  done
  [ -n "$_g" ] || exit 0
fi
rp='' lk=0
if [ -f "$_g/commondir" ]; then
  lk=1
  _cm="${_g%/*}"
  if [ "${_cm##*/}" = worktrees ] && [ "$_cm" != "$_g" ]; then
    _cm="${_cm%/worktrees}"
    _lf="${_cm##*/}"
    [ "$_lf" = .git ] && { _cm="${_cm%/*}"; _lf="${_cm##*/}"; }
    _lf="${_lf%.git}"
    case "$_lf" in
    '' | . | .. | /) ;;
    *) rp="$_lf" ;;
    esac
  fi
fi


_o="$(git -C "$p" status --porcelain -b 2>/dev/null | awk '
NR == 1 { h = $0; next }
{
  x = substr($0, 1, 1); y = substr($0, 2, 1)
  if (x == "U" || y == "U" || (x == "A" && y == "A") || (x == "D" && y == "D")) ++u
  else if (x == "?") ++q
  else if (x == "D" || y == "D") ++d
  else if (x == "A") ++a
  else ++m
}
END {
  s = ""
  if (u) s = s "U" u
  if (m) s = s "m" m
  if (a) s = s "a" a
  if (d) s = s "d" d
  if (q) s = s "?" q
  if (s != "") s = " " s
  printf "%s\n%s", h, s
}')"
[ -n "$_o" ] || exit 0
_h="${_o%%"$NL"*}"
n="${_o#*"$NL"}"
[ "$n" = "$_o" ] && n=''
_h="${_h#\#\# }"
case "$_h" in
'HEAD (no branch)')
  br="$(git -C "$p" rev-parse --short HEAD 2>/dev/null)"
  br="@${br:-detached}"
  ;;
'No commits yet on '*) br="${_h#No commits yet on }" ;;
*) br="${_h%%...*}" ;;
esac
if [ "${#br}" -gt 18 ]; then
  case "$br" in */*) br="$AGENTS_M_ELL/${br##*/}" ;; esac
fi
if [ "$lk" = 1 ]; then
  if [ -n "$rp" ] && [ "${#rp}" -le 18 ]; then
    br="$rp:$br"
  else
    case "$br" in
    "$AGENTS_M_ELL"/*) ;;
    *) br="$AGENTS_M_ELL:$br" ;;
    esac
  fi
fi
case "$br" in *'#'*) br="$(agents_fmt_literal "$br")" ;; esac

drift=''
case "$_h" in
*'['*)
  _b="${_h##*[}"
  case "$_b" in *'ahead '*) _a="${_b#*ahead }"; drift=" $AGENTS_M_AHEAD${_a%%[],]*}" ;; esac
  case "$_b" in *'behind '*) _a="${_b#*behind }"; drift="$drift $AGENTS_M_BEHIND${_a%%[],]*}" ;; esac
  ;;
esac

printf ' %s %s%s%s' "$AGENTS_M_SEP" "$br" "$drift" "$n"
