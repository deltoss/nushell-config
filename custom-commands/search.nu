# Search for items
export def main []: nothing -> nothing {
}

# Search for commonly used directories
export def zoxide []: nothing -> path {
   zoxide query --interactive
}

# Search for everything on your Windows PC
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
    fzf --bind $"start:reload:($searchCommandTemplate)" --bind $"change:reload-sync\(sleep 100ms; ($searchCommandTemplate)\)" --query $query --header="Search - Everything"
    return
  }

  # Pipe null to disable the initial unnecessary search upon entering fzf
  # Sleep command is there to debounce the query so we don't search on every single letter typed
  null | fzf --bind $"change:reload-sync\(sleep 100ms; ($searchCommandTemplate)\)" --phony --query "" --header="Search - Everything"
}

# Search for files from cwd
@example "With piped query" { ".sln" | search files }
export def files []: string -> path, nothing -> path {
  let query = $in
  if ($query | is-not-empty) {
    fd $query | fzf --tac --header="Find - In Current Directory" --preview $env.FZF_CUSTOM_PREVIEW
    return
  }

  fd | fzf --tac --header="Find - In Current Directory" --preview $env.FZF_CUSTOM_PREVIEW
}
