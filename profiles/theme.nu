# For preview of themes, see https://github.com/nushell/nu_scripts/blob/main/themes/screenshots/README.md
# `use` (not `source`) skips the theme's self-activation. Activating it prints raw
# OSC 10/11/12 colour escapes to stdout on every startup, which corrupts output when
# nu runs non-interactively
use ../nu_scripts/themes/nu-themes/atelier-cave-light.nu
atelier-cave-light set color_config
$env.config.tui.surface = {bg: $env.config.color_config.background}
$env.config.tui.backdrop = {bg: $env.config.color_config.background}
$env.config.tui.title_bar = {
  fg: $env.config.color_config.foreground
  bg: $env.config.color_config.background
  attr: b
}
if $nu.is-interactive {
    atelier-cave-light update terminal
}