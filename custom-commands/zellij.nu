# Bring up interactive menu for zellij operations
export def menu [] {
  print $"(ansi bo)(ansi cyan)n(ansi bl) ⟶ (ansi reset)[(ansi bo)N(ansi reset)]ew Pane"
  print $"(ansi bo)(ansi cyan)p(ansi bl) ⟶ (ansi reset)New [(ansi bo)P(ansi reset)]ane"
  print $"(ansi bo)(ansi cyan)s(ansi bl) ⟶ (ansi reset)New [(ansi bo)S(ansi reset)]tack"
  print $"(ansi bo)(ansi cyan)f(ansi bl) ⟶ (ansi reset)New [(ansi bo)F(ansi reset)]loat"
  print $"(ansi bo)(ansi cyan)t(ansi bl) ⟶ (ansi reset)New [(ansi bo)T(ansi reset)]ab"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['n', []] => { new pane; break }
      ['p', []] => { new pane; break }
      ['s', []] => { new stack; break }
      ['f', []] => { new float; break }
      ['t', []] => { new tab; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }
}

def "new pane" [] {
  ^zellij action new-pane --cwd $env.PWD --direction right | ignore
}

def "new float" [] {
  ^zellij action new-pane --cwd $env.PWD --floating --pinned true | ignore
}

def "new stack" [] {
  ^zellij action new-pane --cwd $env.PWD --stacked | ignore
}

def "new tab" [] {
  ^zellij action new-tab --cwd $env.PWD | ignore
}