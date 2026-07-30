---
name: nu-completions-generator
description: >
  Gen Nushell autocomplete files fer CLI tools by explore --help output.
  Use skill when user ask create/generate/write Nushell completions
  or tab completions fer CLI tool, or say "add completions for <tool>",
  "make <tool> autocomplete work in nushell", or "I want tab completion for <tool>".
  Also trigger when user mention gen `*-completions.nu` file.
---

# Nushell Completions Generator

Gen Nushell autocomplete files fer CLI tools by recursive explore `--help` output.

## Overview

Goal: make `.nu` file giv user rich tab-completion fer CLI tool in Nushell. File shud feel hand-craft — not raw help dump.

## Step 1: Discover the CLI tool's structure

Run `<tool> --help` (use `^` prefix fer external commands in Nushell) and parse output to find:
- **Subcommands** — names + one-line desc
- **Flags/options** — long (`--flag`), short (`-f`), takes value?, desc
- **Positional arguments** — name, type, required/optional, rest args (`...args`)

Then recurse `<tool> <subcommand> --help` fer each subcommand to find flags + nested subcommands. Keep go til no more subcommands. Some tools deep nest (e.g., `tool group subcommand action`).

**Important parsing notes:**
- Tools format `--help` diff. Some indent lists, some tables, some have sections "Commands:", "Options:", "Flags:", "Arguments:". Be adaptive.
- Some tools use `-h` not `--help`, or have `help` subcommand. If `--help` fail, try `-h` then `help`.
- Watch aliases (e.g., `delete` and `destroy` same thing) — gen completions fer both.
- Skip `help` subcommand + mirrors (e.g., `tool help subcommand`) — noise no value.

## Step 2: Identify dynamic vs static completions

Most completions **static** — subcommands + flags fixed. But some flag values or positional args **dynamic** — depend runtime state. Look fer clues:

**Dynamic completions** (use `nu-complete` helper functions):
- Args described as IDs, names, or lists of existing resources (e.g., "instance ID", "snapshot name", "available regions")
- Flag values reference user-created stuff (e.g., `--profile <name>`)
- Anything where tool can list valid values (e.g., `tool list` returns options fer `tool delete <id>`)

**Static completions** (inline values or just type annotations):
- Enum-like values (e.g., "output format: text | json | yaml")
- Boolean flags
- Free-form strings (file paths, descriptions, arbitrary names)

Fer dynamic completions, write `nu-complete` helper functions that call CLI tool to fetch current values. Follow pattern from user's existing completions:

```nu
def "nu-complete <tool> <thing>" [] {
  ^<tool> <list-command> --output json
    | from json
    | get <field>
    | each {|it| {description: $"($it.<desc_field>)" value: $it.<id_field>} }
}
```

If tool no support JSON output, parse text output use `lines`, `parse`, or `str trim`.

Fer static enum-like values, write simple completer:

```nu
def "nu-complete <tool> <option>" [] {
  [value1, value2, value3]
}
```

Use judgment — not every arg w/ finite set need dynamic completer. If help text explicit list valid values (like `[text | json | yaml]`), static list fine.

## Step 3: Generate the completion file

### File location and naming

Save file to: `$"($env.XDG_CONFIG_HOME)/nushell/custom-completions/<tool>-completions.nu"`

If `XDG_CONFIG_HOME` not set, fall back `~/.config`.

### File structure

Use this structure — match user's existing completions:

```nu
# Dynamic completers (for resource IDs, names, etc.)
def "nu-complete <tool> <thing>" [] {
  # ...
}

# Static enum completers
def "nu-complete <tool> <option>" [] {
  [value1, value2, value3]
}

# Empty completer to suppress path fallback on parent commands
def "nu-complete none" [] { [] }

# Root command (also a parent — needs empty completer)
export extern "<tool>" [
  _?: string@"nu-complete none"
  --flag (-f): type                                    #Description
  --help (-h)                                          #Help
]

# Parent command with subcommands (description above)
export extern "<tool> <group>" [
  _?: string@"nu-complete none"
  --help                                               #Help
]

# Leaf subcommands (description above each)
export extern "<tool> <group> <subcommand>" [
  arg: string@"nu-complete <tool> <thing>"             #Description
  --flag: type                                         #Description
  --help                                               #Help
]
```

### Choosing between static and dynamic subcommand listing

Fer **root command + intermediate commands** (commands w/ subcommands below), 2 options:

1. **Dynamic `nu-complete` subcommand completer** — calls `--help` at tab-time to list subcommands. Use when tool's subcommand list may change (e.g., plugin-based tools) or many subcommands + no want enumerate all.

2. **Static `export extern` fer each subcommand** — pre-gen every subcommand. Use when subcommand tree stable + already walked.

**No combine both in same file.** If define static `export extern` blocks fer subcommands, Nushell auto offer them as completions fer parent command. Adding dynamic `command?: string@"nu-complete ..."` param on parent cause duplicate entries — one set from dynamic completer, one from static externs. Pick one approach per parent command:

- The **root command itself counts as a parent** if there are any subcommand externs below it. Apply the same `_?: string@"nu-complete none"` treatment.
- If all subcommands have `export extern` blocks → define parent w/ dummy positional use empty completer to suppress path fallback:
  ```nu
  def "nu-complete none" [] { [] }

  # Description of the parent command
  export extern "tool group" [
    _?: string@"nu-complete none"
    --help                          #Show this message and exit
  ]
  ```
  Without `_?: string@"nu-complete none"`, Nushell fall back path completion fer positional arg slot, pollute menu. Empty completer suppress this. Define `nu-complete none` once at top of file + reuse fer all parent commands.
- If only define parent (not individual subcommands) → use dynamic completer fer subcommand discovery

### Nushell extern syntax rules

Follow these rules when write `export extern` blocks:

- **Command description**: Place `# Description` comment on line right before `export extern`. This how Nushell show descriptions in completion menu. Every `export extern` block shud have one.
- **Flags with values**: `--name (-n): type` followed by comment `#Description`
- **Boolean flags / switches** (no value): `--verbose (-v)` followed by `#Description`. NEVER add type annotation (`: bool`) to switches — Nushell no allow. Just write `--flag-name` no type.
- **Required positional**: `name: type` followed by `#Description`
- **Optional positional**: `name?: type` followed by `#Description`
- **Rest arguments**: `...name: type` followed by `#Description`
- **Types**: `string`, `int`, `float`, `path`, `any` (no `bool` — boolean just switch)
- **Custom completers**: `name: type@"nu-complete <tool> <thing>"`
- **Comments as descriptions**: Use `#Description` (hash then desc) right-aligned fer readability
- Short flags go in parens after long form: `--help (-h)`

### Style

- Right-align `#` comments fer readability (pick consistent column)
- Group related `nu-complete` functions at top of file
- Order: helper functions, then root command, then subcommands (depth-first or grouped by parent)
- Blank line between each `export extern` block

## Step 4: Register the completion

After gen file, add `use` line to `custom-completions.nu`:

```nu
use ./<tool>-completions.nu *
```

Add in appropriate section — w/ other local completions (after `nu_scripts` ones). Check fer OS-gated sections + place outside unless tool OS-specific.

If `use` line already exist, no duplicate.

## Tips and edge cases

- **Tools no support `--help`**: Some tools use `help` as subcommand, or `-h` only, or print help to stderr. Try alternatives if `--help` fail.
- **Very large CLIs** (like `aws`, `kubectl`, `docker`): Hundreds of subcommands. Use judgment on depth — go 2-3 levels deep fer common commands, dynamic completers fer rest. Warn user if tool very large + ask if want full coverage or just common commands.
- **Flags shared across all subcommands** (global flags): Many tools have flags like `--config`, `--output`, `--help` on every subcommand. Include on each `export extern` block where appear — Nushell need them on each command definition.
- **Mutually exclusive flags**: Nushell no have syntax fer this. Just list all flags + let tool handle error.
- **Deprecated subcommands/flags**: Skip unless still commonly used.