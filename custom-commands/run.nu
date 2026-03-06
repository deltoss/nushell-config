use ../tools/visual-studio.nu [devenv]

def "get folder" [] {
  if ($in | path type) == "dir" {
    $in
  } else {
    $in | path dirname
  }
}

# Run a program for stdin
export def --env main []: string -> nothing, list<string> -> nothing {
  $in | menu
}

# Run a program for stdin interactively
export def --env menu []: string -> nothing, list<string> -> nothing {
  let $input = $in
  let selections = match ($input | describe) {
    "string" => ($input | split row "\n" | compact --empty)
    "list<string>" => $input
    _ => {
      error make {msg: $"Could not handle unknown stdin type ($input | describe)"}
    }
  }
  let first_selection = $selections | first

  print "=== Open With ==="
  if (commandline | is-not-empty) {
    print $"(ansi bo)(ansi cyan)p(ansi bl) ⟶ (ansi reset)[(ansi bo)P(ansi reset)]rompt"
  }
  print ''

  print "== Programs =="
  print $"(ansi bo)(ansi cyan)n(ansi bl) ⟶ (ansi reset)[(ansi bo)F(ansi reset)]eovim"
  print $"(ansi bo)(ansi cyan)v(ansi bl) ⟶ (ansi reset)[(ansi bo)V(ansi reset)]isual Studio IDE"
  print ''

  print "== Folder =="
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)[(ansi bo)C(ansi reset)]hange Directory"
  print $"(ansi bo)(ansi cyan)y(ansi bl) ⟶ (ansi reset)[(ansi bo)Y(ansi reset)]azi"
  print $"(ansi bo)(ansi cyan)f(ansi bl) ⟶ (ansi reset)[(ansi bo)F(ansi reset)]ile Explorer"
  print ''

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['p', []] => { commandline edit --insert $first_selection; break }
      ['n', []] => {
        ^nvim $first_selection
        break
      }
      ['v', []] => {
        $selections | inspect | par-each {|selection|
          devenv $selection
        }
        break
      }
      ['c', []] => { cd ($first_selection | get folder); break }
      ['y', []] => { y ($first_selection | get folder); break }
      ['f', []] => { start $first_selection; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }
}