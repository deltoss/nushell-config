export-env {
  $env.FZF_DEFAULT_COMMAND = 'fd --type f'
  $env.FZF_DEFAULT_OPTS = '--style full --height 40% --layout=reverse --border --with-shell "nu -c"'
  $env.FZF_CUSTOM_PREVIEW = 'if ({} | path type) == "dir" { eza --tree --level=1 --colour=always --icons=always {} } else { bat --color=always --style=numbers --line-range=:500 {} }'
}

# Wraps fzf to handle nushell structured data such as tables, lists or records
@example "Select a value from a list" { ["option1" "option2"] | main }
@example "Select a record from a table" { ps | main }
@example "Select records from a table, displaying just the column name for fzf" { ps | main --columns [name] --multi }
@example "Select a record from a table, providing a custom display format for fzf" { ps | main --format {|it| $"($it.name) - ($it.pid)" } }
@example "Select field-value pair from a record" { { "name": "John", "surname": "Doe" } | main }
export def --wrapped main [
  # Columns to display for fzf interaction
  --columns: list<string>,
  --format: closure
  ...rest
]: [
  string -> string
  list<string> -> string
  record -> any
  table -> record
  # If --multi flag is used
  table -> table
  nothing -> any
] {
  let data = ($in | default null)
  if ($data | is-empty) {
    return (^fzf ...$rest)
  }

  let kind = ($data | describe)

  if $kind =~ '^list<string>' {
    $data | str join "\n" | ^fzf ...$rest
  } else if $kind =~ '^record' {
    $data | fzf record ...$rest
  } else if $kind =~ '^table' {
    $data | fzf table --columns $columns --format $format ...$rest
  } else {
    $data | ^fzf ...$rest
  }
}

# Selects a field value from a record using fzf
def "fzf record" [
  ...rest
]: [
  record -> record
  # If --multi flag is used
  record -> table
] {
  $in | transpose field value
  | each { |row| $"($row.field): ($row.value)" }
  | str join "\n"
  | ^fzf ...$rest
  | lines
  | each { |line|
      $line | split column --number 2 ": " field value
      | get 0
    }
  | if ($in | length) == 1 {
    get 0
  } else {
    $in
  }
}

# Selects a record or table from a table input using fzf
export def --wrapped "fzf table" [
  # Columns to display for fzf interaction
  --columns: list<string>,
  # Controls how to render the table items on fzf entry
  --format: closure
  ...rest
]: [
  table -> record
  # If --multi flag is used
  table -> table
] {
  let data = $in
  if ($data | is-empty) { return }

  let header_lines = if ($format | is-not-empty) {
    0
  } else {
    1
  }

  let display = if ($format | is-not-empty) {
    $data | each $format | str join "\n"
  } else if ($columns | is-not-empty) {
    $data | to tsv --columns $columns
  } else {
    $data | to tsv
  }

  let is_multi = $rest | any { |it| $it == "--multi" or $it == "-m" }

  let selection = $display
    # --accept-nth={n} gets the index of the selection
    | ^fzf $"--header-lines=($header_lines)" --accept-nth={n} ...$rest
    | complete

  # fzf: 1 = no match, 130 = cancelled with Esc or Ctrl-C.
  # Both are normal picker outcomes, so return nothing instead of raising an error.
  if $selection.exit_code in [1 130] { return }
  if $selection.exit_code != 0 {
    error make {msg: $"fzf failed: ($selection.stderr | str trim)"}
  }

  let result = $selection.stdout | lines | into int
    | each {|idx| $data | get ($idx - $header_lines) }

  if $is_multi {
    return $result
  }

  $result | first
}