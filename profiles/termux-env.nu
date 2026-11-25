# Keep Termux's native PATH and add user-installed scripts.
let local_bin = ($nu.home-dir | path join ".local" "bin")
if $local_bin not-in $env.PATH {
  $env.PATH ++= [$local_bin]
}

$env.XDG_CONFIG_HOME = "~/.config" | path expand
$env.EDITOR = "nvim"