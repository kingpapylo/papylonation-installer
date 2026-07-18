#!/usr/bin/env bash
# =====================================================================
#  PapyloNation Agent — SOURCE installer (installs your renamed fork)
#  Cross-platform: plain Linux AND Termux (Android/Proot).
#  Builds from github.com/kingpapylo/papylonation-agent so the native
#  CLI command is `papylonation` (deep source rebrand, not a skin).
#  Usage:
#    curl -fsSL <URL>/install-from-source.sh | bash
# =====================================================================
set -euo pipefail

REPO="${PAPYLO_REPO:-https://github.com/kingpapylo/papylonation-agent.git}"
BRANCH="${PAPYLO_BRANCH:-main}"
BRAND="PapyloNation Agent"
PORT="${PAPYLO_PORT:-9119}"
HOST="127.0.0.1"

say() { printf '\033[1;33m⚕ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

say "Installing $BRAND from source ($REPO @ $BRANCH)"

# ---- 0) Platform detection -------------------------------------------
IS_TERMUX=0
if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX}/bin" ] && command -v termux-info >/dev/null 2>&1; then
  IS_TERMUX=1
fi

# Install location (writable, no sudo needed)
if [ "$IS_TERMUX" -eq 1 ]; then
  say "Target: Termux (Android)"
  SRC="${PAPYLO_SRC:-$HOME/papylonation-agent}"
else
  say "Target: Linux"
  SRC="${PAPYLO_SRC:-$HOME/.local/lib/papylonation-agent}"
fi

# ---- 1) Dependencies -------------------------------------------------
say "Ensuring git + python ..."
if [ "$IS_TERMUX" -eq 1 ]; then
  pkg install -y git python 2>/dev/null || true
else
  command -v git >/dev/null 2>&1 || die "git not found — install it (e.g. apt install git) and re-run."
fi

# The fork's pyproject requires Python >=3.11,<3.14. Pick a compatible interpreter.
# Strategy: try explicit 3.13/3.12/3.11 on PATH; else check the bare python3 is in range;
# else fall back to uv (installing uv if needed) to provision a managed 3.13.
compat_py() {  # prints a python path whose version is >=3.11 and <3.14, or nothing
  local cand
  for cand in python3.13 python3.12 python3.11; do
    command -v "$cand" >/dev/null 2>&1 && { command -v "$cand"; return 0; }
  done
  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
      "$cand" - <<'PYCHK' 2>/dev/null && { command -v "$cand"; return 0; }
import sys
raise SystemExit(0 if (3,11) <= sys.version_info < (3,14) else 1)
PYCHK
    fi
  done
  return 1
}

PY="$(compat_py || true)"
if [ -z "$PY" ]; then
  say "No system Python in range 3.11–3.13 found — provisioning one via uv ..."
  if ! command -v uv >/dev/null 2>&1; then
    curl -fsSL https://astral.sh/uv/install.sh | sh 2>&1 | tail -3 || true
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  fi
  command -v uv >/dev/null 2>&1 || die "Could not obtain uv to provision Python 3.13. Install Python 3.11–3.13 manually and re-run."
  uv python install 3.13 2>&1 | tail -2 || true
  PY="$(uv python find 3.13 2>/dev/null)"
  [ -n "$PY" ] && [ -x "$PY" ] || die "uv failed to provide Python 3.13."
fi
say "Using interpreter: $PY ($("$PY" --version 2>&1))"

# ---- 2) Clone (or update) the source fork ----------------------------
if [ -d "$SRC/.git" ]; then
  say "Existing checkout at $SRC — updating ..."
  git -C "$SRC" fetch origin "$BRANCH" --depth 1 2>&1 | tail -2 || true
  git -C "$SRC" checkout "$BRANCH" 2>/dev/null || true
  git -C "$SRC" reset --hard "origin/$BRANCH" 2>&1 | tail -1 || true
else
  say "Cloning into $SRC ..."
  mkdir -p "$(dirname "$SRC")"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$SRC" 2>&1 | tail -3
fi
[ -f "$SRC/pyproject.toml" ] || die "Clone incomplete: $SRC/pyproject.toml missing."

# ---- 3) Virtualenv + editable install --------------------------------
say "Creating venv + installing (this can take a few minutes) ..."
cd "$SRC"
# Recreate venv if missing or built with an out-of-range Python.
NEED_VENV=1
if [ -x venv/bin/python ]; then
  if venv/bin/python - <<'PYCHK' 2>/dev/null
import sys
raise SystemExit(0 if (3,11) <= sys.version_info < (3,14) else 1)
PYCHK
  then NEED_VENV=0; fi
fi
if [ "$NEED_VENV" -eq 1 ]; then
  rm -rf venv
  "$PY" -m venv venv
fi
# shellcheck disable=SC1091
. venv/bin/activate
python -m pip install -q --upgrade pip 2>&1 | tail -1 || true
# Deep-renamed fork ships prebuilt web_dist/tui_dist, so no node build needed.
python -m pip install -e . 2>&1 | tail -5 || die "pip install failed — see output above."

# ---- 4) Verify the native CLI ----------------------------------------
BIN="$SRC/venv/bin/papylonation"
[ -x "$BIN" ] || BIN="$SRC/venv/bin/hermes"   # alias fallback
VER="$("$BIN" --version 2>&1)" || die "CLI did not boot."
printf '%s\n' "$VER" | head -1

# ---- 5) Symlink onto PATH --------------------------------------------
if [ "$IS_TERMUX" -eq 1 ]; then LINKDIR="$PREFIX/bin"; else LINKDIR="$HOME/.local/bin"; fi
mkdir -p "$LINKDIR"
ln -sf "$SRC/venv/bin/papylonation" "$LINKDIR/papylonation" 2>/dev/null || true
ln -sf "$SRC/venv/bin/hermes"       "$LINKDIR/hermes" 2>/dev/null || true
case ":$PATH:" in *":$LINKDIR:"*) : ;; *) export PATH="$LINKDIR:$PATH" ;; esac

# ---- 6) Config: TUI + self-improvement + auto-backup -----------------
say "Configuring (TUI, curator, memory, dashboard) ..."
pc() { "$BIN" config set "$@" >/dev/null 2>&1 || true; }
pc display.interface tui
pc curator.enabled true
pc curator.backup.enabled true
pc memory.memory_enabled true
pc sessions.write_json_snapshots true
pc checkpoints.enabled true
pc dashboard.port "$PORT"
pc dashboard.host "$HOST"

# ---- 7) Persistent auto-restarting dashboard launcher ----------------
LAUNCH="$SRC/start-dashboard.sh"
cat > "$LAUNCH" <<DASH
#!/usr/bin/env bash
BIN="$SRC/venv/bin/papylonation"
if curl -s -o /dev/null "http://$HOST:$PORT/" 2>/dev/null; then
  echo "$BRAND dashboard already live -> http://$HOST:$PORT"; exit 0
fi
nohup bash -c 'while true; do "$BIN" dashboard --no-open --port $PORT --host $HOST >> "$SRC/dashboard.log" 2>&1; echo "[watchdog] restart in 3s" >> "$SRC/dashboard.log"; sleep 3; done' >/dev/null 2>&1 &
echo "$BRAND dashboard -> http://$HOST:$PORT (PID \$!)"
DASH
chmod +x "$LAUNCH"

# ---- 8) Auto-start on login ------------------------------------------
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  [ -f "$rc" ] || touch "$rc"
  if ! grep -qF "$LAUNCH" "$rc" 2>/dev/null; then
    echo "[ -f \"$LAUNCH\" ] && bash \"$LAUNCH\" >/dev/null 2>&1" >> "$rc"
  fi
done

say "Done. $BRAND installed from source at: $SRC"
say "Launch the agent:     papylonation"
say "Start dashboard:      bash $LAUNCH"
say "Dashboard URL:        http://$HOST:$PORT"
say "(If 'papylonation' isn't found, open a new shell or: export PATH=\"$LINKDIR:\$PATH\")"
