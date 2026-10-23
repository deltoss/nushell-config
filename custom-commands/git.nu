use ../tools/tui.nu [tui-picker]

# Bring up interactive menu for custom git operations
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
      ['w', []] => { commandline edit  --accept --replace "worktree"; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  $result
}

def branch-name [line: string] {
  $line | ansi strip | str trim
    | str replace --regex '^[*+]\s*' ''
    | str replace --regex '^remotes/' ''
    | str replace --regex '\s*->.+' ''
}

# Select a branch, or press Ctrl+N to create a new branch.
# Returns {query, branch} so callers can distinguish new and existing branches.
export def "select branch" --wrapped [
  --extra: list<string> = []
  --preferred: string # Show this branch first without adding a duplicate
  ...rest
] {
  let branches = (^git branch -a --no-color ...$rest | lines
    | each {|line| {branch: (branch-name $line)} }
    | where branch != "")
  let ordered = if ($preferred | is-not-empty) {
    $branches | sort-by {|row| $row.branch != $preferred }
  } else {
    $branches
  }
  let extras = ($extra | each {|name| {branch: ($name | str trim)} })
  let result = (
    ($extras ++ $ordered)
    | tui label --titlebar "Git branches"
    | tui search --bind / --fuzzy --columns [branch] --id branch-query
    | tui table --focus --columns [branch]
    | tui bind ctrl+n {|state|
        {action: submit, selected: {branch: null, query: ($state.values | get --optional branch-query | default "")}}
      }
    | tui label --status "up/down: move  /: filter  ctrl+n: new branch  enter: select"
    | tui run --dialog
  )
  if $result.action != "submit" { return null }

  let branch = $result.selected.branch?
  let query = ($result.values | get --optional branch-query | default "")
  if ($branch | is-not-empty) {
    return {query: $query, branch: $branch}
  }

  let name = ($result.selected.query? | default "" | str trim)
  let name = if ($name | is-empty) { input "New branch name: " | str trim } else { $name }
  if ($name | is-empty) { return null }
  {query: $name, branch: null}
}

# Select a git commit's hash
export def "select commit" --wrapped [
  ...rest
] {
  let commits = (^git log --all --no-color --pretty=format:"%h¦¦¦%ad¦¦¦%s¦¦¦%an" --date=short ...$rest
    | lines
    | split column "¦¦¦" hash date subject author)
  let selected = $commits | tui-picker "Git commits" [hash date subject author]
  $selected.hash?
}

# Select a changed file's path
export def "select file" --wrapped [
  ...rest
] {
  let files = (^git status --porcelain ...$rest | lines | each {|line|
    {status: ($line | str substring 0..1), path: ($line | str substring 3..)}
  })
  let selected = $files | tui-picker "Git changed files" [status path]
  $selected.path?
}

# Revisions and changed files, for commands that accept either.
# nu_scripts has this as `nu-complete git files-or-refs`, but its completers are
# module-private, so it's reimplemented here.
# `sort: false` keeps branches ahead of files instead of interleaving them.
def "nu-complete refs-or-files" [] {
  # `--relative`: paths are repo-root-relative otherwise, so they wouldn't
  # resolve when completing from a subdirectory. Same for `ls-files` below,
  # which is cwd-relative already.
  let changed = (^git diff --name-only --relative HEAD | lines)

  {
    options: { sort: false }
    completions: (
      ^git for-each-ref --format '%(refname:short)' refs/heads
      | lines
      | parse '{value}'
      | insert description 'Local branch'
      | append (
        ^git for-each-ref --format '%(refname:lstrip=2)' refs/remotes
        | lines
        | parse '{value}'
        | insert description 'Remote branch'
      )
      | append ([HEAD ORIG_HEAD] | parse '{value}' | insert description 'Ref')
      | append ($changed | parse '{value}' | insert description 'Changed file')
      | append (
        # Tracked plus untracked-but-not-ignored, so the whole repo is reachable.
        # Only files, no directories: prefix matching on full paths covers those.
        ^git ls-files --cached --others --exclude-standard --deduplicate
        | lines
        | where $it not-in $changed
        | parse '{value}'
        | insert description 'File'
      )
    )
  }
}

# Log with more readable formatting
export def log --wrapped [
  ...rest: string@"nu-complete refs-or-files"
] {
  let $args = [
    '--graph',
    '--pretty=format:%C(yellow)%h%Creset %C(green)%ad%Creset %C(bold blue)%an%Creset %C(auto)%d%n%Creset%s%C(dim white)%b%Creset%n',
    '--date=human',
    '--color',
    ...$rest
  ]

  ^git log ...$args
}

# Log with Nushell table
# See: https://www.nushell.sh/cookbook/parsing_git_log.html
export def "log table" --wrapped [
  ...rest
] {
  let $args = [
    '-n',
    '100',
    "--pretty=format:%C(yellow)%h%Creset»¦«%aD»¦«%C(bold blue)%an%Creset»¦«%C(auto)%d%Creset»¦«%s%n%C(dim white)%b%Creset¦¦¦",
    '--color',
    ...$rest
  ]

  ^git log ...$args
  | split row "¦¦¦"
  | split column "»¦«" commit date name branch message
  | str trim # Removes newline characters proceeding each record
  | drop 1 # Removes last empty record
  | upsert date {|d| $d.date | into datetime}
}

# Log a branch interactively with a branch menu
export def "log menu" --wrapped [
  ...rest
] {
  let $selection = (select branch --extra ["  HEAD", "  --all"])
  if ($selection.branch? | is-empty) { return }

  log $selection.branch
}