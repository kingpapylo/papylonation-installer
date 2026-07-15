# PapyloNation Agent

A free, self-improving AI agent you can brand as your own. Built on [Hermes Agent](https://github.com/NousResearch/hermes-agent) (MIT license), rebranded as **PapyloNation Agent**.

## What it does

- Runs tasks and executes shell commands autonomously
- Uses `SKILL.md` skills natively (and creates/stores them as it learns)
- Self-improves: curator + persistent memory + auto-backup
- Ships a live web dashboard with a Skill Store and App Store
- MIT licensed upstream — rebrand freely for personal use

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/papylonation-installer/main/install-papylonation.sh | bash
```

Replace `YOUR_USER` with your GitHub username after pushing this repo.
Until then, run it from a local copy:

```bash
bash install-papylonation.sh
```

## What the installer sets up

1. Installs Hermes core if missing (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`)
2. Creates a branded `papylonation` profile + `SOUL.md` identity
3. Configures TUI, self-improvement (curator), memory, auto-backup, checkpoints
4. Installs a persistent auto-restarting dashboard on http://127.0.0.1:9119
5. Seeds the `self-improvement-loop` skill
6. Wires auto-start into your shell login

After install, launch with:

```bash
papylonation            # the agent (TUI)
papylonation dashboard  # or open http://127.0.0.1:9119
```

## Surviving `hermes update`

`hermes update` overwrites the source-level rebrand (CLI banner, dashboard title, store labels). After any update, re-apply branding:

```bash
bash restore-branding.sh
```

This is idempotent — safe to run repeatedly. It patches the source strings and rebuilds the dashboard bundle.

## Android / Termux auto-start

If you run this on Termux, install the **Termux:Boot** app, then copy the boot script so it starts on device boot:

```bash
mkdir -p ~/.termux/boot
# place start-papylonation.sh there (chmod 700) — it starts the dashboard + installer server
```

## Files

| File | Purpose |
|------|---------|
| `install-papylonation.sh` | One-line installer that reproduces the full branded agent |
| `restore-branding.sh` | Re-applies source-level rebrand after `hermes update` |

## License

Agent core: MIT (Hermes Agent, Nous Research). This rebrand wrapper: MIT, do what you like.
