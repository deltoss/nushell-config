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
    { key: '1', label: 'Note Taking',                      action: {|| cd (^zoxide query "Note Taking" | str trim); nu -e y } }
    { key: '2', label: 'Org Notes',                        action: {|| cd (^zoxide query "Org Notes" | str trim); nu -e y } }
    { key: '3', label: 'HTTP Requests',                    action: {|| cd ~/HTTP; nvim . } }
    { key: '3', label: 'Configs: Neovim Configs',          action: {|| cd (^zoxide query .config nvim | str trim); nu -e y } }
    { key: '4', label: 'Configs: Nushell',                 action: {|| cd (^zoxide query .config nushell | str trim); nu -e y } }
    { key: '5', label: 'Configs: Wezterm Configs',         action: {|| cd (^zoxide query .config wezterm | str trim); nu -e y } }
    { key: '7', label: 'Configs: Chezmoi - Personal/Work', action: {|| cd (^chezmoi source-path | str trim); nu -e y } }
    { key: '8', label: 'Configs: Chezmoi - Servers',       action: {|| cd (^zoxide query serversdotfiles | str trim); nu -e y } }
    { key: '6', label: 'Configs: PowerShell Profile',      action: {|| cd (^zoxide query .config PowerShell | str trim); nu -e y } }
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