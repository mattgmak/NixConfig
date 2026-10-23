#!/usr/bin/env bash
set -euo pipefail

bundle="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
names=("Comodo AAA Services root" "emSign ECC Root CA - G3")
hosts=(dv-g3b-emudhra.we-have-a-problem.com dv-g3b-aaa-emudhra.we-have-a-problem.com)

fails=0
skips=0
gaps=0

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

# Apple keeps its own store under different names; do not fold them into names[].
apple=/etc/ssl/cert.pem
apple_names=("CN=AAA Certificate Services" "CN=emSign ECC Root CA - G3")
if [[ -f "$apple" ]]; then
  echo "Apple store: $apple"
  for name in "${apple_names[@]}"; do
    if grep -qF "$name" "$apple"; then
      echo "FAIL $apple still holds $name"
      fails=$((fails + 1))
    else
      echo "PASS $apple lacks $name"
    fi
  done
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

# Stable bun trusts the emudhra leaf. The fix exists only on bun main after ea6a2c7.
if ! command -v bun >/dev/null 2>&1; then
  echo "SKIP online check: bun not found"
  skips=$((skips + 1))
else
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp:-}"' EXIT
  cat > "$tmp/probe.mjs" <<'JS'
const hosts = [
  "dv-g3b-emudhra.we-have-a-problem.com",
  "dv-g3b-aaa-emudhra.we-have-a-problem.com",
]
for (const host of hosts) {
  try {
    await fetch(`https://${host}/`, { signal: AbortSignal.timeout(10000) })
    console.log(`TRUST ${host}`)
  } catch {
    console.log(`REFUSE ${host}`)
  }
}
JS
  out=$(bun "$tmp/probe.mjs" 2>/dev/null) || true
  if [[ -z "$out" ]]; then
    echo "SKIP bun probe gave no output"
    skips=$((skips + 1))
  else
    while read -r verdict host; do
      case "$verdict" in
        REFUSE) echo "PASS bun rejects $host" ;;
        TRUST)  echo "GAP bun trusts $host"; gaps=$((gaps + 1)) ;;
        *)      echo "SKIP bun probe got $verdict"; skips=$((skips + 1)) ;;
      esac
    done <<< "$out"
  fi
fi

# Node ships its own roots, so the bundle state above does not reach it.
if ! command -v node >/dev/null 2>&1; then
  echo "SKIP online check: node not found"
  skips=$((skips + 1))
else
  tmp=${tmp:-$(mktemp -d)}
  trap 'rm -rf "${tmp:-}"' EXIT
  cat > "$tmp/probe.js" <<'JS'
const hosts = [
  "dv-g3b-emudhra.we-have-a-problem.com",
  "dv-g3b-aaa-emudhra.we-have-a-problem.com",
]
;(async () => {
  for (const host of hosts) {
    try {
      const res = await fetch(`https://${host}/`, { signal: AbortSignal.timeout(10000) })
      console.log(`${res.status === 200 ? "TRUST" : "OTHER"} ${host}`)
    } catch (err) {
      const cause = err.cause || {}
      const text = `${cause.code || ""} ${cause.message || ""} ${err.message || ""}`
      const tls = /TLS|x509|CERT|SSL|SELF_SIGNED|UNABLE_TO_VERIFY/i.test(text)
      console.log(`${tls ? "REFUSE" : "OTHER"} ${host}`)
    }
  }
})()
JS
  out=$(node "$tmp/probe.js" 2>/dev/null) || true
  if [[ -z "$out" ]]; then
    echo "SKIP node probe gave no output"
    skips=$((skips + 1))
  else
    while read -r verdict host; do
      case "$verdict" in
        REFUSE) echo "PASS node rejects $host" ;;
        TRUST)  echo "GAP node trusts $host"; gaps=$((gaps + 1)) ;;
        *)      echo "SKIP node probe got $verdict"; skips=$((skips + 1)) ;;
      esac
    done <<< "$out"
  fi
fi

# uv reads the platform store only with --system-certs. It has no plain HTTPS
# request command, so this block reports the version and probes nothing.
if ! command -v uv >/dev/null 2>&1; then
  echo "SKIP online check: uv not found"
  skips=$((skips + 1))
else
  uv_version=$(uv --version 2>/dev/null) || uv_version=unknown
  echo "uv: $uv_version"
  echo "SKIP uv probe: no plain HTTPS request subcommand"
  skips=$((skips + 1))
fi

# The Apple python3 reads the Apple store. It has no CA flag, so it is the
# only probe that shows what /etc/ssl/cert.pem does on the wire.
if [[ ! -x /usr/bin/python3 ]]; then
  echo "SKIP online check: /usr/bin/python3 not found"
  skips=$((skips + 1))
else
  tmp=${tmp:-$(mktemp -d)}
  trap 'rm -rf "${tmp:-}"' EXIT
  cat > "$tmp/probe.py" <<'PY'
import ssl
import urllib.error
import urllib.request

HOSTS = [
    "dv-g3b-emudhra.we-have-a-problem.com",
    "dv-g3b-aaa-emudhra.we-have-a-problem.com",
]

for host in HOSTS:
    try:
        urllib.request.urlopen("https://" + host + "/", timeout=10)
        print("TRUST " + host)
    except urllib.error.URLError as exc:
        print(("REFUSE " if isinstance(exc.reason, ssl.SSLError) else "OTHER ") + host)
    except ssl.SSLError:
        print("REFUSE " + host)
    except Exception:
        print("OTHER " + host)
PY
  out=$(/usr/bin/python3 "$tmp/probe.py" 2>/dev/null) || true
  if [[ -z "$out" ]]; then
    echo "SKIP python probe gave no output"
    skips=$((skips + 1))
  else
    while read -r verdict host; do
      case "$verdict" in
        REFUSE) echo "PASS python rejects $host" ;;
        TRUST)  echo "GAP python trusts $host"; gaps=$((gaps + 1)) ;;
        *)      echo "SKIP python probe got $verdict"; skips=$((skips + 1)) ;;
      esac
    done <<< "$out"
  fi
fi

# The JKS store keeps alias names and subject strings as UTF-8, so a byte
# search is enough and keytool is not needed.
java_store=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home/lib/security/cacerts
if [[ ! -f "$java_store" ]]; then
  echo "SKIP java store not found: $java_store"
  skips=$((skips + 1))
elif [[ ! -r "$java_store" ]]; then
  echo "SKIP java store not readable: $java_store"
  skips=$((skips + 1))
else
  java_alias=(comodoaaaca emsigneccrootcag3)
  java_subject=("AAA Certificate Services" "emSign ECC Root CA - G3")
  java_total=0
  java_found=""
  for probe in "${java_alias[@]}" "${java_subject[@]}"; do
    # rg -c prints nothing at all when it finds no match.
    count=$(rg -a -c -F "$probe" "$java_store" 2>/dev/null || true)
    count=${count:-0}
    java_total=$((java_total + count))
    if ((count > 0)); then
      java_found+="$probe "
    fi
  done
  if ((java_total == 0)); then
    echo "PASS java store lacks both aliases"
  else
    echo "GAP java store still holds ${java_found% }"
    gaps=$((gaps + 1))
  fi
fi

# Go ships no root file and resolves trust through the OS store, so the probe is
# the only verdict.
if ! command -v go >/dev/null 2>&1; then
  echo "SKIP online check: go not found"
  skips=$((skips + 1))
else
  go_version=$(go version 2>/dev/null) || go_version="go version unknown"
  tmp=${tmp:-$(mktemp -d)}
  trap 'rm -rf "${tmp:-}"' EXIT
  mkdir -p "$tmp/go-cache" "$tmp/go-path"
  cat > "$tmp/main.go" <<'GO'
package main

import (
	"fmt"
	"net/http"
	"strings"
)

func main() {
	for _, host := range []string{
		"dv-g3b-emudhra.we-have-a-problem.com",
		"dv-g3b-aaa-emudhra.we-have-a-problem.com",
	} {
		res, err := http.Get("https://" + host + "/")
		if err != nil {
			text := strings.ToLower(err.Error())
			if strings.Contains(text, "tls") || strings.Contains(text, "x509") || strings.Contains(text, "certificate") {
				fmt.Printf("REFUSE %s\n", host)
			} else {
				fmt.Printf("OTHER %s\n", host)
			}
			continue
		}
		res.Body.Close()
		if res.StatusCode == http.StatusOK {
			fmt.Printf("TRUST %s\n", host)
		} else {
			fmt.Printf("OTHER %s\n", host)
		}
	}
}
GO
  out=$(cd "$tmp" && GOTOOLCHAIN=local GOFLAGS=-mod=mod \
    GOCACHE="$tmp/go-cache" GOPATH="$tmp/go-path" \
    go run main.go 2>/dev/null) || true
  if [[ -z "$out" ]]; then
    echo "SKIP go probe gave no output ($go_version)"
    skips=$((skips + 1))
  else
    while read -r verdict host; do
      case "$verdict" in
        REFUSE) echo "PASS go rejects $host ($go_version)" ;;
        TRUST)  echo "GAP go trusts $host ($go_version)"; gaps=$((gaps + 1)) ;;
        *)      echo "SKIP go probe got $verdict ($go_version)"; skips=$((skips + 1)) ;;
      esac
    done <<< "$out"
  fi
fi

echo "Summary: $fails failure(s), $skips skip(s), $gaps known gap(s)"
if ((fails > 0)); then
  exit 1
fi
exit 0
