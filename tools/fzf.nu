export-env {
  $env.FZF_DEFAULT_COMMAND = 'fd --type f'
  $env.FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border --with-shell "nu -c"'
  $env.FZF_CUSTOM_PREVIEW = 'if ({} | path type) == "dir" { eza --tree --level=1 --colour=always --icons=always {} } else { bat --color=always --style=numbers --line-range=:500 {} }'
}
