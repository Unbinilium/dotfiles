BEGIN {
  E = sprintf("%c", 27)
  R = E "[0m"
  CR = sprintf("%c", 13)
  SEL = ENVIRON["AGENTS_S_SEL"]; CHR = ENVIRON["AGENTS_S_CHROME"]
  MSG = ENVIRON["AGENTS_S_MSG"]; BUSY = ENVIRON["AGENTS_S_BUSY"]
  WAIT = ENVIRON["AGENTS_S_WAIT"]; IDLE = ENVIRON["AGENTS_S_IDLE"]
  msg = ENVIRON["AGENTS_MSG"]
  M_ELL = mark("AGENTS_M_ELL", "...")
  M_SEP = mark("AGENTS_M_SEP", "-")
  TI = ENVIRON["AGENTS_PV_TITLE"]
  M_BUSY = mark("AGENTS_M_BUSY", "*")
  M_WAIT = mark("AGENTS_M_WAIT", "!")
  M_IDLE = mark("AGENTS_M_IDLE", "-")
  RULE = mark("AGENTS_M_RULE", "-")
  BLANK = sprintf("%" cols "s", "")
  INSET = " "
  GUT = 5
  W_UP = 7
  NW_MAX = 16
  LW_MAX = 24
  BW_MAX = 18
  TW_MAX = 32
  CWD_KEEP = 14
  MID = " " sprintf("%c%c", 194, 183) " "

  KEYS = "enter open,j-k move,1-9 jump,r refresh,x kill,q quit"
  nhint = split(KEYS, hint, ",")
  split("1,3,5,6,4,2", hrank, ",")
  for (i = 1; i <= nhint; ++i) rank[hint[i]] = hrank[i]

  FF = ENVIRON["AGENTS_FRAME_F"]
  full = 1
  if (FF != "") {
    if ((getline pline < FF) > 0) {
      if (pline == "@" cols) {
        full = 0
        while ((getline pline < FF) > 0 && pn < 500) P[++pn] = pline
      }
      close(FF)
    }
  }
}

function mark(name, dflt) { return ENVIRON[name] == "" ? dflt : ENVIRON[name] }

$0 == "==PV==" { inpv = 1; next }
inpv { pv[++npv] = $0; next }
NF >= 10 {
  ++n
  name[n] = $3; st[n] = $4; up[n] = $5 + 0; cwd[n] = $6; loc[n] = $7 ":" $8
  br[n] = $11
  ti[n] = tclean($12, cwd[n])
  if (dw(name[n]) > nwn) nwn = dw(name[n])
  if (dw(ti[n]) > twn) twn = dw(ti[n])
  if (dw(br[n]) > bwn) bwn = dw(br[n])
  if (index(br[n], ":")) bwide = 1
}

function ordinit(i) {
  for (i = 1; i < 256; ++i) ORD[sprintf("%c", i)] = i
  ORDN = 1
}

function rep(c, w, need, s) { # w copies of c, from a doubling cache
  need = w * length(c)
  s = REPS[c]
  if (length(s) < need) {
    if (s == "") s = c
    while (length(s) < need) s = s s
    REPS[c] = s
  }
  return substr(s, 1, need)
}

function dw(s, w, i, n, c, cp) {
  if (s !~ /[^ -~]/) return length(s)
  if (!ORDN) ordinit()
  n = length(s)
  w = 0
  for (i = 1; i <= n; ) {
    c = ORD[substr(s, i, 1)]
    if (c < 128) { ++w; ++i; continue }
    if (c < 194) { ++i; continue }
    if (c < 224) { cp = (c - 192) * 64 + ORD[substr(s, i + 1, 1)] % 64; i += 2 }
    else if (c < 240) {
      cp = ((c - 224) * 64 + ORD[substr(s, i + 1, 1)] % 64) * 64 + ORD[substr(s, i + 2, 1)] % 64
      i += 3
    } else {
      cp = (((c - 240) * 64 + ORD[substr(s, i + 1, 1)] % 64) * 64 + ORD[substr(s, i + 2, 1)] % 64) * 64 + ORD[substr(s, i + 3, 1)] % 64
      i += 4
    }
    w += cpw(cp)
  }
  return w
}

function cpw(cp) {
  if (cp >= 19968 && cp <= 40959) return 2      # CJK unified
  if (cp >= 768 && cp <= 879) return 0          # combining marks (NFD)
  if (cp >= 12353 && cp <= 19903) return 2      # kana .. CJK ext A
  if (cp >= 44032 && cp <= 55203) return 2      # hangul syllables
  if (cp >= 11904 && cp <= 12350) return 2      # radicals, CJK punct
  if (cp >= 63744 && cp <= 64255) return 2      # compat ideographs
  if (cp >= 65280 && cp <= 65376) return 2      # fullwidth forms
  if (cp >= 65504 && cp <= 65510) return 2
  if (cp >= 4352 && cp <= 4447) return 2        # hangul jamo
  if (cp >= 40960 && cp <= 42191) return 2      # yi
  if (cp >= 43360 && cp <= 43391) return 2
  if (cp >= 65072 && cp <= 65103) return 2      # vertical forms
  if (cp >= 65128 && cp <= 65131) return 2
  if (cp >= 127744 && cp <= 128767) return 2    # emoji, transport
  if (cp >= 129280 && cp <= 129791) return 2
  if (cp >= 131072 && cp <= 262141) return 2    # CJK ext B and on
  if ((cp >= 8203 && cp <= 8207) || cp == 8288) return 0
  if (cp >= 8400 && cp <= 8447) return 0        # enclosing marks
  if (cp >= 65024 && cp <= 65039) return 0      # variation selectors
  if (cp >= 65056 && cp <= 65071) return 0      # half marks
  return 1
}

function ln(s) { L[++nrow] = s }
function pad(s, w, d) {
  d = w - dw(s)
  return (d > 0) ? s rep(" ", d) : s
}

function rfind(s, t, p, q, at) { # index() of the LAST occurrence of t
  p = 0; at = 1
  while ((q = index(substr(s, at), t)) > 0) { p = at + q - 1; at = p + 1 }
  return p
}

function tclean(t, cwdpath, p, tail, seg) { # peel a title's id suffix and cwd-leaf prefix
  if (t == "") return t
  p = rfind(t, MID)
  if (p > 0) {
    tail = tolower(substr(t, p + length(MID)))
    if (length(tail) >= 8 && tail ~ /^[0-9a-f][0-9a-f-]*$/) t = substr(t, 1, p - 1)
  }
  p = index(t, MID)
  if (p > 1) {
    seg = substr(t, 1, p - 1)
    sub(/\/+$/, "", cwdpath)
    sub(/.*\//, "", cwdpath)
    if (cwdpath != "" && seg == cwdpath) t = substr(t, p + length(MID))
  }
  return t
}

function tcut(t) { # a title column entry, cut to its column
  if (dw(t) <= tw) return t
  return dwcut(t, tw - dw(M_ELL)) M_ELL
}

function dwcut(s, w, i, n, c, cl, cw, tot) { # cut s to display width w, whole chars
  if (dw(s) <= w) return s
  if (!ORDN) ordinit()
  n = length(s)
  tot = 0
  for (i = 1; i <= n; ) {
    c = ORD[substr(s, i, 1)]
    if (c < 128) { cl = 1; cw = 1 }
    else if (c < 194) { cl = 1; cw = 0 }
    else if (c < 224) { cl = 2; cw = cpw((c - 192) * 64 + ORD[substr(s, i + 1, 1)] % 64) }
    else if (c < 240) { cl = 3; cw = cpw(((c - 224) * 64 + ORD[substr(s, i + 1, 1)] % 64) * 64 + ORD[substr(s, i + 2, 1)] % 64) }
    else { cl = 4; cw = cpw((((c - 240) * 64 + ORD[substr(s, i + 1, 1)] % 64) * 64 + ORD[substr(s, i + 2, 1)] % 64) * 64 + ORD[substr(s, i + 3, 1)] % 64) }
    if (tot + cw > w) break
    tot += cw
    i += cl
  }
  return substr(s, 1, i - 1)
}

function cut_path(s, w, nseg, seg, i, out, ow) {
  if (dw(s) <= w) return s
  nseg = split(s, seg, "/")
  out = seg[nseg]
  ow = dw(out)
  for (i = nseg - 1; i >= 1; --i) {
    if (dw(M_ELL) + 1 + dw(seg[i]) + 1 + ow > w) break
    out = seg[i] "/" out
    ow += dw(seg[i]) + 1
  }
  return M_ELL "/" out
}

function fields(agent, title, uptime, where, branch, path, s) {
  s = pad(agent, nw)
  if (SHOW_TI) s = s "  " pad(tcut(title), tw)
  if (SHOW_UP) s = s "  " pad(uptime, W_UP)
  if (SHOW_WH) s = s "  " pad(where, lw)
  if (SHOW_BR) s = s "  " pad(branch, bw)
  return s "  " cut_path(path, cww)
}

function gutter(i, on, lbl) {
  lbl = (i <= 9) ? i "" : " "
  if (on) return INSET lbl " " glyph(st[i], 1) " "
  return INSET lbl " " glyph(st[i], 0) R " "
}

function rdeco(fc) { return (fc == " ") ? 2 : 4 } # ␣text␣, and on a rule ──
function room(text, fc) {
 return cols - (text == "" ? 0 : dw(text) + ((fc == " ") ? 0 : 4) + 1) - rdeco(fc)
}

function bar(text, right, rightw, fc, rsty, lsty, lead, tail, deco, dressed, rw, gap, s) {
  if (text != "" && fc != " ") { lead = fc fc " "; tail = " "; deco = 4 }
  dressed = (right != "" && rightw + rdeco(fc) <= cols)
  rw = (right == "") ? 0 : (dressed ? rightw + rdeco(fc) : rightw)
  gap = cols - deco - dw(text) - rw
  if (gap < 1 && text != "" && right != "") {
    text = dwcut(text, dw(text) + gap - 1)
    if (text == "") { lead = ""; tail = ""; deco = 0 }
    gap = cols - deco - dw(text) - rw
  } else if (gap < 0) {
    text = dwcut(text, dw(text) + gap)
    if (text == "") { lead = ""; tail = ""; deco = 0 }
    gap = cols - deco - dw(text) - rw
  }
  s = lead text tail
  if (gap > 0) s = s rep(fc, gap)
  if (dressed) return s rsty " " right " " R lsty (fc == " " ? "" : fc fc)
  return s rsty right R lsty
}

function hints(budget, allow, av, ok, i, m, best, bestr, picked, npick, w, add, s) {
  m = split(allow, av, ",")
  for (i = 1; i <= m; ++i) ok[av[i]] = 1
  for (;;) {
    best = ""
    for (i = 1; i <= nhint; ++i) {
      if (!ok[hint[i]] || picked[hint[i]]) continue
      if (best == "" || rank[hint[i]] < bestr) { best = hint[i]; bestr = rank[hint[i]] }
    }
    if (best == "") break
    add = length(best) + (npick ? 3 : 0) # " / " between neighbours
    if (w + add > budget) break
    picked[best] = 1; ++npick; w += add
  }
  s = ""
  for (i = 1; i <= nhint; ++i)
    if (picked[hint[i]]) s = s (s == "" ? "" : " / ") hint[i]
  return s
}

function glyph(s, flat, g) {
  g = (s == "busy") ? M_BUSY : (s == "waiting") ? M_WAIT : M_IDLE
  return flat ? g : statesty(s) g
}
function statesty(s) { return (s == "busy") ? BUSY : (s == "waiting") ? WAIT : IDLE }
function msgsty() { return (msg != "" && plain != 1) ? MSG : "" }
function human(s) {
  if (s >= 86400) return int(s / 86400) "d" int(s % 86400 / 3600) "h"
  if (s >= 3600) return int(s / 3600) "h" int(s % 3600 / 60) "m"
  if (s >= 60) return int(s / 60) "m"
  return s "s"
}

function emit(i, nd, dam, hi) {
  if (!full) {
    for (i = 1; i <= nrow; ++i) if (i > pn || L[i] != P[i]) dam[++nd] = i
    for (i = nrow + 1; i <= pn; ++i) dam[++nd] = -i
    if (nd == 0) return
    hi = (nrow > pn) ? nrow : pn
    if (nd * 4 > hi * 3) full = 1
  }
  if (full) {
    printf "%s[?7l%s[H%s[J", E, E, E
    for (i = 1; i <= nrow; ++i) printf "%s%s", (i > 1 ? "\n" : ""), L[i]
    printf "%s[?7h", E
  } else {
    printf "%s[?7l", E
    for (i = 1; i <= nd; ++i) {
      if (dam[i] > 0) printf "%s[%d;1H%s%s[K%s", E, dam[i], R, E, L[dam[i]]
      else printf "%s[%d;1H%s%s[K", E, -dam[i], R, E
    }
    printf "%s[?7h", E
  }
  if (FF != "") {
    printf "@%s\n", cols > FF
    for (i = 1; i <= nrow; ++i) printf "%s\n", L[i] > FF
    close(FF)
  }
}

function fit(nat, lo, hi) { return (nat > hi) ? hi : ((nat < lo) ? lo : nat) }

function layout(rem) {
  SHOW_BR = (cols >= 100 && bwn > 0)
  SHOW_UP = (cols >= 80)
  SHOW_WH = (cols >= 64)
  SHOW_TI = (cols >= 48 && twn > 0)
  tw = SHOW_TI ? fit(int(cols * 28 / 100), 10, TW_MAX) : 0
  lw = SHOW_WH ? fit(int(cols * 10 / 100), 6, LW_MAX) : 0
  bw = SHOW_BR ? fit(int(cols * 12 / 100), 8, BW_MAX) : 0
  cww = cols - GUT - 1 - nw - 2
  if (SHOW_TI) cww -= tw + 2
  if (SHOW_UP) cww -= W_UP + 2
  if (SHOW_WH) cww -= lw + 2
  if (SHOW_BR) cww -= bw + 2
  if (cww < CWD_KEEP && SHOW_BR && bw > 8) {
    rem = CWD_KEEP - cww
    if (bw - rem < 8) rem = bw - 8
    bw -= rem; cww += rem
  }
  if (cww < CWD_KEEP && SHOW_WH && lw > 6) {
    rem = CWD_KEEP - cww
    if (lw - rem < 6) rem = lw - 6
    lw -= rem; cww += rem
  }
  if (cww < CWD_KEEP && SHOW_TI && tw > 10) {
    rem = CWD_KEEP - cww
    if (tw - rem < 10) rem = tw - 10
    tw -= rem; cww += rem
  }
  if (cww < 3) cww = 3
}

END {
  if (bwide) BW_MAX = 28
  nw = fit(nwn, 5, NW_MAX)
  layout()

  if (n == 0) {
    if (msg != "") ln(CHR bar("", msg, dw(msg), RULE, msgsty(), CHR) R)
    emit()
    exit
  }

  rt = (shown > 0 && shown < n) ? first "-" (first + shown - 1) "/" n : ""
  if (length(shown) == 0) { first = 1; shown = n }
  if (first < 1) first = 1
  for (i = first; i < first + shown && i <= n; ++i) {
    row = gutter(i, i == sel) fields(name[i], ti[i], human(up[i]), loc[i], br[i], cwd[i])
    if (i == sel && SEL != "") ln(SEL BLANK CR SEL row R)
    else ln(row R)
  }

  if (TI != "" && sel >= 1 && sel <= n) TI = tclean(TI, cwd[sel])
  if (npv == 0) plbl = fitting ? sprintf("fitting to %dx%d", cols, avail) : ""
  else if (exact) plbl = "preview: exact"
  else if (aw == 0) plbl = "preview"
  else if (fitting) plbl = sprintf("fitting %dx%d to %dx%d", aw, ah, cols, avail)
  else plbl = sprintf("preview: %dx%d", aw, ah)
  if (TI != "" && !fitting && (npv > 0 || plbl == "")) {
    tlbl = (exact || plbl == "") ? TI : plbl " " M_SEP " " TI
    tmax = room("", RULE) - 14 # the widest hint stays
    if (tmax >= 8) {
      if (dw(tlbl) > tmax) tlbl = dwcut(tlbl, tmax - dw(M_ELL)) M_ELL
      plbl = tlbl
    }
  }
  if (msg != "") right = msg
  else {
    right = hints(room(plbl, RULE) - (rt == "" ? 0 : dw(rt) + 3), KEYS)
    if (rt != "") right = (right == "") ? rt : rt " " M_SEP " " right
  }
  stc = (st[sel] == "busy") ? BUSY : (st[sel] == "waiting") ? WAIT : CHR
  ln(stc bar(plbl, right, dw(right), RULE, msgsty(), stc) R)

  if (npv > 0) {
    start = npv - avail + 1
    if (start < 1) start = 1
    for (i = start; i <= npv; ++i) ln(pv[i] R)
  }
  emit()
}
