BEGIN {
  SQ = sprintf("%c", 39)
  sec = "opt"
  nopt = split("o_patterns o_interval o_tick o_stamp o_return o_embed" \
    " o_dwell o_cache o_capture o_busy o_wait o_cpu o_prefix o_recenter" \
    " o_transports o_titles o_glyphs o_border o_dtime o_bline o_debug" \
    " o_vstat", oname, " ")
}

function q(s, out, i) {
  out = ""
  i = index(s, SQ)
  while (i > 0) {
    out = out substr(s, 1, i - 1) SQ "\\" SQ SQ
    s = substr(s, i + 1)
    i = index(s, SQ)
  }
  return SQ out s SQ
}

$0 == "==STY==" { sec = "sty"; next }
$0 == "==CLI==" { sec = "cli"; next }
$0 == "==SES==" { sec = "ses"; next }

sec == "opt" { optraw = optraw $0 "\n"; next }
sec == "sty" { styraw = styraw $0 "\n"; next }
sec == "cli" {
  if (want != "" && $1 == want) wantgeo = $3
  if (sid != "" && $2 == sid) { ++nsid; sidname = $1; sidgeo = $3 }
  next
}
sec == "ses" {
  line = $1
  for (i = 2; i <= NF; ++i) line = line sep $i
  swrows = swrows line "\n"
  next
}

END {
  if (optraw != "") {
    optraw = substr(optraw, 1, length(optraw) - 1)
    j = sep
    if (substr(optraw, 1, 1) == sep) optraw = substr(optraw, 2)
    else if (substr(optraw, 1, 4) == "\\037") {
      j = "\\037"
      optraw = substr(optraw, 5)
    }
    n = 0
    while ((i = index(optraw, j)) > 0) {
      v[++n] = substr(optraw, 1, i - 1)
      optraw = substr(optraw, i + length(j))
    }
    v[++n] = optraw
    for (i = 1; i <= n && i <= nopt; ++i) print oname[i] "=" q(v[i])
  }
  sub(/\n$/, "", styraw)
  sub(/\n$/, "", swrows)
  print "STYLE_RAW=" q(styraw)
  print "SWEEP_ROWS=" q(swrows)
  if (want != "") {
    if (wantgeo != "") print "CLIENT=" q(want) "\nCLIENT_GEO=" q(wantgeo)
  } else if (nsid == 1) {
    print "CLIENT=" q(sidname) "\nCLIENT_GEO=" q(sidgeo)
  }
}
