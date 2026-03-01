use ../tools/visual-studio.nu [devenv]
use ./fzf-helpers.nu ['parse fzf']

# Search for items
export def main []: nothing -> nothing {
}

# Search for commonly used directories
export def zoxide []: string -> path, nothing -> path {
  let query = $in | default ""
  zoxide query --interactive $query
}

# Search for everything on your PC
@example "With piped query" { ".json" | search everything }
export def everything []: string -> path, nothing -> path {
  let query = $in
  let searchCommandTemplate = match $nu.os-info.name {
    "windows" => "es count:100 -p -r {q:1} -r {q:2} -r {q:3} -r {q:4} -r {q:5} -r {q:6} -r {q:7} -r {q:8} -r {q:9}"
    _ => null
  }
  if ($searchCommandTemplate | is-empty) {
    error make { msg: $"Searching everything not supported for your OS ($nu.os-info.name)" }
  }
  if ($query | is-not-empty) {
    return (fzf --bind $"start:reload:($searchCommandTemplate)" --bind $"change:reload-sync\(sleep 100ms; ($searchCommandTemplate)\)" --print-query --query $query --header="Search - Everything") | parse fzf
  }

  # Pipe null to disable the initial unnecessary search upon entering fzf
  # Sleep command is there to debounce the query so we don't search on every single letter typed
  null | fzf --bind $"change:reload-sync\(sleep 100ms; ($searchCommandTemplate)\)" --phony --print-query --query "" --header="Search - Everything" | parse fzf
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
      ^es ...['/a-d' '-p' '-r' `!'\\\$Recycle.Bin\'` '-r' `!'C:\\Windows'` '-r' '.sln$']
    }
    _ => null
  }
  if ($results == null) {
    error make { msg: $"Searching everything not supported for your OS ($nu.os-info.name)" }
  }

  $results | fzf --multi --header='Search - .NET Solutions (Tab to Select)' --print-query --query $query | parse fzf
}


# Search for notes on your PC
export def "notes" []: string -> any, nothing -> any {
  let query = $in | default ''
  fd . ("~/Documents/Note Taking" | path expand) ("~/Documents/Org Notes" | path expand) | fzf --header="Search - Obsidian Notes" --print-query --query $query --preview $env.FZF_CUSTOM_PREVIEW | parse fzf
}

# Search for code in current directory
export def "code" []: string -> any, nothing -> any {
  let query = $in | default ''
  let rg_prefix = "rg --column --line-number --no-heading --color=always --smart-case"

  (fzf --ansi --disabled --query $query --print-query
    --bind $"start:reload-sync:($rg_prefix) {q}"
    --bind $"change:reload-sync:($rg_prefix) {q}"
    --delimiter ":"
    --preview "bat --color=always {1} --highlight-line {2}"
    --preview-window "up,60%,border-bottom,+{2}+3/3,~3"
    --header "Search - Code") | parse fzf --code
}

