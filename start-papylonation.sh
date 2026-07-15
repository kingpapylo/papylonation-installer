#!/usr/bin/env bash
# PapyloNation Agent — boot script for Termux:Boot.
# Termux:Boot runs every executable in ~/.termux/boot/ at device boot.
# Starts: (1) the live dashboard, (2) the installer HTTP server (:8080).
# Designed to be idempotent — skips anything already running.

export HOME=/data/data/com.termux/files/home
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
