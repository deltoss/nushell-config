let home_dir = ("~" | path expand)
let user_bin_paths = [
  ($home_dir | path join ".local" "bin")
  ($home_dir | path join ".cargo" "bin")
  ($home_dir | path join ".bun" "bin")
  ($home_dir | path join ".deno" "bin")
  ($home_dir | path join ".dotnet")
  ($home_dir | path join ".dotnet" "tools")
  ($home_dir | path join "go" "bin")
  ($home_dir | path join ".opencode" "bin")
]

let executable_paths = if $nu.os-info.name == "linux" {
  let arch = ^uname -m | str trim
  let nvim_arch = match $arch {
    "aarch64" => "arm64",
    _ => "x86_64"
  }
  let nvim_dir = $"nvim-linux-($nvim_arch)"

  [
    $"/opt/($nvim_dir)/bin" # For Neovim installation
    ...$user_bin_paths
    "/home/linuxbrew/.linuxbrew/bin" # homebrew
    "/home/linuxbrew/.linuxbrew/sbin"
  ]
} else {
  $user_bin_paths
}

let expanded_executable_paths = (
  $executable_paths | each { |entry| $entry | path expand }
)
let existing_paths = (
  $env.PATH | each { |entry| $entry | path expand }
)
let missing_executable_paths = (
  $expanded_executable_paths
  | where { |entry| $entry not-in $existing_paths }
)

$env.PATH ++= $missing_executable_paths

if $nu.os-info.name == "linux" {
  # Conditionally import cargo's env.nu, only if it exists
  const path = "~/.cargo/env.nu" 
  const source = if ($path | path exists) { $path } else { null }
  source $source

  $env.DOTNET_ROOT = ($nu.home-dir | path join ".dotnet") # So `dotnet tool` works
  $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
}

if $nu.os-info.name == "windows" {
  $env.HOME = $env.USERPROFILE | str replace "\\" "/" --all
}
$env.XDG_CONFIG_HOME = "~/.config" | path expand
$env.EDITOR = "nvim"

if $nu.os-info.name == "windows" {
  # Configure Yazi to open files correctly on Windows.
  # See:
  #   https://yazi-rs.github.io/docs/installation#windows
  $env.YAZI_FILE_ONE = "C:\\Program Files\\Git\\usr\\bin\\file.exe"
  $env.YAZI_CONFIG_HOME = $"($env.XDG_CONFIG_HOME)/yazi"

  $env.ZELLIJ_CONFIG_DIR = $"($env.XDG_CONFIG_HOME)/zellij"
}

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

# See: https://textmode.dev/from-zero-to-productive-my-nushell-config
$env.COLORTERM = "truecolor"
$env.config.history = {
  file_format: sqlite
  max_size: 5_000_000
  sync_on_enter: true
  isolation: true
}