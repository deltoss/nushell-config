# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Nushell configuration repository (`~/.config/nushell`). All files are written in Nushell's `.nu` language. The configuration targets both Windows and Linux OS. There are script paths gated behind `$nu.os-info.name` checks.

## Code Style

- 2-space indentation, spaces (not tabs), LF line endings, no trailing newline (see `.editorconfig`)
- Nushell language. This is not a POSIX shell. Use `^` prefix to call external commands (e.g., `^git`, `^fzf`)
- Interactive menus use a common pattern: print labeled options, `input listen --types [key]`, then `match [$key.code $key.modifiers]`

## Architecture

**Entry points:** Nushell loads `env.nu` first (environment variables, shell settings), then `config.nu` (sources everything else).

**`config.nu` load order:**
1. `keybinds.nu` — custom keybindings
2. `tools/tools.nu` — external tool integrations (`source` for env-modifying tools, `use` for command-providing tools)
3. `custom-completions/custom-completions.nu` — tab completions from `nu_scripts` subtree + local completions
4. `custom-commands/` — user-facing commands loaded via `mod.nu` as modules
5. `sourced/sourced.nu` — zoxide override, worktrunk helpers
6. `aliases/aliases.nu` — git aliases + git-wt alias

**Key distinction — `tools/` vs `custom-commands/`:**
- `tools/` wraps external CLI tools and sets up their environment. These are loaded via `source` (for env vars) or `use` (for commands).
- `custom-commands/` contains user-facing workflow commands organized as Nushell modules (loaded via `mod.nu`). Each `.nu` file is a module. Helper files not exported in `mod.nu` are internal.

**`nu_scripts/` is a git subtree** from [nushell/nu_scripts](https://github.com/nushell/nu_scripts). Do not edit files in this directory. For more information including how to update, see [README](./README.md) file

**Environment secrets:** `.env.json` (gitignored) provides sensitive environment variables that's not in source control. Template is in `.env.json.template`.

## Worktree Workflow

Two parallel worktree systems exist:
1. **`custom-commands/worktree.nu`** — Pure Nushell implementation with fzf-based selection (list/select/change/add/remove). The idea is it'd be a faster implementation for trivial and simple tasks for git worktrees.
2. **`tools/git-wt.nu`** — Shell integration for the `git-wt` (worktrunk) external binary with directive-file-based cd. Aliased as `wt`.
3. **`tools/worktrunk.nu`** — Convenience commands that combine both systems. Has custom Nushell commands to integrate AI with worktrunk