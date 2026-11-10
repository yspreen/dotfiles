---
name: dotfiles-sync
description: Use when asked to sync, persist, back up or check ~/dotfiles, or whether config, skills or apps on this Mac are missing from it. Finds config living outside the repo, pulls it in, sorts every uncommitted change into commit, leave or revert, and pushes.
---

`~/dotfiles` (github.com/yspreen/dotfiles) is the source of truth for this Mac. `scripts/install.sh` rebuilds a machine from it: nix-darwin (`nix/flake.nix`) installs brews, casks and Mac App Store apps, then `scripts/post-activation.sh` decrypts secrets, runs `stow --adopt .` and copies or links the rest.

**The repo is public.** Secrets and personal data (keys, tokens, addresses, account ids) go in `secrets/` or `scriptswithsecrets/`. Those are gitignored, and the pre-commit hook encrypts them into `.ssh_enc`. Never commit them in plaintext.

## How files reach $HOME

- **Stow links** (default): every repo path not matched by `.stow-local-ignore` is symlinked into `$HOME` at the same path. `~/.agents` links to the repo, so new skills land in the repo automatically (`~/.claude/skills` points at `~/.agents/skills`).
- **Explicit links** in `post-activation.sh`: `~/CLAUDE.md`, `~/.claude/keybindings.json`, `~/.codex/{config.toml,keybindings.json,AGENTS.md,hooks.json}`.
- **Copies.** These apps rewrite their files, which breaks symlinks, so the repo keeps copies. `scripts/copied-files.txt` lists live path and repo path. The pre-commit hook (`scripts/pre-commit.sh`) pulls them in, and `post-activation.sh` restores any that are missing. To track a new rewritten file, add a line there. If it can hold tokens, set its repo path under `secrets/`.
- **Claude user MCP servers** sit inside `~/.claude.json`, which is otherwise runtime state. The hook saves `.mcpServers` to `secrets/claude-mcp-servers.json`, and `post-activation.sh` merges them back.
- **Apps** come from `homebrew.casks`, `homebrew.brews` and `masApps` in `nix/flake.nix`. Activation runs `brew bundle --cleanup`, so a brew package missing from the flake gets **uninstalled** on the next rebuild. Add packages before rebuilding.

## Steps

1. **State.** `cd ~/dotfiles && git fetch -q && git status -sb`. Report unpushed commits and whether the branch is behind.
2. **Link drift.** `stow -n -v --ignore='\.DS_Store' .`
   - `LINK:` means a repo file with no link in `$HOME`. Usually that's junk that belongs in `.stow-local-ignore` or should leave the repo.
   - A conflict means an app replaced the symlink with a real file. Run `diff` against the repo copy, then `stow --adopt --ignore='\.DS_Store' .`. That moves the live file into the repo and relinks it. Review the result with `git diff`.
3. **Copies.** Run `scripts/pre-commit.sh`. It copies every file in `copied-files.txt`, saves the MCP servers and re-encrypts secrets. Then run `git diff`.
4. **Config living outside the repo.** Check each of these and report what's missing:
   - Apps: `ls /Applications ~/Applications | grep '\.app$'` vs `casks` and `masApps` in `nix/flake.nix`. Use `brew search --cask <name>` or `mas search <name>` to find a source. Apps with no source get listed for the user, not added.
   - Claude plugins: keys of `~/.claude/plugins/installed_plugins.json` vs `enabledPlugins` and `extraKnownMarketplaces` in `.claude/settings.json`.
   - Claude user MCP servers: `jq '.mcpServers' ~/.claude.json`. That file is mostly runtime state, so never commit it whole.
   - T3 Code: `~/.t3/userdata/{settings.json,client-settings.json,keybindings.json}`. Everything else there is state, logs or tokens.
   - `~/.config/*`, `~/Library/Application Support/*` and `~/Library/Preferences/*` entries that are real dirs, not links. Most are caches or credentials, so flag only hand-edited config.
5. **Classify every change** from `git status`: **commit**, **leave** (keep it local and uncommitted) or **revert/remove**. Give a one-line reason for each and show the list to the user. Revert or delete only after they say yes.
   - Commit: config, skills, scripts and flake changes the user made on purpose.
   - Leave or move to `secrets/`: anything personal or secret. A tracked file can't hold a local-only line, so move it to `secrets/` and reference it from there (CLAUDE.md files can import with `@path`).
   - Remove from the repo dir: migration leftovers, exports, archives, anything over 1 MB.
   - `.ssh_enc` changes on its own. The hook regenerates it on every commit, so it needs no decision.
6. **Secret scan** before staging:
   ```bash
   git diff HEAD; git ls-files -o --exclude-standard | xargs grep -nE 'sk-(ant|proj|live)[-_A-Za-z0-9]{16,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-|AIza[0-9A-Za-z_-]{30,}|BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
   ```
   Also read new files for personal data. Regex can't find an address.
7. **Commit and push.** Stage paths by name, never `git add -A`. Commit and push. The pre-commit hook re-encrypts `.ssh_enc` and adds it to the commit, which is expected. Then report the commit hash and anything you left uncommitted.
