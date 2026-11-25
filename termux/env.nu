# Keep Termux's native PATH and add user-installed scripts.
let local_bin = ($nu.home-dir | path join ".local" "bin")
if $local_bin not-in $env.PATH {
  $env.PATH ++= [$local_bin]
}

$env.XDG_CONFIG_HOME = "~/.config" | path expand
$env.EDITOR = "nvim"

$env.config.edit_mode = 'vi'
$env.config.cursor_shape.vi_insert = "blink_line"
$env.config.cursor_shape.vi_normal = "blink_block"
$env.config.completions.algorithm = "fuzzy"

$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true
$env.config.datetime_format.normal = "%d/%m/%y %I:%M:%S%p"
$env.config.hooks.display_output = { tee { table -e | print } | $env.LAST = $in }

$env.COLORTERM = "truecolor"
$env.config.history = {
  file_format: sqlite
  max_size: 5_000_000
  sync_on_enter: true
  isolation: true
}

if "ZELLIJ" in $env {
  $env.PI_PROGRAM_STATUS = "1"
}