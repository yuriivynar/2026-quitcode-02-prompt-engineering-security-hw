#!/usr/bin/env bash
# Regression tests for sanitize-scan.sh.
#
#   bash .claude/scripts/sanitize-scan.test.sh
#
# Fixtures are generated in a temp dir at run time and deleted afterwards. The
# only "secret" is an obviously fake synthetic token assembled from pieces below,
# so this file itself never contains a contiguous key and nothing real is stored.
# Exit 0 = all cases passed, 1 = at least one failed.

export LC_ALL=C.UTF-8
here=$(cd "$(dirname "$0")" && pwd)
scan="$here/sanitize-scan.sh"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

fake="sk""-FAKE0example0NOT0real0token"   # synthetic, matches the key-prefix pattern
key_text=$(printf 'Синтетичний бриф для тесту сканера\napi = %s\nкінець файлу\n' "$fake")
clean_text=$(printf 'Hello\nThis document has nothing sensitive.\n')

utf8()    { printf '%s\n' "$2" > "$tmp/$1"; }
enc()     { printf '%s\n' "$3" | iconv -f UTF-8 -t "$2" > "$tmp/$1"; }
enc_bom() { { printf "$3"; printf '%s\n' "$4" | iconv -f UTF-8 -t "$2"; } > "$tmp/$1"; }

utf8    plain-key.txt            "$key_text"
utf8    plain-clean.txt          "$clean_text"
enc_bom utf16le-bom-key.txt      UTF-16LE '\xff\xfe'         "$key_text"
enc     utf16le-nobom-key.txt    UTF-16LE                    "$key_text"
enc_bom utf16be-bom-key.txt      UTF-16BE '\xfe\xff'         "$key_text"
enc     utf16be-nobom-key.txt    UTF-16BE                    "$key_text"
enc_bom utf32le-bom-key.txt      UTF-32LE '\xff\xfe\x00\x00' "$key_text"
enc     utf32be-nobom-key.txt    UTF-32BE                    "$key_text"
enc_bom utf16le-bom-clean.txt    UTF-16LE '\xff\xfe'         "$clean_text"
enc     utf16le-nobom-clean.txt  UTF-16LE                    "$clean_text"
enc     cp1251-key.txt           CP1251                      "$key_text"
enc     cp1251-address.txt       CP1251                      "$(printf 'Адреса: вул. Тестова, 1\n')"
printf 'line one\n\000 api = %s\n' "$fake"         > "$tmp/nul-then-key.txt"
printf '\001\000\000\002\377\000\003\004\000\000\000\005\006\007\000\010' > "$tmp/binary.bin"

pass=0; fail=0
# check <name> <expected exit> <expected RESULT word> [expected BLOCK line(s)]
check() {
  local name=$1 want_rc=$2 want_res=$3 want_lines=${4:-} out rc ok=1
  out=$(bash "$scan" "$tmp/$name" 2>&1); rc=$?
  [ "$rc" -eq "$want_rc" ] || ok=0
  if [ -n "$want_res" ]; then
    grep -q "RESULT: $want_res" <<< "$out" || ok=0
  else
    ! grep -q "RESULT:" <<< "$out" || ok=0
  fi
  grep -q "RESULT: CLEAN" <<< "$out" && [ "$want_res" != CLEAN ] && ok=0
  if [ -n "$want_lines" ]; then
    grep -Eq "BLOCK +key prefix.* line\(s\): $want_lines\$" <<< "$out" || ok=0
  fi
  grep -qF -- "$fake" <<< "$out" && ok=0            # the value itself is never printed
  if [ "$ok" -eq 1 ]; then
    pass=$((pass + 1)); echo "ok   $name → exit $rc, ${want_res:-no RESULT}"
  else
    fail=$((fail + 1)); echo "FAIL $name (want exit $want_rc, ${want_res:-no RESULT}; got exit $rc)"
    sed 's/^/     | /' <<< "$out"
  fi
}

check plain-key.txt            1 BLOCK  2
check plain-clean.txt          0 CLEAN
check utf16le-bom-key.txt      1 BLOCK  2
check utf16le-nobom-key.txt    1 BLOCK  2
check utf16be-bom-key.txt      1 BLOCK  2
check utf16be-nobom-key.txt    1 BLOCK  2
check utf32le-bom-key.txt      1 BLOCK  2
check utf32be-nobom-key.txt    1 BLOCK  2
check utf16le-bom-clean.txt    0 CLEAN
check utf16le-nobom-clean.txt  4 MANUAL
check cp1251-key.txt           1 BLOCK  2
check cp1251-address.txt       4 MANUAL
check nul-then-key.txt         1 BLOCK  2
check binary.bin               4 MANUAL
check does-not-exist.txt       2 ""

# Several files: BLOCK outranks MANUAL in the exit code; each file keeps its verdict.
out=$(bash "$scan" "$tmp/binary.bin" "$tmp/utf16le-nobom-key.txt" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && grep -q "RESULT: MANUAL" <<< "$out" && grep -q "RESULT: BLOCK" <<< "$out"; then
  pass=$((pass + 1)); echo "ok   binary.bin + utf16le-nobom-key.txt → exit 1, MANUAL + BLOCK"
else
  fail=$((fail + 1)); echo "FAIL multi-file (want exit 1, MANUAL + BLOCK; got exit $rc)"
fi
# The fixture's street address is still reported after the CP1251 decode.
if bash "$scan" "$tmp/cp1251-address.txt" 2>&1 | grep -q "REVIEW street address"; then
  pass=$((pass + 1)); echo "ok   cp1251-address.txt → street address found after decoding"
else
  fail=$((fail + 1)); echo "FAIL cp1251-address.txt: street address not found after decoding"
fi

echo "Tests: $pass passed, $fail failed ($((pass + fail)))"
[ "$fail" -eq 0 ]
