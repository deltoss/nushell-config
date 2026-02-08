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
  let esTemplate = "es count:100 -p -r {q:1} -r {q:2} -r {q:3} -r {q:4} -r {q:5} -r {q:6} -r {q:7} -r {q:8} -r {q:9}"
  if ($query | is-not-empty) {
    fzf --bind $"start:reload:($esTemplate)" --bind $"change:reload-sync\(sleep 100ms; ($esTemplate)\)" --query $query --header="Search - Query"
    return
  }

  # Pipe null to disable the initial unnecessary search upon entering fzf
  # Sleep command is there to debounce the query so we don't search on every single letter typed
  null | fzf --bind $"change:reload-sync\(sleep 100ms; ($esTemplate)\)" --phony --query "" --header="Search - Query"
}
