#!/usr/bin/env bash
# =====================================================================
#  PapyloNation Agent — one-line installer
#  Usage:  curl -fsSL <URL>/install-papylonation.sh | bash
#  Reproduces the full branded, self-improving agent + live dashboard.
# =====================================================================
set -euo pipefail

PROFILE="papylonation"
BRAND="PapyloNation Agent"
PORT="${PAPYLO_PORT:-9119}"
HOST="127.0.0.1"

say() { printf '\033[1;33m⚕ %s\033[0m\n' "$*"; }

say "Installing $BRAND ..."

# 1) Ensure Hermes Agent is installed
if ! command -v hermes >/dev/null 2>&1; then
  say "Hermes core not found — installing..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi

# 2) Create the branded profile (idempotent)
if ! hermes profile list 2>/dev/null | grep -q "$PROFILE"; then
  say "Creating profile '$PROFILE'..."
  hermes profile create "$PROFILE"
fi

HH="$HOME/.hermes/profiles/$PROFILE"
export HERMES_HOME="$HH"
WRAP="$HOME/.local/bin/$PROFILE"

# 3) Identity (SOUL.md)
cat > "$HH/SOUL.md" <<'SOUL'
# PapyloNation Agent
You are **PapyloNation Agent**, an autonomous AI assistant.
- Runs tasks, executes shell commands, uses SKILL.md skills natively.
- Self-improves: when you solve something hard or lack a skill, CREATE the
  skill, use it, and STORE it for reuse. If an existing skill is wrong, patch it.
- On errors: diagnose and fix automatically before asking the user.
- Be direct and capable; do the work, then report. Never fabricate results.
SOUL

# 4) Config: TUI + self-improvement + auto-save + auto-backup + connectors
"$PROFILE" config set display.interface tui              >/dev/null 2>&1 || hermes config set display.interface tui
"$PROFILE" config set curator.enabled true               >/dev/null 2>&1 || true
"$PROFILE" config set curator.backup.enabled true        >/dev/null 2>&1 || true
"$PROFILE" config set memory.memory_enabled true         >/dev/null 2>&1 || true
"$PROFILE" config set sessions.write_json_snapshots true >/dev/null 2>&1 || true
"$PROFILE" config set checkpoints.enabled true           >/dev/null 2>&1 || true
"$PROFILE" config set dashboard.port "$PORT"             >/dev/null 2>&1 || true
"$PROFILE" config set dashboard.host "$HOST"             >/dev/null 2>&1 || true

# 5) Persistent auto-restarting dashboard launcher
cat > "$HH/start-dashboard.sh" <<DASH
#!/usr/bin/env bash
export HERMES_HOME="$HH"
if curl -s -o /dev/null "http://$HOST:$PORT/" 2>/dev/null; then
  echo "$BRAND dashboard already live → http://$HOST:$PORT"; exit 0
fi
nohup bash -c 'export HERMES_HOME="$HH"
  while true; do "$PROFILE" dashboard --no-open --port $PORT --host $HOST >> "$HH/dashboard.log" 2>&1
    echo "[watchdog] restart in 3s" >> "$HH/dashboard.log"; sleep 3; done' >/dev/null 2>&1 &
echo "$BRAND dashboard → http://$HOST:$PORT (PID \$!)"
DASH
chmod +x "$HH/start-dashboard.sh"

# 6) Auto-start dashboard on shell login
GREP_LINE="$HH/start-dashboard.sh"
if ! grep -qF "$GREP_LINE" "$HOME/.bashrc" 2>/dev/null; then
  echo "[ -f \"$GREP_LINE\" ] && bash \"$GREP_LINE\" >/dev/null 2>&1" >> "$HOME/.bashrc"
fi

# 7) Seed the self-improvement skill
mkdir -p "$HH/skills/self-improvement/self-improvement-loop"
cat > "$HH/skills/self-improvement/self-improvement-loop/SKILL.md" <<'SK'
---
name: self-improvement-loop
description: "After any non-trivial task, capture the lesson as a skill or memory so the agent improves. If a needed skill is missing, create it, use it, and store it for reuse."
version: 1.0.0
---
# Self-Improvement Loop
1. Reflect on what worked. 2. Save reusable procedures as skills, stable facts to memory.
3. If a needed skill does not exist, CREATE it, use it, and store it. 4. Patch wrong/stale skills immediately.
On errors: diagnose and fix automatically, then record the fix as a skill.
SK

say "Done. Launch the agent:   $PROFILE"
say "Start live dashboard:     bash $HH/start-dashboard.sh"
say "Dashboard URL:            http://$HOST:$PORT"
