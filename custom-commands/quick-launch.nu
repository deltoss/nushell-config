# Interactive launcher menu. Press a key to launch an app inline.
export def --env main [] {
  let entries = [
    { key: 't', label: 'Default Shell',              action: {|| nu -e zellij } }
    { key: 'T', label: 'Admin Nushell',              action: {|| gsudo nu -e zellij } }
    { key: 'n', label: 'Neovim',                     action: {|| nvim } }
    { key: 'y', label: 'Yazi',                       action: {|| nu -e y } }
    { key: 'p', label: 'PowerShell',                 action: {|| pwsh -NoLogo } }
    { key: 'P', label: 'Admin PowerShell',           action: {|| pwsh -NoProfile -NoLogo -c gsudo } }
    { key: '1', label: 'Neovim: Note Taking',        action: {|| cd (^zoxide query "Note Taking" | str trim); nvim . } }
    { key: '2', label: 'Neovim: Org Notes',          action: {|| cd (^zoxide query "Org Notes" | str trim); nvim . } }
    { key: '3', label: 'Neovim: Neovim Configs',     action: {|| cd (^zoxide query .config nvim | str trim); nvim . } }
    { key: '4', label: 'Neovim: Wezterm Configs',    action: {|| cd (^zoxide query .config wezterm | str trim); nvim . } }
    { key: '5', label: 'Neovim: PowerShell Profile', action: {|| cd (^zoxide query .config PowerShell | str trim); nvim . } }
    { key: '6', label: 'Neovim: Nushell Configs',    action: {|| cd (^zoxide query .config nushell | str trim); nvim . } }
    { key: '7', label: 'Neovim: Chezmoi - Personal/Work', action: {|| cd (^chezmoi source-path | str trim); nvim . } }
    { key: '8', label: 'Neovim: Chezmoi - Servers',  action: {|| cd (^zoxide query serversdotfiles | str trim); nvim . } }
    { key: '9', label: 'Neovim: HTTP Requests',      action: {|| cd ~/HTTP; nvim . } }
  ]

  for e in $entries {
    print $"(ansi bo)(ansi cyan)($e.key)(ansi bl) ⟶ (ansi reset)($e.label)"
  }
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      ['q', []] => { break }
      _ => {
        let hit = ($entries | where key == $key.code)
        if ($hit | is-empty) {
          print "That key wasn't recognized."
        } else {
          do ($hit | first | get action)
          break
        }
      }
    }
  }
}