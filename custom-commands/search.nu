use ../tools/leader-tree.nu [run-menu]
use ../tools/visual-studio.nu [devenv]
use ./fzf-helpers.nu ['parse fzf']
use ./open.nu

# Open the file and repository search menu.
@example "Choose a search" { search }
export def --env main []: nothing -> nothing {
  menu
}

# Choose a search and open its results.
@example "Open the search menu" { search menu }
export def --env menu [] { run-menu (menu-items) }

# Search for everything on your PC
@example "With piped query" { ".json" | search everything }
export def everything []: string -> record, nothing -> record {
  let query = $in
  let search_template = match $nu.os-info.name {
    "windows" => "es count:100 -p -r {q:1} -r {q:2} -r {q:3} -r {q:4} -r {q:5} -r {q:6} -r {q:7} -r {q:8} -r {q:9}"
    "linux" => "locate --ignore-case --limit 100 -r {q:1} {q:2} {q:3} {q:4} {q:5} {q:6} {q:7} {q:8} {q:9}"
    _ => null
  }
  if ($search_template | is-empty) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }
  if ($query | is-not-empty) {
    return (fzf --bind $"start:reload:($search_template)" --bind $"change:reload-sync\(sleep 100ms; ($search_template)\)" --print-query --query $query --header="Search - Everything" | parse fzf)
  }

  # Pipe null to disable the initial unnecessary search upon entering fzf
  # Sleep command is there to debounce the query so we don't search on every single letter typed
  null | fzf --bind $"change:reload-sync\(sleep 100ms; ($search_template)\)" --phony --print-query --query "" --header="Search - Everything" | parse fzf
}

# Search for files from cwd
@example "With piped query" { ".sln" | search files }
export def files []: string -> record, nothing -> record {
  let query = $in
  let results = if ($query | is-not-empty) {
    fd $query
  } else {
    fd
  }
  $results | fzf --tac --header="Find - In Current Directory" --preview $env.FZF_CUSTOM_PREVIEW --print-query | parse fzf
}

# Search for .NET solutions on your PC
@example "Find a solution by name" { "api" | search .net }
export def ".net" []: string -> record, nothing -> record {
  let query = $in | default ''
  let results = match $nu.os-info.name {
    "windows" => {
      ^es /a-d -p -r !'\\\$Recycle.Bin\' -r !'C:\\Windows' -r .sln$
    }
    "linux" => {
      ^locate -r \.sln$
    }
    _ => null
  }
  if ($results == null) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }

  $results | fzf --multi --header='Search - .NET Solutions (Tab to Select)' --print-query --query $query | parse fzf
}

# Search for notes on your PC
@example "Find notes by topic" { "nushell" | search notes }
export def "notes" []: string -> record, nothing -> record {
  let query = $in | default ''
  fd . ("~/Documents/Note Taking" | path expand) ("~/Documents/Org Notes" | path expand) | fzf --header="Search - Obsidian Notes" --print-query --query $query --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

# Search for file content in current directory
@example "Find text and choose matching lines" { "TODO" | search grep }
export def "grep" []: string -> record, nothing -> record {
  let query = $in | default ''
  const helper = path self "grep-helpers.nu"
  let reload = $"source ($helper | to nuon); main {q}"

  let result = (null | ^fzf --disabled --query $query --print-query
    --with-shell "nu --no-config-file --no-std-lib -c"
    --bind $"start:reload-sync:($reload)"
    --bind $"change:reload-sync:($reload)"
    --delimiter (char tab) --with-nth 3.. --accept-nth 1
    --preview 'let match = {1} | decode base64 | decode utf-8 | from json; ^bat --color=always --highlight-line $match.line -- $match.path'
    --preview-window "up,60%,border-bottom,+{2}+3/3,~3"
    --header "Search - Grep" | complete)
  if $result.exit_code in [1 130] { return {} }
  if $result.exit_code != 0 {
    error make {msg: $"Grep picker failed: ($result.stderr | str trim)"}
  }
  $result.stdout | parse fzf --grep
}

# Search for git repositories on your PC
@example "Find repositories and worktrees by name" { "api" | search repositories --include-worktrees }
export def "repositories" [
  --preferred: string # Show this repository first when it is among the search results
  --include-worktrees # Include linked worktrees and other .git-file checkouts
]: string -> record, nothing -> record {
  let query = $in | default ''
  let results = match $nu.os-info.name {
    "windows" => {
      let attributes = if $include_worktrees { [] } else { [/ad] }
      ^es ...$attributes -r ^\.git$ | lines | each { path dirname } | str join "\n"
    }
    "linux" => {
      ^locate '*/.git'
        | lines
        | where {|git_path| try {
          let kind = $git_path | path type
          $kind == 'dir' or ($include_worktrees and $kind == 'file')
        } catch { false } }
        | each { path dirname }
        | str join "\n"
    }
    _ => null
  }
  if ($results == null) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }

  if ($results | is-empty) { return {} }

  let repositories = $results | lines
  let ordered = if ($preferred | is-not-empty) {
    let preferred_path = $preferred | path expand
    $repositories | sort-by {|repo| ($repo | path expand) != $preferred_path }
  } else {
    $repositories
  }
  $ordered | str join "\n" | fzf --header="Search - Git Repositories" --query $query --print-query --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

# Search for files in the current git repository
@example "Find files in the repository" { "config" | search repository files }
export def "repository files" [] {
  let query = $in | default ''
  let repo_root = ^git rev-parse --show-toplevel
  let repo_files = ^fd "" $repo_root
  let repo_files = $repo_files | par-each {|full_path|
    let relative_path = $full_path | str substring ($repo_root | str length).. | str trim --left --char '\' | str trim --left --char '/'
    $"(ansi red)($relative_path)(ansi reset)"
  }
  $repo_files | fzf --tac --header="Find - In Current Repository" --query $query --print-query --ansi --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

def --env "open selection" [] {
  let result = $in
  if ($result.selections? | is-not-empty) {
    $result.selections | open with
  }
}

# Return search menu entries for composition.
@example "Inspect the menu labels" { search menu-items | get label }
export def menu-items [] {
  [
    {key: e, label: "[E]verything", action: {|| everything | open selection}}
    {key: f, label: "[F]iles", action: {|| files | open selection}}
    {key: F, label: "[F]iles in git repository", action: {|| repository files | open selection}}
    {key: g, label: "[G]rep", action: {|| grep | open selection}}
    {key: r, label: "[R]epositories", action: {|| repositories | open selection}}
    {key: n, label: ".[N]otes", action: {|| notes | open selection}}
    {key: N, label: ".[N]ET", action: {|| .net | open selection}}
  ]
}