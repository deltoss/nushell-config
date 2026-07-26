use ./search.nu
use ./ai.nu
use ./git.nu
use ./kill.nu
use ./zellij.nu

# Bring up leader menu to pick a command category (space in vi_normal)
export def menu [] {
  print $"(ansi bo)(ansi cyan)s(ansi bl) ⟶ (ansi reset)[(ansi bo)S(ansi reset)]earch"
  print $"(ansi bo)(ansi cyan)a(ansi bl) ⟶ (ansi reset)[(ansi bo)A(ansi reset)]I"
  print $"(ansi bo)(ansi cyan)g(ansi bl) ⟶ (ansi reset)[(ansi bo)G(ansi reset)]it"
  print $"(ansi bo)(ansi cyan)k(ansi bl) ⟶ (ansi reset)[(ansi bo)K(ansi reset)]ill"
  print $"(ansi bo)(ansi cyan)l(ansi bl) ⟶ (ansi reset)Quick [(ansi bo)L(ansi reset)]aunch"
  print $"(ansi bo)(ansi cyan)z(ansi bl) ⟶ (ansi reset)[(ansi bo)Z(ansi reset)]ellij"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['s', []] => { print ''; search menu; break }
      ['a', []] => { print ''; ai menu; break }
      ['g', []] => { print ''; git menu; break }
      ['k', []] => { print ''; kill menu; break }
      ['l', []] => { print ''; ^nu --no-config-file --no-std-lib ~/.config/nushell/custom-commands/quick-launch.nu; break }
      ['z', []] => { print ''; zellij menu; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }
}
