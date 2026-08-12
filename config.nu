# config.nu
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

source ./tools/tools.nu

use ./custom-commands/ *

# Aliases and `extern` completions are parse-time definitions.
# They can't be wrapped in a `if $nu.is-interactive`. It'd silently discards
# every alias and completion. Keep them at top level.
source ./custom-completions/custom-completions.nu
source ./aliases/aliases.nu

if $nu.is-interactive {
  # Runtime `$env.config` mutation, unaffected by block scoping.
  source ./keybinds.nu
}

# For preview of themes, see https://github.com/nushell/nu_scripts/blob/main/themes/screenshots/README.md
# `use` (not `source`) skips the theme's self-activation. Activating it prints raw
# OSC 10/11/12 colour escapes to stdout on every startup, which corrupts output when
# nu runs non-interactively
use ./nu_scripts/themes/nu-themes/atelier-cave-light.nu
atelier-cave-light set color_config
if $nu.is-interactive {
    atelier-cave-light update terminal
}