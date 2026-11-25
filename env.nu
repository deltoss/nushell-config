use ./profiles/platform.nu [IS_TERMUX]

source (if $IS_TERMUX { "./profiles/termux-env.nu" } else { "./profiles/desktop-env.nu" })

# Configure Nushell command line editing experience to behave like vim.
$env.config.edit_mode = 'vi'
$env.config.cursor_shape.vi_insert = "blink_line"
$env.config.cursor_shape.vi_normal = "blink_block"

$env.config.completions.algorithm = "fuzzy"

# When true, the current directory and running command are shown in the terminal tab/window title.
# Also abbreviates the directory name by prepending ~ to the home directory and its subdirectories.
$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true      # cwd via OSC 7
$env.config.shell_integration.osc9_9 = true    # cwd via OSC 9;9 - Windows Terminal uses this for "duplicate tab in same directory"

$env.config.datetime_format.normal = "%d/%m/%y %I:%M:%S%p"

# Display output tables with more information
# Also stores the output (if any) into an environment variable
$env.config.hooks.display_output = { tee { table -e | print } | $env.LAST = $in }

let env_file = ($nu.default-config-dir | path join ".env.json")
let vars = if ($env_file | path exists) { open $env_file } else { {} }
load-env $vars

# Cache Git's system-config path to avoid Starship's Windows `git --exec-path`
# lookup on each prompt render. On Linux, its Git library uses
# GIT_CONFIG_SYSTEM or /etc/gitconfig without that lookup.
if $nu.os-info.name == "windows" and ($vars.GIT_CONFIG_SYSTEM? | default "" | str trim | is-empty) {
  if ($env.GIT_CONFIG_SYSTEM? | default "" | str trim | is-empty) { hide-env -i GIT_CONFIG_SYSTEM }
  try {
    let result = (^git var GIT_CONFIG_SYSTEM | complete)
    let paths = ($result.stdout | lines)
    if $result.exit_code == 0 and ($paths | length) == 1 and ($paths.0 | path type) == "file" {
      $vars | upsert GIT_CONFIG_SYSTEM $paths.0 | to json | save --force $env_file
      $env.GIT_CONFIG_SYSTEM = $paths.0
    }
  } catch { }
}

# See: https://textmode.dev/from-zero-to-productive-my-nushell-config
$env.COLORTERM = "truecolor"
$env.config.history = {
  file_format: sqlite
  max_size: 5_000_000
  sync_on_enter: true
  isolation: true
}

# Force Pi status reporting inside Zellij.
if "ZELLIJ" in $env {
  $env.PI_PROGRAM_STATUS = "1"
}