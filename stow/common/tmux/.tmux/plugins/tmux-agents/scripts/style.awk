BEGIN {
  E = sprintf("%c", 27)
  _n = split("black red green yellow blue magenta cyan white", _b, " ")
  for (_i = 1; _i <= _n; ++_i) {
    basec[_b[_i]] = _i - 1
    basec[_i - 1] = _i - 1
    brightc["bright" _b[_i]] = _i - 1
    brightc[89 + _i] = _i - 1
  }
  _n = split("bold 1 bright 1 dim 2 italics 3 underscore 4 blink 5 reverse 7" \
    " hidden 8 strikethrough 9 overline 53 double-underscore 4" \
    " curly-underscore 4 dotted-underscore 4 dashed-underscore 4", _a, " ")
  for (_i = 1; _i < _n; _i += 2) attrn[_a[_i]] = _a[_i + 1]
  _n = split("default none noattr acs ignore noignore nolist norange noalign" \
    " nolink push-default pop-default set-default", _a, " ")
  for (_i = 1; _i <= _n; ++_i) plain[_a[_i]] = 1
  HEX = "0123456789abcdef"
}

$1 != "" && !done[$1] {
  _s = translate($2, $3)
  if (_s != "") { print $1 "\t" _s; done[$1] = 1 }
}


function translate(str, mode, nt, tok, i, low, v, fgs, bgs, attrs, fg, bg, out) {
  gsub(/,/, " ", str)
  nt = split(str, tok, " ")
  attrs = ";"
  fgs = ""
  bgs = ""
  for (i = 1; i <= nt; ++i) {
    low = tolower(tok[i])
    if (low == "default") { attrs = ";"; fgs = ""; bgs = ""; continue }
    if (low == "none" || low == "noattr") { attrs = ";"; continue }
    if (low in plain) continue
    if (substr(low, 1, 3) == "fg=") { fgs = substr(low, 4); continue }
    if (substr(low, 1, 3) == "bg=") { bgs = substr(low, 4); continue }
    if (substr(low, 1, 3) == "us=") continue
    if (low ~ /^(align|fill|list|range|width|pad|link|dim)=/) continue
    if (substr(low, 1, 2) == "no" && (substr(low, 3) in attrn)) {
      v = attrn[substr(low, 3)]
      sub(";" v ";", ";", attrs)
      continue
    }
    if (low in attrn) {
      v = attrn[low]
      if (index(attrs, ";" v ";") == 0) attrs = attrs v ";"
    }
  }
  if (mode == "fg") {
    if (index(attrs, ";7;") > 0) return ""
    if (bgs != "") { fgs = bgs; bgs = "" }
  }
  fg = (fgs == "") ? "" : colour(fgs, 0)
  bg = (bgs == "") ? "" : colour(bgs, 1)
  out = substr(attrs, 2)
  if (fg != "") out = out fg ";"
  if (bg != "") out = out bg ";"
  if (out == "") return ""
  return E "[" substr(out, 1, length(out) - 1) "m"
}

function colour(spec, isbg, hex) {
  if (spec == "") return ""
  if (spec == "default" || spec == "terminal") return ""
  if (substr(spec, 1, 1) == "#") return rgb(substr(spec, 2), isbg)
  if (spec in basec) return (isbg ? 40 : 30) + basec[spec]
  if (spec in brightc) return (isbg ? 100 : 90) + brightc[spec]
  if (substr(spec, 1, 6) == "colour") return c256(substr(spec, 7), isbg)
  if (substr(spec, 1, 5) == "color") return c256(substr(spec, 6), isbg)
  hex = ask(spec)
  return (hex == "") ? "" : rgb(hex, isbg)
}

function c256(n, isbg) {
  if (n !~ /^[0-9]+$/ || n + 0 > 255) return ""
  return (isbg ? "48;5;" : "38;5;") (n + 0)
}

function rgb(hex, isbg, i, c) {
  hex = tolower(hex)
  if (length(hex) != 6) return ""
  for (i = 1; i <= 6; ++i)
    if (index(HEX, substr(hex, i, 1)) == 0) return ""
  return (isbg ? "48;2;" : "38;2;") hexb(substr(hex, 1, 2)) ";" hexb(substr(hex, 3, 2)) ";" hexb(substr(hex, 5, 2))
}

function hexb(h) { return (index(HEX, substr(h, 1, 1)) - 1) * 16 + index(HEX, substr(h, 2, 1)) - 1 }

function ask(name, cmd, hex, i) {
  if (name in asked) return asked[name]
  asked[name] = ""
  if (name !~ /^[a-z][a-z0-9]*$/) return ""
  cmd = "tmux display-message -p '#{c:" name "}' 2>/dev/null"
  hex = ""
  cmd | getline hex
  close(cmd)
  if (length(hex) != 6) return ""
  for (i = 1; i <= 6; ++i)
    if (index(HEX, substr(hex, i, 1)) == 0) return ""
  asked[name] = hex
  return hex
}
