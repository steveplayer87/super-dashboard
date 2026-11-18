#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ ! -t 0 ]; then
  echo "Run this script from an interactive terminal so the key is entered without echo." >&2
  exit 1
fi
restore_echo() { stty echo 2>/dev/null || true; }
trap restore_echo EXIT HUP INT TERM
printf 'CWA API key (input hidden): '
stty -echo
IFS= read -r CWA_KEY
restore_echo
printf '\n'
if [ -z "$CWA_KEY" ]; then
  echo "No key entered; Cloudflare secret was not changed." >&2
  exit 1
fi
printf '%s' "$CWA_KEY" | npx --yes wrangler@4 secret put CWA_API_KEY
unset CWA_KEY
