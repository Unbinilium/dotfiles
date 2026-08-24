BEGIN {
  ell = (ENVIRON["AGENTS_M_ELL"] == "") ? "..." : ENVIRON["AGENTS_M_ELL"]
  MAXUP = 24
  OFS = ENVIRON["AGENTS_SEP"]
  if (OFS == "") OFS = FS
  nnames = split(ENVIRON["AGENTS_PATTERNS"], name_arr, /[ ,\n]+/)
  for (ni = 1; ni <= nnames; ++ni) name_set[name_arr[ni]] = 1
  ntr = split(ENVIRON["AGENTS_TRANSPORTS"], tr_arr, /[ ,\n]+/)
  for (ni = 1; ni <= ntr; ++ni) tr_set[tr_arr[ni]] = 1
  ntt = 0
  ntl = split(ENVIRON["AGENTS_TITLES"], tl, /[,\n]+/)
  for (ti = 1; ti <= ntl; ++ti) {
    te = index(tl[ti], "=")
    if (te < 2) continue
    ++ntt
    tt_name[ntt] = substr(tl[ti], 1, te - 1)
    tt_re[ntt] = tolower(substr(tl[ti], te + 1))
    gsub(/^[ \t]+|[ \t]+$/, "", tt_name[ntt])
    gsub(/^[ \t]+|[ \t]+$/, "", tt_re[ntt])
  }
  inps = 0
}

$0 == "==PS==" { inps = 1; next }

!inps {
  if ($1 in seen) next
  seen[$1] = 1
  ++np
  p_id[np] = $1; p_pid[np] = $2; p_ses[np] = $3
  p_wix[np] = $4; p_wid[np] = $5; p_stamp[np] = $6
  p_own[np] = $7; p_swap[np] = $8; p_title[np] = $9; p_cwd[np] = $10
  ses_of[$1] = $3; wix_of[$1] = $4; wid_of[$1] = $5
  next
}

inps {
  if (!match($0, /^[ \t]*[^ \t]+[ \t]+[^ \t]+[ \t]+[^ \t]+[ \t]+[^ \t]+[ \t]*/)) next
  if (split(substr($0, 1, RLENGTH), f, " ") < 4) next
  pid = f[1] + 0
  etime[pid] = f[3]
  pcpu[pid] = f[4]
  argv[pid] = substr($0, RLENGTH + 1)
  kids[f[2] + 0] = kids[f[2] + 0] " " pid
}

function base(s) { sub(/.*\//, "", s); return s }

function requote(s) { gsub(/[].[^$(){}|*+?\\\/]/, "\\\\&", s); return s }

function is_agent(b) { return (b in name_set) }

function agent_name(pid, n, t, b, j, rest) {
  n = split(argv[pid], t, " ")
  if (n == 0) return ""
  b = base(t[1])
  if (is_agent(b)) return b
  if (b !~ /^(node|nodejs|bun|deno|python[0-9.]*|ruby|sh|bash|zsh|dash)$/ || n < 2) return ""
  b = base(t[2])
  if (is_agent(b)) return b
  rest = argv[pid]
  sub(/^[^ ]* /, "", rest)
  if (substr(rest, 1, 1) != "/") return ""
  for (j = 1; j <= nnames; ++j)
    if (rest ~ ("^/.*/" requote(name_arr[j]) "( |$)")) return name_arr[j]
  return ""
}

function find_first(root, want, q, h, t, pid, m, arr, i, f) {
  q[0] = root; h = 0; t = 1
  while (h < t && t < 512) {
    pid = q[h++]
    if (want == "t") {
      if (split(argv[pid], f, " ") > 0 && is_transport(base(f[1])))
        return pid
    } else if (agent_name(pid) != "") return pid
    m = split(kids[pid], arr, " ")
    for (i = 1; i <= m; ++i) if (arr[i] != "") q[t++] = arr[i]
  }
  return 0
}

function is_transport(b) { return (b in tr_set) }

function opt_takes_arg(b) {
  if (b == "autossh") return "MbcDEeFIiJLlmOoPpQRSWw"
  if (b == "ssh" || b == "slogin") return "bcDEeFIiJLlmOoPpQRSWw"
  if (b == "mosh" || b == "mosh-client") return "pIs"
  if (b == "telnet" || b == "rlogin") return "belnSx"
  if (b == "docker" || b == "podman") return "euw"
  if (b == "kubectl") return "cn"
  if (b == "lxc" || b == "incus") return "eu"
  if (b == "nsenter") return "tSGn"
  return ""
}

function transport_dest(pid, n, t, i, tok, b, args) {
  n = split(argv[pid], t, " ")
  if (n == 0) return "?"
  b = base(t[1])
  args = opt_takes_arg(b)
  for (i = 2; i <= n; ++i) {
    tok = t[i]
    if (substr(tok, 1, 1) == "-") {
      if (length(tok) == 2 && args != "" && index(args, substr(tok, 2, 1)) > 0) ++i
      continue
    }
    if (b !~ /^(ssh|slogin|autossh|mosh|mosh-client|telnet|rlogin)$/ && tok ~ /^(exec|attach|run|enter|shell|login|start)$/) continue
    sub(/^[^@]*@/, "", tok)
    if (tok ~ /^[0-9]+$/ || tok ~ /^(sh|bash|zsh|dash|fish|ash|ksh)$/)
      return b
    return tok
  }
  return b
}

function title_agent(ttl, i, lt) {
  if (ttl == "") return ""
  lt = tolower(ttl)
  for (i = 1; i <= ntt; ++i) if (lt ~ tt_re[i]) return tt_name[i]
  for (i = 1; i <= nnames; ++i)
    if (lt ~ ("(^|[^a-z0-9])" requote(tolower(name_arr[i])) "([^a-z0-9]|$)")) return name_arr[i]
  return ""
}

function etime_secs(e, dp, hms, n, d, s) {
  d = 0
  if (e ~ /-/) { split(e, dp, "-"); d = dp[1]; e = dp[2] }
  n = split(e, hms, ":")
  if (n == 3) s = hms[1] * 3600 + hms[2] * 60 + hms[3]
  else if (n == 2) s = hms[1] * 60 + hms[2]
  else s = hms[1] + 0
  return d * 86400 + s
}

function branch(dir, d, i, f, line, gd) {
  if (dir == "" || dir == "-") return ""
  if (dir in br_seen) return br_seen[dir]
  d = dir
  br_seen[dir] = ""
  wt_seen[dir] = ""
  for (i = 0; i < MAXUP && d != "" && d != "/"; ++i) {
    f = d "/.git/HEAD"
    line = ""
    if ((getline line < f) > 0) { close(f); br_seen[dir] = head_ref(line); break }
    close(f)
    f = d "/.git"
    line = ""
    if ((getline line < f) > 0) {
      close(f)
      if (substr(line, 1, 8) == "gitdir: ") {
        gd = substr(line, 9)
        sub(/[\r\n]+$/, "", gd)
        if (substr(gd, 1, 1) != "/") gd = d "/" gd
        while (sub(/\/[^\/]+\/\.\.\//, "/", gd)) ;
        wt_seen[dir] = repo_of(gd)
        line = ""
        if ((getline line < (gd "/HEAD")) > 0) br_seen[dir] = head_ref(line)
        close(gd "/HEAD")
      }
      break
    }
    close(f)
    if (d !~ /\//) break
    sub(/\/[^\/]*$/, "", d)
  }
  return br_seen[dir]
}

function repo_of(gd, nseg, seg, leaf) {
  nseg = split(gd, seg, "/")
  if (nseg < 2 || seg[nseg - 1] != "worktrees") return ""
  leaf = seg[nseg - 2]
  if (leaf == ".git") leaf = (nseg >= 4) ? seg[nseg - 3] : ""
  sub(/\.git$/, "", leaf)
  if (leaf == "" || leaf == "." || leaf == "..") return ell
  return leaf
}

function head_ref(line, n) {
  sub(/[\r\n]+$/, "", line)
  if (substr(line, 1, 5) == "ref: ") {
    n = substr(line, 6)
    sub(/^refs\/heads\//, "", n)
    return n
  }
  if (line ~ /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]/)
    return "@" substr(line, 1, 7)
  return ""
}

END {
  home = ENVIRON["HOME"]
  for (i = 1; i <= np; ++i) {
    ses = p_ses[i]; wix = p_wix[i]; wid = p_wid[i]
    if (p_own[i] == "1") {
      if (split(p_swap[i], sw, " ") < 2) continue
      if (sw[1] != p_id[i] || !(sw[2] in ses_of)) continue
      ses = ses_of[sw[2]]; wix = wix_of[sw[2]]; wid = wid_of[sw[2]]
    }
    pid = find_first(p_pid[i] + 0, "")
    if (!pid) {
      tp = find_first(p_pid[i] + 0, "t")
      if (!tp) continue
      nm = title_agent(p_title[i])
      if (nm == "") continue
      print p_id[i], tp, nm, etime_secs(etime[tp]), pcpu[tp], "@" transport_dest(tp), ses, wix, wid, p_stamp[i], ""
      continue
    }
    nm = agent_name(pid)
    cwd = p_cwd[i]
    if (home != "" && index(cwd, home) == 1) cwd = "~" substr(cwd, length(home) + 1)
    if (cwd == "") cwd = "-"
    bn = branch(p_cwd[i])
    if (length(bn) > 18 && index(bn, "/") > 0) {
      nseg = split(bn, seg, "/")
      bn = ell "/" seg[nseg]
    }
    rp = wt_seen[p_cwd[i]]
    if (bn != "" && rp != "") {
      if (length(rp) > 18) rp = (index(bn, ell "/") == 1) ? "" : ell
      if (rp != "") bn = rp ":" bn
    }
    print p_id[i], pid, nm, etime_secs(etime[pid]), pcpu[pid], cwd, ses, wix, wid, p_stamp[i], bn
  }
}
