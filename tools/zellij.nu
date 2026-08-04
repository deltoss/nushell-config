let layouts_dir = if ($env has 'ZELLIJ_CONFIG_DIR') {
  $'($env.ZELLIJ_CONFIG_DIR)/layouts'
} else {
  $'($env.XDG_CONFIG_HOME)/zellij/layouts'
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

# On cd, rename the zellij tab to the current folder name, but only while the
# tab has a useless default name ("Tab #1" etc) or a name this hook set itself
# (tracked in $env.ZELLIJ_DYNAMIC_TAB_NAME). Manually named tabs are left alone.
# The hook body is a string (not a closure) so the env var change persists.
if 'ZELLIJ' in $env {
  $env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | append r#'
      $env.ZELLIJ_DYNAMIC_TAB_NAME = (do {
        let focused = (
          ^zellij action dump-layout
          | lines
          | parse --regex 'tab name="(?<name>[^"]*)"(?<attrs>[^{]*)'
          | where attrs =~ 'focus=true'
          | get -o 0.name
          | default ''
        )
        let folder = ($env.PWD | path basename)
        let dynamic = ($env.ZELLIJ_DYNAMIC_TAB_NAME? | default '')
        if $folder != '' and ($focused =~ '^[Tt]ab' or $focused == $dynamic) {
          ^zellij action rename-tab $folder
          $folder
        } else {
          $dynamic
        }
      })
    '#
  )
}