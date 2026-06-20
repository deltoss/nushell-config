let layouts_dir = if ($env.ZELLIJ_CONFIG_DIR | is-not-empty) {
  $'($env.ZELLIJ_CONFIG_DIR)/layouts'
} else {
  $'($env.XDG_HOME_DIR)/zellij/layouts'
}

export alias zj = ^zellij

export def zjq [] {
  ^zellij --layout $'($layouts_dir)/quick-launch.kdl'
}

export def zjc [] {
  ^zellij --layout $'($layouts_dir)/coding.kdl'
}

export def zjC [] {
  let session = 'configs'
  let sessions = (^zellij list-sessions -s | complete | get stdout | lines)
  if ($session in $sessions) {
    ^zellij attach $session
  } else {
    ^zellij --layout $'($layouts_dir)/configs.kdl' options --session-name=$session
  }
}

export def zjn [] {
  let session = 'notes'
  let sessions = (^zellij list-sessions -s | complete | get stdout | lines)
  if ($session in $sessions) {
    ^zellij attach $session
  } else {
    ^zellij --layout $'($layouts_dir)/notes.kdl' options --session-name=$session
  }
}