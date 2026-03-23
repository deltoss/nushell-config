export-env {
  $env.ZOXIDE_FZF_CUSTOM_PREVIEW = 'eza --tree --level=1 --colour=always --icons=always ({}  | str replace --all --regex "[^\t]+\t" "")'

  $env._ZO_FZF_OPTS = $env.FZF_DEFAULT_OPTS ++ $" --preview='($env.ZOXIDE_FZF_CUSTOM_PREVIEW)'"
}

job spawn {
  zoxide init nushell | save -f ~/.zoxide.nu
}

source ~/.zoxide.nu

# Overrides z command that uses the custom command `search everything`
# if the queried common directory doesn't exist in zoxide
def --env z [...args] {
  let query = ($args | str join " ")
  if ($query == "~") {
    cd "~"
    return
  }

  let result = zoxide query ...$args | complete

  if ($result.exit_code != 0) {
    let selection = ($query | search everything) | get --optional selections.0
    if ($selection | is-not-empty) {
      cd $selection
    }
  } else {
    cd ($result.stdout | str trim)
  }
}