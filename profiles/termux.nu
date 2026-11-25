# Only load tools intended for the mobile shell.
use ../tools/fzf.nu *
use ../tools/yazi.nu *
use ../tools/nvim.nu *
use ../tools/ripgrep.nu *
use ../tools/bat.nu *
source ../tools/zoxide.nu
source ../tools/starship.nu
source ../tools/zellij.nu

# Keep completions ahead of custom commands that override them.
use ../nu_scripts/custom-completions/rg/rg-completions.nu *
use ../nu_scripts/custom-completions/zoxide/zoxide-completions.nu *
use ../nu_scripts/custom-completions/curl/curl-completions.nu *
use ../nu_scripts/custom-completions/eza/eza-completions.nu *
use ../nu_scripts/custom-completions/ssh/ssh-completions.nu *
use ../nu_scripts/custom-completions/git/git-completions.nu *
use ../nu_scripts/custom-completions/bat/bat-completions.nu *
use ../nu_scripts/custom-completions/zellij/zellij-completions.nu *
use ../nu_scripts/custom-completions/npm/npm-completions.nu *
use ../custom-completions/yazi-completions.nu *
use ../custom-completions/ya-completions.nu *

use ../custom-commands/git.nu
source ../aliases/git.nu

source ./theme.nu