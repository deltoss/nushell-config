let layouts_dir = if ($env.ZELLIJ_CONFIG_DIR | is-not-empty) {
  $'($env.ZELLIJ_CONFIG_DIR)/layouts'
} else {
  $'($env.XDG_HOME_DIR)/zellij/layouts'
}
export alias zjq = ^zellij --layout $'($layouts_dir)/quick-launch.kdl'
export alias zjc = ^zellij --layout $'($layouts_dir)/coding.kdl'
export alias zjC = ^zellij --layout $'($layouts_dir)/configs.kdl' options --session-name=configs --attach-to-session='true'
export alias zjn = ^zellij --layout $'($layouts_dir)/notes.kdl' options --session-name=notes --attach-to-session='true'