use ./projects.nu

# Keep the original pair on each row so filtering never changes edit/delete identity.
def manager-widget [repository: string, message: string]: table -> any {
  let ui = ($in | each {|rule|
      {Hint: ($rule.hint | default '(repo root)'), Service: $rule.service, rule: $rule}
    }
    | tui label --titlebar $"Service hints | ($repository)"
    | tui label $message
    | tui search --id hint-search --bind / --fuzzy --columns [Hint Service]
    | tui table --id hint-rows --focus --columns [Hint Service]
    | tui label --status "a/Ctrl+N: Add  e/Enter: Edit  Delete: Remove  Ctrl+R: Refresh  /: Filter  q: Quit"
    | tui bind a {|| {action: submit, selected: {action: add}} }
    | tui bind ctrl+n {|| {action: submit, selected: {action: add}} }
    | tui bind ctrl+r {|| {action: submit, selected: {action: refresh}} })
  [[key action]; [e edit] [delete delete]] | reduce --fold $ui {|binding, ui|
    $ui | tui bind $binding.key {|state|
      let rule = $state.values.hint-rows.row?.rule?
      if $rule != null { {action: submit, selected: {action: $binding.action, rule: $rule}} }
    }
  }
}

def edit-rule [rule?: record] {
  mut draft = $rule | default {service: '', hint: null}
  mut message = ''
  let title = if $rule == null { 'Add service hint' } else { 'Edit service hint' }
  loop {
    let result = (tui label --titlebar $title
      | tui label 'Blank hint = repo root; directories end in /; regexes start with regex:'
      | tui label $message
      | tui textbox --id service --title Service --value $draft.service --focus
      | tui textbox --id hint --title Hint --value ($draft.hint | default '')
      | tui label --status 'Tab: Switch field  Enter: Save  Ctrl+C: Cancel'
      | tui run --dialog --size [90 16])
    if $result.action != 'submit' { return null }
    $draft = {service: $result.values.service, hint: $result.values.hint}
    let current = $draft
    let validated = try {
      {rule: (projects normalize-rule $current), message: ''}
    } catch {|error|
      {rule: null, message: $error.msg}
    }
    if $validated.rule != null { return $validated.rule }
    $message = $validated.message
  }
}

def confirm-delete [rule: record]: nothing -> bool {
  let result = (tui label --titlebar 'Remove service hint?'
    | tui label $"Service: ($rule.service)"
    | tui label $"Hint: ($rule.hint | default '(repo root)')"
    | tui button Cancel --focus
    | tui button Delete
    | tui run --dialog --size [80 12])
  $result.action == 'submit' and $result.selected == 'Delete'
}

# Uses the same list/add/remove operations as the CLI; edits replace one pair in a single write.
export def run-hint-manager [file: path, repository: string]: nothing -> nothing {
  mut message = ''
  loop {
    let hints = projects list-rules $file $repository
    let result = $hints | manager-widget $repository $message | tui run
    if $result.action != 'submit' { return }
    let action = match $result.selected {
      {action: $action} => { $action }
      {rule: $rule} => { 'edit' }
      _ => { continue }
    }
    $message = try {
      match $action {
        add => {
          let rule = edit-rule
          if $rule != null { projects save-rule $file $repository $rule }
        }
        edit => {
          let previous = $result.selected.rule
          let rule = edit-rule $previous
          if $rule != null { projects save-rule $file $repository $rule --previous $previous }
        }
        delete => {
          let rule = $result.selected.rule
          if (confirm-delete $rule) { projects remove-rule $file $repository $rule }
        }
        refresh => {}
      }
      ''
    } catch {|error|
      $error.msg
    }
  }
}
