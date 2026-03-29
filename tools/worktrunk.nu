use ../custom-commands/git.nu ['select branch']
use ../custom-commands/worktree.nu

# Switch to an existing git worktree
export def --env --wrapped wts [...rest] {
  print "Pick worktree:"
  let branch = worktree select | get -o branch
  if ($branch | is-empty) {
    return
  }
  print $"Selected Branch: ($branch)"

  git-wt switch $branch ...$rest
}

# Create a git worktree and select the base branch for it
export def --env --wrapped wta [...rest] {
  print "Pick base branch:"
  let base_branch = select branch | get -o branch
  if ($base_branch | is-empty) {
    return
  }
  print $"Selected Branch: ($base_branch)"

  print "Pick new branch:"
  let new_branch_interaction = select branch
  let new_branch = ($new_branch_interaction | get -o branch) | default ($new_branch_interaction | get -o query)
  if ($new_branch | is-empty) {
    return
  }
  print $"Selected Branch: ($new_branch)"

  git-wt switch --create --base $base_branch $new_branch ...$rest
}

# Remove a selected git worktree
export def --env --wrapped wtr [...rest] {
  print "Pick branch to delete:"
  let branch = select branch | get -o branch
  if ($branch | is-empty) {
    return
  }
  print $"Selected Branch: ($branch)"
  git-wt remove -D $branch ...$rest
}

# Create a git worktree and run Claude Code on it
@example "Creates worktree, runs hooks & launches Claude Code" { wtc new-feature }
@example "Runs `claude 'Fix GH #322'`" { wtc feature -- "Fix GH #322" }
export def --env --wrapped wtc [...rest] {
  wta
  ^claude ($rest | where $it != '--' | str join ' ')
}

# Create a git worktree and run OpenCode on it
@example "Creates worktree, runs hooks & launches OpenCode" { wt0 new-feature }
@example "Runs `opencode 'Fix GH #322'`" { wto feature -- "Fix GH #322" }
export def --env --wrapped wto [...rest] {
  wta
  ^opencode ($rest | where $it != '--' | str join ' ')
}