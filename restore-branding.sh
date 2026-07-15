#!/usr/bin/env bash
# =====================================================================
#  PapyloNation Agent — restore branding after a Hermes update
#  Re-applies all source edits that `hermes update` may overwrite:
#    - CLI banner logo + version label + footer
#    - "not configured" / setup guidance strings
#    - Dashboard frontend: brand + "Skill Store" + "App Store"
#  Then rebuilds the web bundle. Idempotent — safe to run repeatedly.
#  Usage:  bash ~/.hermes/profiles/papylonation/restore-branding.sh
# =====================================================================
set -euo pipefail

# Source root: prefer explicit override, else parse from `hermes --version`
# (cross-platform: Termux installs under $PREFIX, Linux under /usr/local/lib, etc.)
if [ -n "${HERMES_SRC:-}" ] && [ -d "$HERMES_SRC" ]; then
  SRC="$HERMES_SRC"
else
  SRC="$(hermes --version 2>/dev/null | grep -i 'Install directory:' | sed 's/.*Install directory:[[:space:]]*//' | head -1)"
fi
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "ERROR: could not locate Hermes install dir. Set HERMES_SRC=/path and re-run." >&2
  exit 1
fi
# venv python (used for the banner-label verify step)
PYBIN="$SRC/venv/bin/python"
[ -x "$PYBIN" ] || PYBIN="python3"
# node/npx for the web rebuild
NX="npx"
command -v npx >/dev/null 2>&1 || NX="node_modules/.bin/vite"
say() { printf '\033[1;33m⚕ %s\033[0m\n' "$*"; }
repl() { # file  old  new   (only replaces if old still present)
  local f="$1" o="$2" n="$3"
  if grep -qF "$o" "$f" 2>/dev/null; then
    python3 - "$f" "$o" "$n" <<'PY'
import sys
f,o,n=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(f,encoding="utf-8").read()
open(f,"w",encoding="utf-8").write(s.replace(o,n))
print("  patched:",f)
PY
  else
    echo "  already branded (or string moved):  $f"
  fi
}

say "Restoring PapyloNation branding in $SRC ..."

# 1) CLI banner version label
repl "$SRC/hermes_cli/banner.py" \
  'base = f"Hermes Agent v{VERSION} ({RELEASE_DATE})"' \
  'base = f"PapyloNation Agent v{VERSION} ({RELEASE_DATE})"'

# 2) CLI "not configured" message
repl "$SRC/hermes_cli/main.py" \
  "It looks like Hermes isn't configured yet" \
  "It looks like PapyloNation Agent isn't configured yet"

# 3) Setup guidance strings
repl "$SRC/hermes_cli/setup.py" \
  "⚕ Hermes Setup — Non-interactive mode" \
  "⚕ PapyloNation Agent Setup — Non-interactive mode"
repl "$SRC/hermes_cli/setup.py" \
  "Configure Hermes using environment variables or config commands:" \
  "Configure PapyloNation Agent using environment variables or config commands:"

# 4a) Dashboard HTML <title> (static template, not in i18n)
repl "$SRC/web/index.html" \
  '<title>Hermes Agent - Dashboard</title>' \
  '<title>PapyloNation Agent - Dashboard</title>'

# 4b) Dashboard frontend — brand + store page labels
repl "$SRC/web/src/i18n/en.ts" 'brand: "Hermes Agent",' 'brand: "PapyloNation Agent",'
repl "$SRC/web/src/i18n/en.ts" 'brandShort: "HA",'       'brandShort: "PN",'
repl "$SRC/web/src/i18n/en.ts" '      skills: "Skills",'  '      skills: "Skill Store",'
repl "$SRC/web/src/App.tsx" \
  '{ path: "/skills", labelKey: "skills", label: "Skills", icon: Package },' \
  '{ path: "/skills", labelKey: "skills", label: "Skill Store", icon: Package },'
repl "$SRC/web/src/App.tsx" \
  '{ path: "/mcp", label: "MCP", icon: Plug },' \
  '{ path: "/mcp", label: "App Store", icon: Plug },'

# 5) Rebuild the web bundle so the dashboard serves the rebrand.
#    Tolerant: skip (don't fail the script) if the node/npx toolchain is missing.
say "Rebuilding dashboard bundle ..."
if command -v npx >/dev/null 2>&1 || [ -x "$SRC/web/node_modules/.bin/vite" ]; then
  ( cd "$SRC/web" && $NX vite build ) && say "Dashboard rebuilt." \
    || say "⚠ build exited non-zero — bundle may be stale; re-run restore-branding.sh later."
else
  say "⚠ npx not found — skipped bundle rebuild. Dashboard serves the prebuilt bundle; re-run after installing node."
fi

# 6) Verify banner label is branded
if "$PYBIN" -c "from hermes_cli import banner; print(banner.format_banner_version_label())" 2>/dev/null | grep -q "PapyloNation Agent"; then
  say "✓ CLI banner shows PapyloNation Agent"
else
  say "⚠ Could not confirm CLI banner label — check manually"
fi

say "Done. Restart the dashboard:  bash ~/.hermes/profiles/papylonation/start-dashboard.sh"
