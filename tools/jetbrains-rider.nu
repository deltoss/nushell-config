use "../custom-commands/fzf-helpers.nu" ['parse fzf']
use "../custom-commands/start.nu"

# Launch JetBrains Rider.
#
# Add Rider's bin directory or Toolbox's shell scripts directory to PATH.
@example "Launch Rider" { rider }
@example "Open a solution" { rider MySolution.sln }
export def --wrapped rider [...rest] {
  let launcher = (which --all rider rider64 rider.sh | where type == external | get --optional path.0)
  if ($launcher | is-empty) {
    error make { msg: "No Rider launcher found on PATH. Add Rider's bin directory or JetBrains Toolbox's shell scripts directory to PATH." }
  }

  if $nu.os-info.name == "windows" {
    if ($rest | is-empty) {
      start $launcher
    } else {
      start detached $launcher ...$rest
    }
  } else {
    job spawn { ^$launcher ...$rest } | ignore
  }
}

# Find and launch solutions in the current directory and subdirectories.
@example "Select solutions with fzf" { rider solution }
@example "Start with a search query" { "MyApp" | rider solution }
export def --wrapped "rider solution" [...rest] {
  let query = $in | default ''
  let solutions = glob --no-dir "**/*.{sln,slnx}"
  if ($solutions | is-empty) {
    print "No .NET solutions found in the current directory or its subdirectories."
    return
  }

  let result = $solutions | str join "\n" | ^fzf --multi --header='Search - .NET Solutions (Tab to Select)' --print-query --query $query | complete
  if $result.exit_code in [1 130] { return }
  if $result.exit_code != 0 {
    error make { msg: $"Solution picker failed: ($result.stderr | str trim)" }
  }

  let interaction = $result.stdout | parse fzf
  for solution in ($interaction | get --optional selections | default []) {
    rider $solution ...$rest
  }
}