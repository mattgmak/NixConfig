#!/usr/bin/env bash
set -euo pipefail

bundle="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
names=("Comodo AAA Services root" "emSign ECC Root CA - G3")
hosts=(dv-g3b-emudhra.we-have-a-problem.com dv-g3b-aaa-emudhra.we-have-a-problem.com)

fails=0
skips=0

# The bundle keeps the alias line and marks trust in the text below it.
check_name() {
  local name="$1" out
  out=$(awk -v name="$name" '
    function is_alias(l) {
      if (l == "") return 0
      if (l ~ /^[ \t]/ || l ~ /^---/) return 0
      if (l == "Trusted for:" || l == "Rejected for:") return 0
      if (l ~ /^Traditional PEM block omitted:/) return 0
      return 1
    }
    function verdict() {
      if ((rej && oid) || omit) return "PASS"
      return "FAIL"
    }
    is_alias($0) {
      if (in_entry) { print verdict(); in_entry = 0; exit }
      in_entry = ($0 == name)
      next
    }
    in_entry {
      if ($0 == "Rejected for:") rej = 1
      if ($0 ~ /^Traditional PEM block omitted:/) omit = 1
      if ($0 ~ /1\.3\.6\.1\.5\.5\.7\.3\.1/) oid = 1
    }
    END { if (in_entry) print verdict() }
  ' "$bundle")
  case "$out" in
    PASS) echo "PASS $name not trusted for servers" ;;
    FAIL) echo "FAIL $name still trusted for servers"; fails=$((fails + 1)) ;;
    "")   echo "PASS $name not in bundle" ;;
    *)    echo "FAIL $name unknown entry state"; fails=$((fails + 1)) ;;
  esac
}

echo "Bundle: $bundle"
if [[ -f "$bundle" ]]; then
  for name in "${names[@]}"; do
    check_name "$name"
  done
else
  echo "FAIL bundle not found"
  fails=$((fails + 1))
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP online check: curl not found"
  skips=$((skips + 1))
else
  for host in "${hosts[@]}"; do
    code=0
    curl -sS -o /dev/null --max-time 10 "https://$host/" || code=$?
    # Exit 60 = peer certificate cannot be authenticated.
    case "$code" in
      60) echo "PASS $host rejects the compromised chain" ;;
      0)  echo "FAIL $host trusts the compromised chain"; fails=$((fails + 1)) ;;
      *)  echo "SKIP $host got curl exit $code"; skips=$((skips + 1)) ;;
    esac
  done
fi

echo "Summary: $fails failure(s), $skips skip(s)"
if ((fails > 0)); then
  exit 1
fi
exit 0
