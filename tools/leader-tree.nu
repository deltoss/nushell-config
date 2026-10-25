# Navigate preloaded menu records without running commands.
def item-at [items: list, path: list] {
  $path | reduce --fold {children: $items} {|key, item|
    $item.children? | default [] | where key == $key | get --optional 0
  }
}

def rows [items: list, path: list] {
  (item-at $items $path).children
  | each {|item| {label: $"($item.key) ($item.label)", path: ($path | append $item.key)}}
}

def tree [items: list] {
  $items | reduce --fold {} {|item, result|
    $result | insert $"($item.key) ($item.label)" (tree ($item.children? | default []))
  }
}

def chord [key: string] {
  if $key =~ '^[A-Z]$' { $"shift+($key | str lowercase)" } else { $key }
}

def chords [items: list] {
  $items | each --flatten {|item|
    [(chord $item.key) ...(chords ($item.children? | default []))]
  } | uniq
}

def choose [items: list, path: list] {
  let item = (item-at $items $path)
  if ($item | describe) == "nothing" { return null }
  if ($item.children? | default [] | is-not-empty) {
    rows $items $path
  } else if ($item.action? | describe) =~ "^closure" {
    {action: submit, selected: $path}
  }
}

def shortcut [items: list, state: record, key: string] {
  let path = ($state.values.choices.row.path? | default [])
  let parent = ($path | drop 1)
  let item = ((item-at $items $parent).children
    | where {|item| (chord $item.key) == $key }
    | get --optional 0)
  if ($item | describe) != "nothing" {
    choose $items ($parent | append $item.key)
  }
}

def enter [items: list, state: record] {
  let path = if $state.focused == "menu-tree" {
    let tree_path = ($state.values.menu-tree.path? | default "")
    $tree_path | split row "/" | each {|part| $part | split row " " | first }
  } else {
    $state.values.choices.row.path? | default []
  }
  choose $items $path
}

def back [items: list, state: record] {
  let path = ($state.values.choices.row.path? | default [])
  if ($path | length) > 1 {
    rows $items ($path | drop 2)
  }
}

# Keep the menu data separate from its interactive runner for headless tests.
export def menu-ui [items: list] {
  let ui = (rows $items []
    | tui label --titlebar "Commands"
    | tui split --sizes [45% 1fr] [
        (tui tree --id menu-tree --title "All commands" --data (tree $items))
        (tui select --id choices --title "Current menu" --display label --focus)
      ]
    | tui label --status "letter: open/run  Enter: choose  Tab: tree  Backspace: back  q/Esc: quit")
  (chords $items | reduce --fold $ui {|key, app|
    $app | tui bind $key {|state| shortcut $items $state $key }
  })
  | tui bind enter {|state| enter $items $state }
  | tui bind backspace {|state| back $items $state }
}

export def selected-action [items: list, path: list] {
  (item-at $items $path).action?
}

# Close the TUI before launching the selected command.
export def --env run-menu [items: list] {
  let result = (menu-ui $items | tui run)
  if $result.action == "submit" {
    let action = (selected-action $items $result.selected)
    if ($action | describe) =~ '^closure' {
      do --env $action
    }
  }
}
