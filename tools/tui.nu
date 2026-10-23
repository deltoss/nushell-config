# Pick records from a searchable table.
# Display and search only the given columns, but return the selected records with all fields.
# Returns one record, or a list with --multi. Cancellation returns null or [].
@example "Select an environment, keeping its ID" {
  [{name: "Dev", id: 1} {name: "Prod", id: 2}] | tui-picker "Environment" [name]
}
@example "Select multiple applications" {
  [{name: "Neovim", type: "editor"} {name: "Yazi", type: "files"}]
  | tui-picker "Applications" [name type] --multi
}
export def tui-picker [
  title: string
  columns: list<string>
  --multi
] {
  let rows = $in
  if ($rows | is-empty) {
    return (if $multi { [] } else { null })
  }

  let hint = if $multi {
    "up/down: move  /: filter  space: check  enter: confirm  ctrl+c: cancel"
  } else {
    "up/down: move  /: filter  enter: select  ctrl+c: cancel"
  }

  let result = (
    $rows
    | tui label --titlebar $title
    | tui search --bind / --fuzzy --columns $columns
    | tui table --focus --columns $columns --multi=$multi
    | tui label --status $hint
    | tui run --dialog
  )

  if $result.action != "submit" {
    return (if $multi { [] } else { null })
  }

  let selected = $result.selected
  if not $multi { return $selected }
  if ($selected | is-empty) { return [] }

  if ($selected | describe) =~ '^(table|list)' {
    $selected
  } else {
    [$selected]
  }
}
