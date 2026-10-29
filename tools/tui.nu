# Keep the original record separate from display-only column labels.
def display-rows [columns: list<string>] {
  $in | each {|row|
    $row | select --optional ...$columns
      | rename --block { str pascal-case }
      | insert __tui_picker_row $row
  }
}

# Pick records from a searchable table.
# Display and search only the given columns, with PascalCase labels.
# Return the selected records with their original keys and all fields.
# By default, returns one record or a list with --multi. Cancellation returns null or [].
# An optional preview closure receives the highlighted record and returns text.
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
  --preview: closure
  --on-submit: closure # Receives the original selection (possibly null) and search query.
  --on-new: closure # Ctrl+N: receives the query and returns a new record, or null to stay open.
] {
  let rows = $in
  if ($rows | is-empty) and $on_new == null {
    return (if $multi { [] } else { null })
  }

  let columns = if ($columns | is-empty) { $rows | columns } else { $columns }
  let labels = $columns | str pascal-case
  if ($labels | uniq | length) != ($labels | length) {
    error make {msg: "Display columns must have distinct PascalCase names"}
  }
  let display = $rows | display-rows $columns

  let hint = if $multi {
    " / : Move  /: Filter  Space: Check  Enter: Confirm  Ctrl+C: Cancel"
  } else {
    " / : Move  /: Filter  Enter: Select  Ctrl+C: Cancel"
  }

  let hint = if $on_new == null { $hint } else { $hint + "  Ctrl+N: New" }
  let ui = ($display
    | tui label --titlebar $title
    | tui search --id picker-query --bind / --fuzzy --columns $labels --placeholder "/ to search")
  let ui = if $preview == null {
    $ui | tui table --focus --columns $labels --multi=$multi
  } else {
    $ui | tui split --id picker-layout --sizes [40% 1fr] [
      (tui table --id picker-rows --focus --columns $labels --multi=$multi)
      (tui preview --from picker-rows --title Preview {|row| do $preview $row.__tui_picker_row })
    ]
  }
  let ui = if $on_new == null {
    $ui
  } else {
    $ui | tui bind ctrl+n {|state|
      let candidate = do $on_new $state.values.picker-query
      if $candidate == null {
        null
      } else {
        {action: submit, selected: {__tui_picker_row: $candidate}}
      }
    }
  }
  let result = $ui | tui label --status $hint | tui run

  if $result.action != "submit" {
    return (if $multi { [] } else { null })
  }

  # Ctrl+N carries its own row; Enter on the splitter only carries layout sizes.
  let is_record = ($result.selected | describe) =~ '^record'
  let has_candidate = $is_record and ("__tui_picker_row" in ($result.selected | columns))
  let submitted = if $result.focused == "picker-layout" and not $has_candidate {
    let state = $result.values.picker-rows
    if $multi and ($state.checked | is-not-empty) { $state.checked } else { $state.row }
  } else {
    $result.selected
  }
  let selected = if not $multi {
    $submitted.__tui_picker_row?
  } else if ($submitted | is-empty) {
    []
  } else if ($submitted | describe) =~ '^(table|list)' {
    $submitted | get __tui_picker_row
  } else {
    [$submitted.__tui_picker_row]
  }
  if $on_submit != null {
    do $on_submit $selected $result.values.picker-query
  } else {
    $selected
  }
}