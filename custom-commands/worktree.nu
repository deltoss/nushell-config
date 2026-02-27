use ./git-helpers.nu [repo-folder, worktrees-folder]
use ./git.nu ['select branch']

export def --env main [] {
  menu
}

# Bring up interactive git menu for custom git operations
export def --env menu [] {
  print $"(ansi bo)(ansi cyan)l(ansi bl) ⟶ (ansi reset)[(ansi bo)L(ansi reset)]ist worktrees"
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)[(ansi bo)C(ansi reset)]hange"
  print $"(ansi bo)(ansi cyan)a(ansi bl) ⟶ (ansi reset)[(ansi bo)A(ansi reset)]dd"
  print $"(ansi bo)(ansi cyan)r(ansi bl) ⟶ (ansi reset)[(ansi bo)R(ansi reset)]emove"

  mut result = ''
  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['l', []] => { $result = list; break }
      ['c', []] => { $result = change; break }
      ['a', []] => { $result = add; break }
      ['r', []] => { $result = remove; break }
      ['q', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  $result
}

# List git worktrees
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
      branch: $branch
      relative_path: $relative_path
      path: $full_path
      commit_short: ($commit | str substring 0..7)
      commit: $commit
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
  let selected_worktree = $worktrees | where branch == $selected_branch | first

  $selected_worktree | default nothing
}

# Switch to the directory of a git worktree
export def --env change [] {
  let chosen_worktree = select
  if ($chosen_worktree | is-empty) {
    return
  }

  cd $chosen_worktree.path
  print $"(ansi green)Changed to worktree: ($chosen_worktree.path)(ansi reset)"
}

# Adds a git worktree and change to its directory
export def --env add [] {
  let worktree_path = worktrees-folder
  if ($worktree_path | is-empty) {
    error make {msg: "Failed to get worktrees folder path"}
  }

  # Select branch interactively
  let interaction = select branch
  if ($interaction | is-empty) {
    print $"(ansi yellow)No branch was selected.(ansi reset)"
    return
  }

  # Determine if creating new branch or using existing
  let new_branch = ($interaction.query | is-not-empty) and ($interaction.branch | is-empty)
  let selected_branch = if $new_branch {
    print $"(ansi green)Will create new branch: ($interaction.query)(ansi reset)"
    $interaction.query
  } else {
    $interaction.branch | str replace --regex '^origin/' ''
  }

  # Validate branch name
  if ($selected_branch | str trim | is-empty) {
    error make {msg: "Selected branch name is empty or invalid"}
  }

  let relative_path = input $"Enter the new worktree directory name [default: ($selected_branch)]: "
    | str trim
    | default --empty $selected_branch

  # Ensure worktree parent directory exists
  if not ($worktree_path | path exists) {
    mkdir $worktree_path
    print $"(ansi green)Created worktree folder at: ($worktree_path)(ansi reset)"
  }

  let full_path = ($worktree_path | path join $relative_path)

  # Check if worktree path already exists
  if ($full_path | path exists) {
    error make {msg: $"Worktree path already exists: ($full_path)"}
  }

  try {
    print $"(ansi green)Creating worktree at: ($full_path)(ansi reset)"

    # Execute git worktree add
    let git_result = if $new_branch {
      ^git worktree add $full_path -b $selected_branch
        | complete
    } else {
      ^git worktree add $full_path $selected_branch
        | complete
    }

    if $git_result.exit_code != 0 {
      error make {
        msg: $"Git worktree command failed with exit code ($git_result.exit_code)"
        label: {
          text: $git_result.stderr
          span: (metadata $git_result).span
        }
      }
    }

    # Switch to new worktree
    try {
      cd $full_path
      print $"(ansi green)Created and switched to worktree: ($full_path)(ansi reset)"
    } catch {
      print $"(ansi yellow)Worktree created but failed to switch location: ($in)(ansi reset)"
      print $"(ansi yellow)Worktree created at: ($full_path)(ansi reset)"
    }

  } catch {|err|
    print $"(ansi red)Create-Worktree failed: ($err.msg)(ansi reset)"

    # Cleanup: Try to remove partially created worktree
    if ($full_path | is-not-empty) and ($full_path | path exists) {
      try {
        ^git worktree remove $full_path --force
          | complete
          | ignore
        print $"(ansi yellow)Cleaned up partial worktree at: ($full_path)(ansi reset)"
      } catch {
        print $"(ansi yellow_bold)Warning: Could not clean up partial worktree at: ($full_path)(ansi reset)"
      }
    }

    # Re-raise error
    error make $err
  }
}

# Remove a git worktree
export def --env remove [] {
  let chosen_worktree = select
  if ($chosen_worktree | is-empty) {
    return
  }

  let chosen_path = $chosen_worktree.path
  let current_path = $env.PWD | str replace --all "\\" "/"

  if $chosen_path == $current_path {
    print $"(ansi red)Can't remove the worktree you're currently in. Switch to another worktree first, then try again.(ansi reset)"
    return
  }

  ^git worktree remove --force $chosen_path
  print $"(ansi green)Removed worktree: ($chosen_path)(ansi reset)"
}
