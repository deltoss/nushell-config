# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Nushell configuration for Windows and Linux.

## Code Style

- Follow [.editorconfig](./.editorconfig) for formatting.
- Use Nushell syntax. Prefix intended external commands with `^` to avoid invoking wrappers.
- Follow the surrounding code and reuse existing helpers.
- Keep command help and examples beside their `.nu` definitions. Avoid duplicating command lists, keybindings, load order, or credential settings in Markdown.

## Architecture

Read [env.nu](./env.nu) and [config.nu](./config.nu) for startup behavior and load order.

- Put user-facing workflows in [custom-commands/](./custom-commands/); check its module exports before changing public commands.
- Keep tool integrations and reusable helpers in [tools/](./tools/).
- Read [secretspec.toml](./secretspec.toml) and [tools/secretspec.nu](./tools/secretspec.nu) for credential configuration and lookup.
- See [autoload/](./autoload/) for user autoload scripts.

[nu_scripts/](./nu_scripts/) is a vendored git subtree. Do not edit it directly.
See [README.md](./README.md) for the update procedure.