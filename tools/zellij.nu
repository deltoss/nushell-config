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
# tab has a useless default name ("Tab #1" etc) or starts with an emoji,
# which means it was auto-renamed. Manually named tabs are left alone.
if 'ZELLIJ' in $env {
  # Programs (pi, nvim, ...) overwrite the pane title and zellij restores the
  # default one on exit, so re-assert it before every prompt. This is just an
  # escape sequence, no subprocess, so it's cheap enough to run every time.
  $env.config.hooks.pre_prompt = (
    $env.config.hooks.pre_prompt? | default [] | append {||
      let folder = ($env.PWD | path basename)
      if $folder != '' {
        print --no-newline $"\e]2;📂 ($folder)\u{7}"
      }
    }
  )

  $env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | append {||
      let focused = (
        ^zellij action dump-layout
        | lines
        | parse --regex 'tab name="(?<name>[^"]*)"(?<attrs>[^{]*)'
        | where attrs =~ 'focus=true'
        | get -o 0.name
        | default ''
      )
      let folder = ($env.PWD | path basename)
      let label = $"📂 ($folder)"
      if $folder != '' and ($focused =~ '^([Tt]ab|\p{Extended_Pictographic})') {
        ^zellij action rename-tab $label
      }
    }
  )
}