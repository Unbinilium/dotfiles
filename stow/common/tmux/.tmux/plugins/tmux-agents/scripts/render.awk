BEGIN {
  E = sprintf("%c", 27)
  R = E "[0m"
  CR = sprintf("%c", 13)
  SEL = ENVIRON["AGENTS_S_SEL"]; CHR = ENVIRON["AGENTS_S_CHROME"]
  MSG = ENVIRON["AGENTS_S_MSG"]; BUSY = ENVIRON["AGENTS_S_BUSY"]
  WAIT = ENVIRON["AGENTS_S_WAIT"]; IDLE = ENVIRON["AGENTS_S_IDLE"]
  msg = ENVIRON["AGENTS_MSG"]
  M_ELL = mark("AGENTS_M_ELL", "...")
  M_BUSY = mark("AGENTS_M_BUSY", "*")
  M_WAIT = mark("AGENTS_M_WAIT", "!")
  M_IDLE = mark("AGENTS_M_IDLE", "-")
  RULE = mark("AGENTS_M_RULE", "-")
  BLANK = sprintf("%" cols "s", "")
  INSET = " "
  GUT = 5
  INDENT = sprintf("%" GUT "s", "")
  W_UP = 7
  NW_MAX = 16
  LW_MAX = 24
  BW_MAX = 18
  CWD_KEEP = 18

  KEYS = "enter open,j-k move,1-9 jump,r refresh,x kill,q quit"
  KEYS_IDLE = "r refresh,q quit"
  nhint = split(KEYS, hint, ",")
  split("1,3,5,6,4,2", hrank, ",")
  for (i = 1; i <= nhint; ++i) rank[hint[i]] = hrank[i]

  for (i = 1; i < 256; ++i) ORD[sprintf("%c", i)] = i

  FF = ENVIRON["AGENTS_FRAME_F"]
  full = 1
  if (FF != "") {
    if ((getline pline < FF) > 0 && pline == "@" cols) {
      full = 0
      while ((getline pline < FF) > 0 && pn < 500) P[++pn] = pline
    }
    close(FF)
  }
}

function mark(name, dflt) { return ENVIRON[name] == "" ? dflt : ENVIRON[name] }

$0 == "==PV==" { inpv = 1; next }
inpv { pv[++npv] = $0; next }
NF >= 10 {
  ++n
  name[n] = $3; st[n] = $4; up[n] = $5 + 0; cwd[n] = $6; loc[n] = $7 ":" $8
  br[n] = $11
  if (dw(name[n]) > nwn) nwn = dw(name[n])
  if (dw(loc[n]) > lwn) lwn = dw(loc[n])
  if (dw(br[n]) > bwn) bwn = dw(br[n])
  if (dw(cwd[n]) > cwn) cwn = dw(cwd[n])
  if (n == 1) { loc1 = loc[n]; br1 = br[n] }
  else {
    if (loc[n] != loc1) lo_vary = 1
    if (br[n] != br1) br_vary = 1
  }
  if (index(br[n], ":")) blbl = "repo:branch"
}

function dw(s, w, i, n, c, cp) {
  if (s !~ /[^ -~]/) return length(s)
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
  while (d-- > 0) s = s " "
  return s
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

function fields(agent, uptime, where, branch, path, s) {
  s = pad(agent, nw)
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
 return cols - (text == "" ? 0 : length(text) + ((fc == " ") ? 0 : 4) + 1) - rdeco(fc)
}

function bar(text, right, rightw, fc, rsty, lsty, lead, tail, deco, dressed, rw, gap, s) {
  if (text != "" && fc != " ") { lead = fc fc " "; tail = " "; deco = 4 }
  dressed = (right != "" && rightw + rdeco(fc) <= cols)
  rw = (right == "") ? 0 : (dressed ? rightw + rdeco(fc) : rightw)
  gap = cols - deco - length(text) - rw
  if (gap < 1 && text != "" && right != "") {
    text = substr(text, 1, length(text) + gap - 1)
    if (text == "") { lead = ""; tail = ""; deco = 0 }
    gap = cols - deco - length(text) - rw
  } else if (gap < 0) {
    text = substr(text, 1, length(text) + gap)
    if (text == "") { lead = ""; tail = ""; deco = 0 }
    gap = cols - deco - length(text) - rw
  }
  s = lead text tail
  while (gap-- > 0) s = s fc
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

function layout(i, need, slack, give, nd, dcol) {
  SHOW_UP = 1
  SHOW_WH = 1
  SHOW_BR = (bw > 0)

  if (n < 2) { lo_vary = 1; br_vary = 1 }

  if (SHOW_BR && !br_vary) dcol[++nd] = "b"
  if (SHOW_WH && !lo_vary) dcol[++nd] = "w"
  dcol[++nd] = "u"
  if (SHOW_WH && lo_vary) dcol[++nd] = "w"
  if (SHOW_BR && br_vary) dcol[++nd] = "b"

  budget = cols - GUT - 1
  need = nw + 2 + CWD_KEEP
  if (SHOW_UP) need += W_UP + 2
  if (SHOW_WH) need += lw + 2
  if (SHOW_BR) need += bw + 2
  for (i = 1; i <= nd && need > budget; ++i) {
    if (dcol[i] == "u" && SHOW_UP) { SHOW_UP = 0; need -= W_UP + 2 }
    else if (dcol[i] == "w" && SHOW_WH) { SHOW_WH = 0; need -= lw + 2 }
    else if (dcol[i] == "b" && SHOW_BR) { SHOW_BR = 0; need -= bw + 2 }
  }

  cww = budget - nw - 2
  if (SHOW_UP) cww -= W_UP + 2
  if (SHOW_WH) cww -= lw + 2
  if (SHOW_BR) cww -= bw + 2

  slack = cww - cwn
  for (i = nd; i >= 1 && slack > 0; --i) {
    give = 0
    if (dcol[i] == "w" && SHOW_WH && lwn > lw) give = lwn - lw
    else if (dcol[i] == "b" && SHOW_BR && bwn > bw) give = bwn - bw
    if (give > slack) give = slack
    if (give <= 0) continue
    if (dcol[i] == "w") lw += give; else bw += give
    slack -= give
    cww -= give
  }
  if (cww < 3) cww = 3
}

END {
  if (blbl == "") blbl = "branch"
  if (blbl != "branch") BW_MAX = 28
  nw = fit(nwn, 5, NW_MAX)
  lw = fit(lwn, 5, LW_MAX)
  bw = (bwn > 0) ? fit(bwn, length(blbl), BW_MAX) : 0
  layout()

  if (n == 0) {
    ln(CHR INSET "  " (scanning ? "scanning agents..." : "no agents found") R)
    right = (msg != "") ? msg : hints(room("", RULE), KEYS_IDLE)
    ln(CHR bar("", right, dw(right), RULE, msgsty(), CHR) R)
    emit()
    exit
  }

  count = n " running"
  if (shown > 0 && shown < n) count = first "-" (first + shown - 1) " of " n
  countw = length(count)
  ln(CHR bar(INDENT fields("agent", "uptime", "where", blbl, "cwd"), count, countw, " ", "", CHR) R)
  if (length(shown) == 0) { first = 1; shown = n }
  if (first < 1) first = 1
  for (i = first; i < first + shown && i <= n; ++i) {
    row = gutter(i, i == sel) fields(name[i], human(up[i]), loc[i], br[i], cwd[i])
    if (i == sel && SEL != "") ln(SEL BLANK CR SEL row R)
    else ln(row R)
  }

  if (npv == 0) plbl = fitting ? sprintf("fitting to %dx%d", cols, avail) : ""
  else if (exact) plbl = "preview: exact"
  else if (aw == 0) plbl = "preview"
  else if (fitting) plbl = sprintf("fitting %dx%d to %dx%d", aw, ah, cols, avail)
  else plbl = sprintf("preview: %dx%d", aw, ah)
  right = (msg != "") ? msg : hints(room(plbl, RULE), KEYS)
  stc = (st[sel] == "busy") ? BUSY : (st[sel] == "waiting") ? WAIT : CHR
  ln(stc bar(plbl, right, dw(right), RULE, msgsty(), stc) R)

  if (npv > 0) {
    start = npv - avail + 1
    if (start < 1) start = 1
    for (i = start; i <= npv; ++i) ln(pv[i] R)
  }
  emit()
}
