use ./git-helpers.nu [repo-folder repo-info parse-git-url]

# Bring up interactive git menu for custom git operations
export def menu [] {
  print $"(ansi bo)(ansi cyan)b(ansi bl) ⟶ (ansi reset)Select git [(ansi bo)B(ansi reset)]ranch"
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)Select git [(ansi bo)C(ansi reset)]ommit"
  print $"(ansi bo)(ansi cyan)f(ansi bl) ⟶ (ansi reset)Select git [(ansi bo)F(ansi reset)]ile"
  print $"(ansi bo)(ansi cyan)l(ansi bl) ⟶ (ansi reset)Show git [(ansi bo)L(ansi reset)]og"
  print $"(ansi bo)(ansi cyan)g(ansi bl) ⟶ (ansi reset)Lazy[(ansi bo)G(ansi reset)]it"
  print $"(ansi bo)(ansi cyan)G(ansi bl) ⟶ (ansi reset)Edit GitHub [(ansi bo)G(ansi reset)]ists"
  print $"(ansi bo)(ansi cyan)m(ansi bl) ⟶ (ansi reset)Resolve git [(ansi bo)M(ansi reset)]erge conflicts"
  print $"(ansi bo)(ansi cyan)p(ansi bl) ⟶ (ansi reset)Open [(ansi bo)P(ansi reset)]ull request"
  print $"(ansi bo)(ansi cyan)w(ansi bl) ⟶ (ansi reset)[(ansi bo)W(ansi reset)]orktree"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  mut result = ''
  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['b', []] => { $result = (select branch | get --optional branch); break }
      ['c', []] => { $result = select commit; break }
      ['f', []] => { $result = select file; break }
      ['l', []] => { $result = log; break }
      ['g', []] => { commandline edit  --accept --replace "lazygit"; break }
      ['G', []] => { commandline edit  --accept --replace "gh gist edit"; break }
      ['m', []] => { commandline edit  --accept --replace "git mergetool"; break }
      ['p', []] => { commandline edit  --accept --replace "pr"; break }
      ['w', []] => { break }
      ['q', []] => { break }
      ['c', [keymodifiers(control)]] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  $result
}

# Select a git branch's name
export def "select branch" --wrapped [
  --extra: list<string> = []
  ...rest
] {
  let branches = (git branch -a --color ...$rest | lines)
  let all = ($extra ++ $branches)
  let interaction = $all | str join "\n" | fzf --print-query --ansi --header="Git - Branches" | lines

  # Return null if nothing selected
  if ($interaction | is-empty) {
    return null
  }

  # Check if we got a query only or query + selection
  if ($interaction | length) == 1 {
    return {
      query: ($interaction | get 0)
      branch: null
    }
  } else {
    return {
      query: ($interaction | get 0)
      branch: ($interaction | get 1 
        | str trim 
        | str replace --regex '^\*\s*' ''
        | str replace --regex '^remotes/' ''
        | str replace --regex '\x1b\[[0-9;]*m' ''
        | str replace --regex '\+\s+' ''
        | str replace --regex '\s*->.+' '')
    }
  }
}

# Select a git commit's hash
export def "select commit" --wrapped [
  ...rest
] {
  ^git log --all --color=always --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset) %H" --date=format:"%Y-%m-%d %I:%M %p" ...$rest
  | fzf --print-query --ansi --header="Git - Commits" 
  | str trim
  | ansi strip
  | split row ' '
  | first
}

# Select a changed file's path
export def "select file" --wrapped [
  ...rest
] {
  git status --porcelain ...$rest | fzf --header="Git - Changed Files"
  | str substring 3..-1
  | str trim
}

# Log with more readable formatting
export def log --wrapped [
  ...rest
] {
  let $args = [
    '--graph',
    '--pretty=format:%C(yellow)%h%Creset %C(green)%ad%Creset %C(bold blue)%an%Creset %C(red)%d%Creset %s %C(dim white)%b%Creset',
    '--date=short',
    '--color',
    ...$rest
  ]

  ^git log ...$args
}

# Log a branch interactively with a branch menu
export def "log menu" --wrapped [
  ...rest
] {
  let $selection = select-branch --extra ["  HEAD", "  --all"]
  if ($selection | is-empty) {
    return
  }

  log ($selection | get branch)
}

# Get detailed information about git worktrees
export def "worktree info" [] {
  let worktrees = git worktree list --porcelain | str trim
  let entries = $worktrees | split row --regex '(\r?\n){2}'

  if ($entries | is-empty) {
    print "No worktrees found."
    return
  }

  let repo_folder = repo-folder
  let parent_folder = if ($repo_folder | is-not-empty) {
    $repo_folder | path dirname
  }

  $entries | each { |entry|
    let lines = $entry | lines
    let full_path = $lines | get 0 | str replace --regex '^worktree ' ''
    let relative_path = if (($parent_folder | is-not-empty) and ($full_path | is-not-empty)) {
      $full_path | path relative-to $parent_folder
    } else {
      $full_path
    }

    {
      Branch: (if ($lines.2 | str starts-with 'branch ') {
        $lines.2 | str replace --regex '^branch refs/heads/' ''
      } else {
        '(detached)'
      })
      RelativePath: $relative_path
      Path: $full_path
      CommitShort: ($lines.1 | str replace --regex '^HEAD ' '' | str substring 0..7)
      Commit: ($lines.1 | str replace --regex '^HEAD ' '')
    }
  }
}
