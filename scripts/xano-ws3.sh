#!/usr/bin/env bash
# Runs a Xano CLI command against Marketing Engine workspace 3 only.
# Refuses to run unless workspace 3's immutable fingerprint matches, and always appends -w 3.
# Usage: scripts/xano-ws3.sh <xano subcommand...>   e.g. scripts/xano-ws3.sh workspace push -b v1 -d xano --dry-run
set -euo pipefail
unset XANO_PROFILE
EXPECTED='3|Marketing engine|2026-10-29 09:28:04+0000'
for a in "$@"; do
  case "$a" in -w|--workspace|--workspace=*|-p|--profile|--profile=*) echo "xano-ws3: do not pass $a; workspace 3 is fixed" >&2; exit 2;; esac
done
actual=$(xano workspace get -w 3 -o json | python3 -c 'import sys,json;d=json.load(sys.stdin);print("|".join(str(d[k]) for k in ("id","name","created_at")))')
if [ "$actual" != "$EXPECTED" ]; then echo "xano-ws3: workspace fingerprint mismatch: $actual" >&2; exit 3; fi
exec xano "$@" -w 3
