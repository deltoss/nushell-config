source ../env.nu

# Interactive launcher menu. Press a key to launch an app inline.
export def --env main [] {
  let entries = [
    { key: 't', label: 'Nushell',                          action: {|| nu } }
    { key: 'T', label: 'Admin Nushell',                    action: {|| gsudo nu } }
    { key: 'n', label: 'Neovim',                           action: {|| nu -e nvim } }
    { key: 'y', label: 'Yazi',                             action: {|| nu -e y } }
    { key: 'p', label: 'PowerShell',                       action: {|| pwsh -NoLogo } }
    { key: 'P', label: 'Admin PowerShell',                 action: {|| pwsh -NoProfile -NoLogo -c gsudo } }
    { key: 'c', label: 'Zellij: Configs',                  action: {|| nu -c "source ~/.config/nushell/tools/zellij.nu; zjC" } }
    { key: 'N', label: 'Zellij: Notes',                    action: {|| nu -c "source ~/.config/nushell/tools/zellij.nu; zjn" } }
    { key: 'h', label: 'HTTP Requests',                    action: {|| cd ~/HTTP; nvim . } }
  ]

  print $"(ansi blue)╭────────────────────────────────────────────────╮(ansi reset)"
  print $"(ansi blue)│(ansi reset)  (ansi cyan_bold)🚀 QUICK LAUNCH(ansi reset)  —  (ansi green)press a key to launch ✨(ansi reset)  (ansi blue)│(ansi reset)"
  print $"(ansi blue)╰────────────────────────────────────────────────╯(ansi reset)"

  for e in $entries {
    print $"  (ansi bo)(ansi cyan)($e.key)(ansi bl) ⟶ (ansi reset)($e.label)"
  }
  print $"  (ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      ['q', []] | ['esc', []] => { break }
      _ => {
        let hit = ($entries | where key == $key.code)
        if ($hit | is-empty) {
          print "That key wasn't recognized."
        } else {
          clear
          do ($hit | first | get action)
          break
        }
      }
    }
  }
}