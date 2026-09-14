#!/usr/bin/env bash
# Local pre-flight scan for docs/sanitization-checklist.md §2.
# Prints ONLY category, match count and line numbers — never the matched text,
# so neither the terminal log nor an AI agent running this sees the values.
#
#   bash .claude/scripts/sanitize-scan.sh <file>...
#
# Exit: 0 = no BLOCK hits, 1 = at least one BLOCK hit, 2 = usage / missing file.

export LC_ALL=C.UTF-8

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

status=0
for f in "$@"; do
  if [ ! -f "$f" ]; then echo "missing file: $f" >&2; exit 2; fi
  echo "== $f"
  block=0; review=0
  while IFS='|' read -r sev cat re; do
    [ -z "$sev" ] && continue
    lines=$(grep -n -i -E -e "$re" -- "$f" | cut -d: -f1 | sort -n -u | paste -sd, -)
    [ -z "$lines" ] && continue
    n=$(printf '%s\n' "$lines" | awk -F, '{print NF}')
    printf '  %-6s %-46s %3s line(s): %s\n' "$sev" "$cat" "$n" "$lines"
    if [ "$sev" = BLOCK ]; then block=$((block + 1)); else review=$((review + 1)); fi
  done <<< "$PATTERNS"
  if [ "$block" -gt 0 ]; then
    echo "  RESULT: BLOCK — $block secret category(ies) found; do not send this file to any model"
    status=1
  elif [ "$review" -gt 0 ]; then
    echo "  RESULT: REVIEW — no secrets matched; a human checks $review category(ies) above are placeholders/synthetic"
  else
    echo "  RESULT: CLEAN — no pattern matched (still read it once: patterns are not a guarantee)"
  fi
done
exit "$status"
