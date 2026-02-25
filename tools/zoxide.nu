export-env {
  $env.ZOXIDE_FZF_CUSTOM_PREVIEW = 'eza --tree --level=1 --colour=always --icons=always ({}  | str replace --all --regex "[^\t]+\t" "")'

  $env._ZO_FZF_OPTS = $env.FZF_DEFAULT_OPTS ++ $" --preview='($env.ZOXIDE_FZF_CUSTOM_PREVIEW)'"
}

job spawn {
  zoxide init nushell | save -f ~/.zoxide.nu
}

source ~/.zoxide.nu
