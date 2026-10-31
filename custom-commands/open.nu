use ../tools/visual-studio.nu [devenv]

def "get folder" [] {
  if ($in | path type) == "dir" {
    $in
  } else {
    $in | path dirname
  }
}

# Open plain paths or search hits containing path, line, and column fields.
@example "Choose how to open a file" { "config.nu" | open with }
@example "Open a search hit at its location" { {path: "config.nu", line: 10, column: 1} | open with }
export def --env with []: string -> nothing, list<string> -> nothing, record -> nothing, table -> nothing {
  $in | menu
}

# Choose an application or directory action for piped paths.
@example "Choose how to open several files" { ["config.nu" "env.nu"] | open menu }
export def --env menu []: string -> nothing, list<string> -> nothing, record -> nothing, table -> nothing {
  let input = $in
  if ($input | is-empty) { return }

  let selections = match ($input | describe) {
    "string" => ($input | lines | compact --empty | each {|path| {path: $path} })
    "list<string>" => ($input | each {|path| {path: $path} })
    $kind if $kind =~ '^record' => [$input]
    $kind if $kind =~ '^table' => $input
    _ => {
      error make {msg: $"Could not handle unknown stdin type ($input | describe)"}
    }
  }
  if ($selections | is-empty) { return }
  let first_selection = $selections | first

  print $"(ansi bo)(ansi blue)=== Open With ===(ansi reset)"
  if (commandline | is-not-empty) {
    print $"(ansi bo)(ansi cyan)p(ansi bl) ⟶ (ansi reset)[(ansi bo)P(ansi reset)]rompt"
  }
  print ''

  print $"(ansi bo)(ansi cyan)== Programs ==(ansi reset)"
  print $"(ansi bo)(ansi cyan)n(ansi bl) ⟶ (ansi reset)[(ansi bo)N(ansi reset)]eovim"
  print $"(ansi bo)(ansi cyan)v(ansi bl) ⟶ (ansi reset)[(ansi bo)V(ansi reset)]isual Studio IDE"
  print ''

  print $"(ansi bo)(ansi cyan)== Folder ==(ansi reset)"
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)[(ansi bo)C(ansi reset)]hange Directory"
  print $"(ansi bo)(ansi cyan)y(ansi bl) ⟶ (ansi reset)[(ansi bo)Y(ansi reset)]azi"
  print $"(ansi bo)(ansi cyan)f(ansi bl) ⟶ (ansi reset)[(ansi bo)F(ansi reset)]ile Explorer"
  print ''

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['p', []] => { commandline edit --insert $first_selection.path; break }
      ['n', []] => {
        if ($first_selection.line? | is-not-empty) {
          let line = $first_selection.line | into int
          let column = $first_selection.column? | default 1 | into int
          ^nvim $"+call cursor\(($line),($column)\)" -- $first_selection.path
        } else {
          ^nvim -- $first_selection.path
        }
        break
      }
      ['v', []] => {
        $selections | par-each {|selection|
          devenv $selection.path
        }
        break
      }
      ['c', []] => { cd ($first_selection.path | get folder); break }
      ['y', []] => { y ($first_selection.path | get folder); break }
      ['f', []] => { start $first_selection.path; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }
}