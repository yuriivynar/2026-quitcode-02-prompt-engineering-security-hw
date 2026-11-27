#!/usr/bin/env bash
# Local pre-flight scan for docs/sanitization-checklist.md §2.
# Prints ONLY category, match count and line numbers — never the matched text,
# so neither the terminal log nor an AI agent running this sees the values.
#
#   bash .claude/scripts/sanitize-scan.sh <file>...
#   bash .claude/scripts/sanitize-scan.test.sh      # regression tests
#
# Exit: 0 = no BLOCK hits and every file decoded with certainty (CLEAN / REVIEW),
# 1 = at least one BLOCK hit, 4 = no BLOCK hit but at least one file is MANUAL
# (binary, undecodable, or its encoding was only guessed), 2 = usage / missing or
# unreadable file, 3 = grep or iconv failed while scanning. On 2 and 3 no RESULT:
# line is printed — callers must treat a missing RESULT: line as a hard stop,
# never CLEAN.
#
# Encodings. grep only sees bytes, so a UTF-16 file hides "sk-…" as "s\0k\0-\0…"
# and a naive scan reports CLEAN (finding of the 16.11 re-check). Before scanning,
# each file is classified from its first bytes:
#   - UTF-8 / ASCII (valid UTF-8, BOM or not)        → scanned as is;
#   - BOM of UTF-16LE/BE or UTF-32LE/BE              → decoded with iconv to UTF-8;
#   - no BOM, NUL bytes in a UTF-16/32 pattern       → decoded as guessed — MANUAL;
#   - no NUL, not valid UTF-8 (legacy 8-bit)         → decoded as CP1251 — MANUAL;
#   - any other NUL pattern, or decoding fails       → binary — MANUAL.
# A MANUAL file is never CLEAN: a BLOCK hit still wins, otherwise a human converts
# or reads it locally. Guessed and binary files are additionally scanned with NUL
# bytes stripped, so an ASCII key interleaved with NULs is still found.
# Files are scanned with grep -a so NUL bytes cannot hide a match behind GNU grep's
# "binary file matches" message (which newer grep sends to stderr, not stdout).

export LC_ALL=C.UTF-8
umask 077

# severity|category|extended regex (case-insensitive)
PATTERNS=$(cat <<'EOF'
BLOCK|key prefix (sk-/ghp_/github_pat_/AKIA/AIza)|(^|[^a-z0-9])(sk-[a-z0-9]{4,}|ghp_[a-z0-9]{8,}|github_pat_|akia[a-z0-9]{12,}|aiza[a-z0-9_-]{20,})
BLOCK|Slack token (xox?-)|xox[bpars]-[a-z0-9-]{8,}
BLOCK|Airtable PAT|(^|[^a-z0-9])pat[a-z0-9]{3,}\.[a-z0-9]{8,}
BLOCK|live/test API key (name_live_xxx)|[a-z0-9]+_(live|test)_[a-z0-9]{10,}
BLOCK|JWT|eyj[a-z0-9_-]{10,}\.[a-z0-9_-]{10,}
BLOCK|connection string|(postgres|postgresql|mysql|mariadb|mongodb(\+srv)?|redis|amqp|mssql)://
BLOCK|credentials in URL|://[^/[:space:]:@]+:[^/[:space:]@]+@
BLOCK|token in URL query|[?&](token|key|api_key|access_token|sig|signature)=
BLOCK|private key block|-----BEGIN [a-z ]*PRIVATE KEY-----
REVIEW|secret marker word|key|token|secret|passw|pwd|credential|bearer
REVIEW|webhook / hook URL|webhook|hooks\.
REVIEW|internal ID (Airtable app…)|(^|[^a-z0-9])app[A-Z0-9][a-z0-9]{8,}
REVIEW|email|[a-z0-9._%+-]+@[a-z0-9-]+\.[a-z0-9.-]+
REVIEW|UA phone (real operator code)|\+?380[[:space:](]*[1-9][0-9]|(^|[^0-9])0[1-9][0-9][[:space:]-]?[0-9]{3}[[:space:]-]?[0-9]{2}
REVIEW|IBAN / card number|ua[0-9]{27}|([0-9]{4}[[:space:]-]?){3}[0-9]{4}
REVIEW|tax ID (ЄДРПОУ 8 / РНОКПП 10 digits)|(^|[^0-9])([0-9]{8}|[0-9]{10})([^0-9]|$)
REVIEW|messenger handle|(^|[[:space:]])@[a-z0-9_]{4,}
REVIEW|street address|вул\.|просп\.|бульв\.|пров\.|кв\.|оф\.
REVIEW|money / commercial terms|\$[0-9]|₴|грн|маржа|собівартість|ставк|/год
REVIEW|hidden text for AI (comments, SYSTEM blocks)|<!--|system *[/:]|ignore (all |previous )|ігноруй
EOF
)

if [ "$#" -eq 0 ]; then
  echo "usage: bash .claude/scripts/sanitize-scan.sh <file>..." >&2
  exit 2
fi

for tool in od awk iconv tr mktemp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "scan error: required tool '$tool' not found — not CLEAN" >&2
    exit 3
  fi
done

tmp=$(mktemp -d) || { echo "scan error: mktemp failed — not CLEAN" >&2; exit 3; }
trap 'rm -rf "$tmp"' EXIT

# classify <file>: prints one of UTF-8, UTF-8-BOM, UTF-16, UTF-32 (BOM present),
# UTF-16LE, UTF-16BE, UTF-32LE, UTF-32BE (guessed from NUL layout), BINARY, or
# NO-NUL (no NUL bytes; the caller checks whether it is valid UTF-8).
classify() {
  local head
  head=$(od -An -v -tx1 -N4 -- "$1" | tr -d ' \n')
  case $head in
    0000feff*) echo UTF-32; return ;;
    fffe0000*) echo UTF-32; return ;;   # UTF-32LE BOM — checked before UTF-16LE
    efbbbf*)   echo UTF-8-BOM; return ;;
    feff*)     echo UTF-16; return ;;
    fffe*)     echo UTF-16; return ;;
  esac
  # Count NUL bytes per offset mod 4 in the first 64 KiB. Text in UTF-16 has a
  # NUL in the high byte of every ASCII character (odd offsets for LE, even for
  # BE); UTF-32 has two or three NULs per character. Stray NULs in otherwise
  # 8-bit text are too rare and too scattered to look like either.
  od -An -v -tu1 -N 65536 -- "$1" | awk '
    { for (i = 1; i <= NF; i++) { if ($i == 0) z[n % 4]++; n++ } }
    END {
      z0 = z[0] + 0; z1 = z[1] + 0; z2 = z[2] + 0; z3 = z[3] + 0
      nul = z0 + z1 + z2 + z3; q = n / 4
      if (nul == 0)                                   { print "NO-NUL"; exit }
      if (z2 >= 0.9 * q && z3 >= 0.9 * q && z0 <= 0.1 * q) { print "UTF-32LE"; exit }
      if (z0 >= 0.9 * q && z1 >= 0.9 * q && z3 <= 0.1 * q) { print "UTF-32BE"; exit }
      odd = z1 + z3; even = z0 + z2
      if (nul >= 0.1 * n && even <= 0.05 * odd)       { print "UTF-16LE"; exit }
      if (nul >= 0.1 * n && odd <= 0.05 * even)       { print "UTF-16BE"; exit }
      print "BINARY"
    }'
}

status=0
idx=0
for f in "$@"; do
  if [ ! -f "$f" ] || [ ! -r "$f" ]; then echo "missing or unreadable file: $f" >&2; exit 2; fi
  echo "== $f"
  idx=$((idx + 1))
  decoded="$tmp/$idx.decoded"; stripped="$tmp/$idx.stripped"

  # sources = files grep reads (same line numbering); manual = why CLEAN is impossible
  sources=(); manual=""; note=""
  kind=$(classify "$f")
  case $kind in
    UTF-8-BOM) sources=("$f") ;;
    NO-NUL)
      if iconv -f UTF-8 -t UTF-8 -- "$f" >/dev/null 2>&1; then
        sources=("$f")
      elif iconv -f CP1251 -t UTF-8 -- "$f" > "$decoded" 2>/dev/null; then
        sources=("$decoded"); note="not valid UTF-8 — decoded as CP1251 (guess)"
        manual="encoding was guessed"
      else
        sources=("$f"); note="not valid UTF-8 and not CP1251 — scanned as raw bytes"
        manual="content is undecodable"
      fi ;;
    UTF-16|UTF-32|UTF-16LE|UTF-16BE|UTF-32LE|UTF-32BE)
      if iconv -f "$kind" -t UTF-8 -- "$f" > "$decoded" 2>/dev/null; then
        sources=("$decoded")
        case $kind in
          UTF-16|UTF-32) note="$kind with BOM — decoded to UTF-8 before scanning" ;;
          *) note="no BOM, NUL layout looks like $kind — decoded as a guess"
             manual="encoding was guessed" ;;
        esac
      else
        note="looks like $kind but does not decode — scanned as raw bytes"
        manual="content is undecodable"
      fi ;;
    *) note="binary content (NUL bytes outside any UTF-16/32 layout) — scanned as raw bytes"
       manual="content is binary" ;;
  esac
  if [ -n "$manual" ]; then
    # Also scan the raw bytes with NULs stripped: line numbers are unchanged
    # (only NUL bytes go), and an ASCII key split by NULs becomes visible.
    if ! tr -d '\000' < "$f" > "$stripped"; then
      echo "scan error: could not prepare $f — not CLEAN" >&2; exit 3
    fi
    sources+=("$f" "$stripped")
  fi
  [ -n "$note" ] && echo "  encoding: $note"

  block=0; review=0
  while IFS='|' read -r sev cat re; do
    [ -z "$sev" ] && continue
    lines=""
    for src in "${sources[@]}"; do
      # Probe first so "no match" (1) and "grep failed" (>=2) are told apart.
      grep -a -q -i -E -e "$re" -- "$src"; rc=$?
      if [ "$rc" -gt 1 ]; then
        echo "scan error: grep exited $rc on $f (pattern: $cat) — not CLEAN" >&2
        exit 3
      fi
      [ "$rc" -eq 1 ] && continue
      lines="$lines$(grep -a -n -i -E -e "$re" -- "$src" | cut -d: -f1)"$'\n'
    done
    [ -z "$lines" ] && continue
    lines=$(printf '%s' "$lines" | grep -E '^[0-9]+$' | sort -n -u | paste -sd, -)
    [ -z "$lines" ] && continue
    n=$(printf '%s\n' "$lines" | awk -F, '{print NF}')
    printf '  %-6s %-46s %3s line(s): %s\n' "$sev" "$cat" "$n" "$lines"
    if [ "$sev" = BLOCK ]; then block=$((block + 1)); else review=$((review + 1)); fi
  done <<< "$PATTERNS"
  if [ "$block" -gt 0 ]; then
    echo "  RESULT: BLOCK — $block secret category(ies) found; do not send this file to any model"
    status=1
  elif [ -n "$manual" ]; then
    echo "  RESULT: MANUAL — $manual; patterns cannot be trusted on it ($review other category(ies) above). Not CLEAN: a human converts it to UTF-8 or reads it locally"
    [ "$status" -eq 0 ] && status=4
  elif [ "$review" -gt 0 ]; then
    echo "  RESULT: REVIEW — no secrets matched; a human checks $review category(ies) above are placeholders/synthetic"
  else
    echo "  RESULT: CLEAN — no pattern matched (still read it once: patterns are not a guarantee)"
  fi
done
exit "$status"
