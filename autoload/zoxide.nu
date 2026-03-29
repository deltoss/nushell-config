# Based on: https://www.nushell.sh/cookbook/custom_completers.html#zoxide-path-completions
def "nu-complete zoxide path" [context: string] {
  let parts = $context | str trim --left | split row " " | skip 1 | each { str downcase }
  let completions = (
    ^zoxide query --list --exclude $env.PWD -- ...$parts
      | lines
      | each {|dir|
        if ($parts | length) <= 1 {
          $dir
        } else {
          let dir_lower = $dir | str downcase
          let rem_start = $parts | drop 1 | reduce --fold 0 { |part, rem_start|
            ($dir_lower | str index-of --range $rem_start.. $part) + ($part | str length)
          }
          {
            value: ($dir | str substring $rem_start..),
            description: $dir
          }
        }
      }
  )

  {
    options: {
      sort: false,
      completion_algorithm: substring,
      case_sensitive: false,
    },
    completions: $completions,
  }
}

# Overrides z command that uses the custom command `search everything`
# if the queried common directory doesn't exist in zoxide
def --env --wrapped z [...rest: string@"nu-complete zoxide path"] {
  let query = ($rest | str join " ")
  if ($query == "~") {
    cd "~"
    return
  }

  let result = ^zoxide query --exclude $env.PWD ...$rest | complete

  if ($result.exit_code != 0) {
    let selection = ($query | search everything) | get --optional selections.0
    if ($selection | is-not-empty) {
      cd $selection
    }
  } else {
    cd ($result.stdout | str trim)
  }
}