export-env {
  $env.BAT_PAGER = "less" # On Windows, see: https://github.com/jftuga/less-Windows
  $env.BAT_THEME = "gruvbox-light"
}

export alias cat = bat --color=always --style=numbers
