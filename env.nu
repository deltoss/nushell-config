$env.XDG_CONFIG_HOME = "~/.config" | path expand
$env.EDITOR = "nvim"
# Custom environment variable used within nvim & shell scripts to start OpenCode CLI
$env.OPENCODE_PORT = 4096

if $nu.os-info.name == "windows" {
  # Configure Yazi to open files correctly on Windows.
  # See:
  #   https://yazi-rs.github.io/docs/installation#windows
  $env.YAZI_FILE_ONE = "C:\\Program Files\\Git\\usr\\bin\\file.exe"
  $env.YAZI_CONFIG_HOME = $"($env.XDG_CONFIG_HOME)/yazi"
}

# Configure Nushell command line editing experience to behave like vim.
$env.config.edit_mode = 'vi'
$env.config.cursor_shape.vi_insert = "blink_line"
$env.config.cursor_shape.vi_normal = "blink_block"

$env.config.completions.algorithm = "fuzzy"

# When true, the current directory and running command are shown in the terminal tab/window title.
# Also abbreviates the directory name by prepending ~ to the home directory and its subdirectories.
$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true

$env.config.datetime_format.normal = "%d/%m/%y %I:%M:%S%p"

# Display output tables with more information
$env.config.hooks.display_output = { table -e }

let env_file = ($nu.default-config-dir | path join ".env.json")
let vars = if ($env_file | path exists) { open $env_file } else { {} }
load-env $vars
