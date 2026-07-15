#!/usr/bin/env bash
# =====================================================================
#  PapyloNation Agent — one-line installer (cross-platform)
#  Works on plain Linux AND Termux (Android).
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

# ---- 0) Platform detection -------------------------------------------
IS_TERMUX=0
if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX}/bin" ] && command -v termux-info >/dev/null 2>&1; then
  IS_TERMUX=1
fi
if [ "$IS_TERMUX" -eq 1 ]; then
  say "Target: Termux (Android)"
else
  say "Target: Linux"
fi

# ---- 1) Ensure Hermes Agent core is installed ------------------------
if ! command -v hermes >/dev/null 2>&1; then
  say "Hermes core not found — installing..."
  if [ "$IS_TERMUX" -eq 1 ]; then
    pkg install -y python git 2>/dev/null || true
    pip install hermes-agent 2>&1 | tail -5 || \
      (curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash)
  else
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  fi
  export PATH="$HOME/.local/bin:$PREFIX/bin:$PATH"
fi

# Source root of the hermes install (cross-platform: parsed from `hermes --version`)
SRC="$(hermes --version 2>/dev/null | grep -i 'Install directory:' | sed 's/.*Install directory:[[:space:]]*//' | head -1)"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  say "⚠ Could not auto-detect Hermes source dir; set HERMES_SRC and re-run restore-branding.sh later."
  SRC="${HERMES_SRC:-/usr/local/lib/hermes-agent}"
fi

# ---- 2) Create the branded profile (idempotent) ----------------------
if ! hermes profile list 2>/dev/null | grep -q "$PROFILE"; then
  say "Creating profile '$PROFILE'..."
  hermes profile create "$PROFILE"
fi

HH="$HOME/.hermes/profiles/$PROFILE"
export HERMES_HOME="$HH"
mkdir -p "$HH"

# ---- 3) Identity (SOUL.md) -------------------------------------------
cat > "$HH/SOUL.md" <<'SOUL'
# PapyloNation Agent
You are **PapyloNation Agent**, an autonomous AI assistant.
- Runs tasks, executes shell commands, uses SKILL.md skills natively.
- Self-improves: when you solve something hard or lack a skill, CREATE the
  skill, use it, and STORE it for reuse. If an existing skill is wrong, patch it.
- On errors: diagnose and fix automatically before asking the user.
- Be direct and capable; do the work, then report. Never fabricate results.
SOUL

# ---- 4) Config: TUI + self-improvement + auto-save + auto-backup ----
papylonation() { hermes -p "$PROFILE" "$@"; }
papylonation config set display.interface tui              >/dev/null 2>&1 || hermes config set display.interface tui
papylonation config set curator.enabled true               >/dev/null 2>&1 || true
papylonation config set curator.backup.enabled true        >/dev/null 2>&1 || true
papylonation config set memory.memory_enabled true         >/dev/null 2>&1 || true
papylonation config set sessions.write_json_snapshots true >/dev/null 2>&1 || true
papylonation config set checkpoints.enabled true           >/dev/null 2>&1 || true
papylonation config set dashboard.port "$PORT"             >/dev/null 2>&1 || true
papylonation config set dashboard.host "$HOST"             >/dev/null 2>&1 || true

# ---- 5) Wrapper script (cross-platform: let hermes place it) ---------
if ! command -v papylonation >/dev/null 2>&1; then
  say "Creating 'papylonation' command..."
  hermes profile alias "$PROFILE" --name papylonation 2>&1 | tail -2 || \
    hermes profile alias "$PROFILE" 2>&1 | tail -2
  export PATH="$HOME/.local/bin:$PREFIX/bin:$PATH"
fi

# ---- 6) Persistent auto-restarting dashboard launcher ----------------
cat > "$HH/start-dashboard.sh" <<DASH
#!/usr/bin/env bash
export HERMES_HOME="$HH"
if curl -s -o /dev/null "http://$HOST:$PORT/" 2>/dev/null; then
  echo "$BRAND dashboard already live -> http://$HOST:$PORT"; exit 0
fi
nohup bash -c 'export HERMES_HOME="$HH"
  while true; do papylonation dashboard --no-open --port $PORT --host $HOST >> "$HH/dashboard.log" 2>&1
    echo "[watchdog] restart in 3s" >> "$HH/dashboard.log"; sleep 3; done' >/dev/null 2>&1 &
echo "$BRAND dashboard -> http://$HOST:$PORT (PID \$!)"
DASH
chmod +x "$HH/start-dashboard.sh"

# ---- 7) Auto-start on login (works on both: .bashrc / .profile) ------
GREP_LINE="$HH/start-dashboard.sh"
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  if [ -f "$rc" ] && ! grep -qF "$GREP_LINE" "$rc" 2>/dev/null; then
    echo "[ -f \"$GREP_LINE\" ] && bash \"$GREP_LINE\" >/dev/null 2>&1" >> "$rc"
  fi
done

# ---- 8) Seed the self-improvement skill ------------------------------
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

# ---- 9) Apply source-level rebrand (CLI banner + dashboard) ----------
# Fetch restore-branding.sh from the repo if not carried alongside, then run it.
# This patches the Hermes source strings and rebuilds the dashboard bundle so a
# fresh install is fully branded without a manual step. Tolerates a missing
# node toolchain (restore-branding.sh skips the rebuild in that case).
REPO_RAW="https://raw.githubusercontent.com/kingpapylo/papylonation-installer/main"
RESTORE_LOCAL="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/restore-branding.sh"
if [ ! -f "$RESTORE_LOCAL" ]; then
  RESTORE_LOCAL="$HH/restore-branding.sh"
  curl -fsSL "$REPO_RAW/restore-branding.sh" -o "$RESTORE_LOCAL" 2>/dev/null \
    || curl -fsSL "https://raw.githubusercontent.com/kingpapylo/papylonation-installer/main/restore-branding.sh" -o "$RESTORE_LOCAL" 2>/dev/null \
    || true
fi
if [ -f "$RESTORE_LOCAL" ]; then
  chmod +x "$RESTORE_LOCAL"
  cp "$RESTORE_LOCAL" "$HH/restore-branding.sh" 2>/dev/null || true
  say "Applying PapyloNation source rebrand (CLI + dashboard) ..."
  bash "$RESTORE_LOCAL" 2>&1 | sed 's/^/    /' || \
    say "⚠ rebrand step reported issues — run: bash $HH/restore-branding.sh"
else
  say "⚠ restore-branding.sh not found — skipping source rebrand. Run it manually later."
fi

say "Done. Launch the agent:   papylonation"
say "Start live dashboard:     bash $HH/start-dashboard.sh"
say "Dashboard URL:            http://$HOST:$PORT"
