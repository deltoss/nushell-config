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

# Configure rider to use ~/.config/rider
$env.RIDER_PROPERTIES = $home_dir | path join ".config" "rider" "idea.properties"