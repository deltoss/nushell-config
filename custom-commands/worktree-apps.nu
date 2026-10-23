use std/log
use ../tools/visual-studio.nu ['devenv is-installed']
use ../tools/jetbrains-rider.nu ['rider is-installed']

export def available-modes [] {
  mut modes = [nvim hunk]
  if (rider is-installed) { $modes ++= [rider] }
  if (devenv is-installed) { $modes ++= [vs] }
  $modes
}

# Fresh shells must import the solution launchers. Forward slashes survive Zellij's argument forwarding.
def solution-command [module: string, command: string] {
  let script = $nu.default-config-dir | path join tools $module | str replace --all '\' '/'
  [nu -c $"use ($script | to nuon) [($command | to nuon)]; ($command)"]
}

# --edit opens Neovim normally; the other tools behave the same for tickets and reviews.
export def launch-command [mode: string, base: string, --edit] {
  match $mode {
    "nvim" => {
      if $edit { return [nvim] }
      [
        nvim
        # CodeDiff opens a new tab asynchronously; close the startup dashboard tab once it is ready.
        -c "autocmd User CodeDiffOpen ++once lua vim.schedule(function() vim.cmd('1tabclose') end)"
        -c $"CodeDiff ($base)..."
      ]
    }
    "hunk" => {
      # Hunk has no whitespace flag, so generate the patch with Git and let Hunk render it.
      # See https://github.com/modem-dev/hunk/issues/794
      # Use Nushell to resolve Windows npm shims for Hunk.
      # Diff the working tree against the merge base, including staged and unstaged changes.
      let target = $base | to nuon
      let script = $"let patch = mktemp --suffix .patch
try {
  ^git diff --merge-base --ignore-all-space --no-color ($target) -- | save --force $patch
  ^hunk patch $patch
} finally {
  rm --force $patch
}"
      [nu --commands $script]
    }
    "rider" => {
      if (rider is-installed) {
        solution-command jetbrains-rider.nu 'rider solution'
      } else {
        log warning "Rider isn't available on this machine"
        null
      }
    }
    "vs" => {
      if (devenv is-installed) {
        solution-command visual-studio.nu 'devenv solution'
      } else {
        log warning "Visual Studio isn't available on this machine"
        null
      }
    }
    _ => { log warning $"Unknown mode '($mode)', skipping launch"; null }
  }
}

export def launch [base: string, worktree: path, modes?: list<string>, --edit] {
  let prompt = if $edit { "Open with" } else { "Open diff with" }
  let selected = $modes
    | default {
      let result = (
        available-modes
        | tui label --titlebar $prompt
        | tui select --multi
        | tui run --dialog
      )
      if $result.action != "submit" {
        []
      } else {
        let picked = $result.selected
        if ($picked | describe) =~ '^list' { $picked } else { [$picked] }
      }
    }
    | default []
    | where {|mode| $mode not-in ["" "none" null] }
  let in_zellij = $env.ZELLIJ? | is-not-empty

  for mode in $selected {
    let command = launch-command $mode $base --edit=$edit
    if ($command | is-empty) { continue }
    if $mode == "vs" and not $edit {
      print $"(ansi yellow)Visual Studio can't open a branch diff from the command line. To see the full diff:(ansi reset)"
      print $"(ansi bo)(ansi cyan)Git(ansi reset) > (ansi bo)(ansi cyan)Manage Branches(ansi reset) > right-click (ansi bo)(ansi green)($base)(ansi reset) > (ansi bo)(ansi cyan)Compare with Current Branch(ansi reset)"
    }

    if $in_zellij {
      (^zellij action new-pane
        --cwd $worktree --stacked --close-on-exit --name $mode
        -- ...$command) | ignore

      if $mode == "hunk" {
        (^zellij action new-pane
          --cwd $worktree --stacked --close-on-exit --name "🤖 Hunk AI"
          -- nu) | ignore
      }
    } else {
      do {
        cd $worktree
        run-external ($command | first) ...($command | skip 1)
      }
    }
  }
}