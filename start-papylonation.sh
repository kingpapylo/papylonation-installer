#!/usr/bin/env bash
# PapyloNation Agent — boot script for Termux:Boot (and plain Linux if launched at boot).
# Termux:Boot runs every executable in ~/.termux/boot/ at device boot.
# Starts: (1) the live dashboard, (2) the installer HTTP server (:8080).
# Idempotent — skips anything already running.
# Cross-platform: resolves the real HOME so it works on Termux and Linux.

# On Termux, $HOME inside Termux:Boot is already the termux home; keep it.
# Fallback for environments where it isn't:
if [ -z "${HOME:-}" ] || [ ! -d "$HOME/.hermes" ]; then
  for cand in /data/data/com.termux/files/home "$HOME"; do
    [ -n "$cand" ] && [ -d "$cand/.hermes" ] && { HOME="$cand"; break; }
  done
fi
export HOME
PROFILE_HOME="$HOME/.hermes/profiles/papylonation"

start_if_down() {
  local url="$1"; shift
  if curl -s -o /dev/null --max-time 2 "$url"; then
    echo "[boot] already up: $url"
  else
    echo "[boot] starting: $*"
    nohup "$@" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

# 1) Live branded dashboard
start_if_down "http://127.0.0.1:9119/" bash "$PROFILE_HOME/start-dashboard.sh"

# 2) Installer one-liner server (so curl ...:8080/install-papylonation.sh works)
start_if_down "http://127.0.0.1:8080/install-papylonation.sh" \
  python3 -m http.server 8080 --bind 0.0.0.0 --directory "$HOME"

echo "[boot] PapyloNation Agent services checked."
