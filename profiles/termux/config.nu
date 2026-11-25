# Load only the integrations needed on Termux.
use ../../tools/fzf.nu *
use ../../tools/yazi.nu *
use ../../tools/nvim.nu *
use ../../tools/ripgrep.nu *
use ../../tools/bat.nu *
source ../../tools/zoxide.nu
source ../../tools/starship.nu
source ../../tools/zellij.nu

# Load completions before custom commands that override them.
use ../../nu_scripts/custom-completions/rg/rg-completions.nu *
use ../../nu_scripts/custom-completions/zoxide/zoxide-completions.nu *
use ../../nu_scripts/custom-completions/curl/curl-completions.nu *
use ../../nu_scripts/custom-completions/eza/eza-completions.nu *
use ../../nu_scripts/custom-completions/ssh/ssh-completions.nu *
use ../../nu_scripts/custom-completions/git/git-completions.nu *
use ../../nu_scripts/custom-completions/bat/bat-completions.nu *
use ../../nu_scripts/custom-completions/zellij/zellij-completions.nu *
use ../../nu_scripts/custom-completions/npm/npm-completions.nu *
use ../../custom-completions/yazi-completions.nu *
use ../../custom-completions/ya-completions.nu *

use ../../custom-commands/git.nu
source ../../aliases/git.nu

use ../../nu_scripts/themes/nu-themes/atelier-cave-light.nu
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