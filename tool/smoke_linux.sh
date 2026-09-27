#!/usr/bin/env bash
set -euo pipefail

exe="$(realpath "${1:?executable required}")"
[[ -x "$exe" ]] || { echo "Not executable: $exe" >&2; exit 1; }
work="$(mktemp -d)"
export XDG_DATA_HOME="$work/data"
export XDG_CACHE_HOME="$work/cache"
export XDG_CONFIG_HOME="$work/config"
pid=""
cleanup() {
  if [[ -n "$pid" ]]; then
    kill -- "-$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT
setsid dbus-run-session -- xvfb-run -a "$exe" >"$work/console.log" 2>&1 &
pid=$!
log="$XDG_DATA_HOME/MiriaGo/logs/startup.log"
for ((attempt = 0; attempt < 90; attempt++)); do
  if [[ -f "$log" ]] && grep -q 'Flutter first page displayed' "$log"; then
    sleep 3
    if kill -0 "$pid" 2>/dev/null && [[ -s "$XDG_DATA_HOME/MiriaGo/miriago.sqlite" ]] && ! grep -Eqi 'startup failed|launcher stopped with error|web bootstrap:' "$log"; then
      cat "$log"
      echo "Linux frontend startup smoke passed"
      exit 0
    fi
    break
  fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
cat "$work/console.log" >&2
[[ ! -f "$log" ]] || cat "$log" >&2
echo "Linux frontend did not start successfully" >&2
exit 1
