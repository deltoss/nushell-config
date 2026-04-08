use ./fzf.nu *
use ./yazi.nu *
use ./nvim.nu *
use ./opencode.nu *
use ./1password.nu *
use ./ripgrep.nu *
use ./bat.nu *
use ./visual-studio.nu *

# Conditionally import cargo's env.nu, only if it exists
use (if ($nu.os-info.name == "linux") { "./blkid.nu" } else { null })

source ./tv.nu
source ./zoxide.nu
source ./mise.nu
source ./intelli-shell.nu
source ./aichat/aichat.nu
source ./starship.nu
source ./git-wt.nu
source ./worktrunk.nu