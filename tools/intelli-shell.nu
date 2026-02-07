export-env {
  $env.INTELLI_HOME = $"($env.USERPROFILE)/intelli-shell/data"
  $env.INTELLI_CONFIG = $"($env.XDG_CONFIG_HOME)/intelli-shell/config.toml"
  $env.INTELLI_COMMANDS = $"($env.XDG_CONFIG_HOME)/intelli-shell/commands/"
  $env.INTELLI_SEARCH_HOTKEY = 'control char_e'
}

mkdir ($nu.data-dir | path join "vendor/autoload")
intelli-shell init nushell | save -f ($nu.data-dir | path join "vendor/autoload/intelli-shell.nu")
