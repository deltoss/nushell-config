use ./git-helpers.nu [repo-folder]

export def list [] {
  let output = git worktree list --porcelain | str trim
  let entries = $output | split row "\n\n"

  if ($entries | is-empty) {
    print "No worktrees found."
    return []
  }

  let main_repo_path = repo-folder
  let parent_path = if ($main_repo_path | is-not-empty) {
    $main_repo_path | path dirname
  }

  $entries | each { |entry|
    let lines = $entry | split row "\n" | where { |l| ($l | str trim) != "" }
    let full_path = $lines.0 | str replace --regex '^worktree ' ''

    let relative_path = if ($parent_path != null) and ($full_path | is-not-empty) {
      try {
        $full_path | path relative-to $parent_path
      } catch {
        print $"Failed to get relative path: ($full_path)"
        $full_path
      }
    } else {
      $full_path
    }

    let commit = $lines.1 | str replace --regex '^HEAD ' ''
    let branch = if ($lines.2 | str starts-with 'branch ') {
      $lines.2 | str replace --regex '^branch refs/heads/' ''
    } else {
      '(detached)'
    }

    {
      path: $full_path
      relative_path: $relative_path
      commit: $commit
      commit_short: ($commit | str substring 0..7)
      branch: $branch
    }
  }
}

export def select [] {
  let worktrees = list

  let formatted_entries = $worktrees | each { |it|
    $"($it.branch | fill -a l -w 40) ($it.commit_short | fill -a l -w 10) ($it.relative_path)"
  }

  let selected = $formatted_entries | str join "\n" | ^fzf

  # fzf only gives us the selected string back
  # Get the original worktree object from the selection
  let selected_branch = $selected | str replace --regex '\s+.+\s+.+' '' | str trim
  let selected_worktree = $worktrees | where branch == $selected_branch

  $selected_worktree
}
