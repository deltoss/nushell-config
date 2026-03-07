use ../tools/visual-studio.nu [devenv]
use ./fzf-helpers.nu ['parse fzf']
use ./run.nu

# Search for items
export def --env main []: nothing -> nothing {
  menu
}

# Bring up interactive menu for search operations
export def --env menu []: nothing -> nothing {
  print $"(ansi bo)(ansi cyan)e(ansi bl) ⟶ (ansi reset)[(ansi bo)E(ansi reset)]verything"
  print $"(ansi bo)(ansi cyan)f(ansi bl) ⟶ (ansi reset)[(ansi bo)F(ansi reset)]iles"
  print $"(ansi bo)(ansi cyan)F(ansi bl) ⟶ (ansi reset)[(ansi bo)F(ansi reset)]iles in git repository"
  print $"(ansi bo)(ansi cyan)g(ansi bl) ⟶ (ansi reset)[(ansi bo)G(ansi reset)]rep"
  print $"(ansi bo)(ansi cyan)r(ansi bl) ⟶ (ansi reset)[(ansi bo)R(ansi reset)]epositories"
  print $"(ansi bo)(ansi cyan)n(ansi bl) ⟶ .(ansi reset)[(ansi bo)N(ansi reset)]otes"
  print $"(ansi bo)(ansi cyan)N(ansi bl) ⟶ .(ansi reset)[(ansi bo)N(ansi reset)]ET"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  mut result = ''
  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['e', []] => { $result = everything; break }
      ['f', []] => { $result = files; break }
      ['F', ['keymodifiers(shift)']] => { $result = repository files; break }
      ['g', []] => { $result = grep; break }
      ['r', []] => { $result = repositories; break }
      ['n', []] => { $result = notes; break }
      ['N', ['keymodifiers(shift)']] => { $result = .net; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  if ($result | is-not-empty) {
    print ''
    $result.selections | run
  }
}

# Search for everything on your PC
@example "With piped query" { ".json" | search everything }
export def everything []: string -> path, nothing -> path {
  let query = $in
  let search_template = match $nu.os-info.name {
    "windows" => "es count:100 -p -r {q:1} -r {q:2} -r {q:3} -r {q:4} -r {q:5} -r {q:6} -r {q:7} -r {q:8} -r {q:9}"
    _ => null
  }
  if ($search_template | is-empty) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }
  if ($query | is-not-empty) {
    return (fzf --bind $"start:reload:($search_template)" --bind $"change:reload-sync\(sleep 100ms; ($search_template)\)" --print-query --query $query --header="Search - Everything") | parse fzf
  }

  # Pipe null to disable the initial unnecessary search upon entering fzf
  # Sleep command is there to debounce the query so we don't search on every single letter typed
  null | fzf --bind $"change:reload-sync\(sleep 100ms; ($search_template)\)" --phony --print-query --query "" --header="Search - Everything" | parse fzf
}

# Search for files from cwd
@example "With piped query" { ".sln" | search files }
export def files []: string -> path, nothing -> path {
  let query = $in
  let results = if ($query | is-not-empty) {
    fd $query
  } else {
    fd
  }
  $results | fzf --tac --header="Find - In Current Directory" --preview $env.FZF_CUSTOM_PREVIEW --print-query | parse fzf
}

# Search for .NET solutions on your PC
export def ".net" []: string -> any, nothing -> any {
  let query = $in | default ''
  let results = match $nu.os-info.name {
    "windows" => {
      ^es /a-d -p -r !'\\\$Recycle.Bin\' -r !'C:\\Windows' -r .sln$
    }
    _ => null
  }
  if ($results == null) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }

  $results | fzf --multi --header='Search - .NET Solutions (Tab to Select)' --print-query --query $query | parse fzf
}

# Search for notes on your PC
export def "notes" []: string -> any, nothing -> any {
  let query = $in | default ''
  fd . ("~/Documents/Note Taking" | path expand) ("~/Documents/Org Notes" | path expand) | fzf --header="Search - Obsidian Notes" --print-query --query $query --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

# Search for file content in current directory
export def "grep" []: string -> any, nothing -> any {
  let query = $in | default ''
  let rg_prefix = "rg --column --line-number --no-heading --color=always --smart-case"

  (fzf --ansi --disabled --query $query --print-query
    --bind $"start:reload-sync:($rg_prefix) {q}"
    --bind $"change:reload-sync:($rg_prefix) {q}"
    --delimiter ":"
    --preview "bat --color=always {1} --highlight-line {2}"
    --preview-window "up,60%,border-bottom,+{2}+3/3,~3"
    --header "Search - Grep") | parse fzf --grep
}

# Search for git repositories on your PC
export def "repositories" []: string -> any, nothing -> any {
  let query = $in | default ''
  let results = match $nu.os-info.name {
    "windows" => {
      ^es -p -r child:^\.git$
    }
    _ => null
  }
  if ($results == null) {
    error make { msg: $"This search is not supported for your OS: ($nu.os-info.name)" }
  }

  $results | fzf --header="Search - Git Repositories" --query $query --print-query --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

# Search for files in the current git repository
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