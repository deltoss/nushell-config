# Custom hooks. Nushell's own hooks live in $env.config.hooks
$env.hooks = ($env.hooks? | default {})
$env.hooks.pre-pr-raise = ($env.hooks.pre-pr-raise? | default [])

source ../tools/tools.nu

# Aliases and `extern` completions are parse-time definitions.
# They can't be wrapped in a `if $nu.is-interactive`. It'd silently discards
# every alias and completion. Keep them at top level.
source ../custom-completions/custom-completions.nu

# Loaded after the completions on purpose: an `extern` and a `def` of the same name
# are both plain declarations, so the last one parsed wins. The other way round,
# `extern "git log"` from nu_scripts shadowed the `git log` command below.
use ../custom-commands/ *

$env.hooks.pre-pr-raise ++= [
  {|_, dest_branch|
    if (input "Do you want an AI review of your changes before raising the PR? [y/N] " | str trim | str lowercase) in ["y" "yes"] {
      pr self-review $dest_branch
      if (input "Proceed with raising the PR? [y/N] " | str trim | str lowercase) not-in ["y" "yes"] {
        return false
      }
    }
  }
]

source ../aliases/aliases.nu

if $nu.is-interactive {
  # Runtime `$env.config` mutation, unaffected by block scoping.
  source ../keybinds.nu
}

source ./theme.nu