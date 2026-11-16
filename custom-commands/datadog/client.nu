export def browser-base-url [site: string]: nothing -> string {
  # Bare sites use app.; regional sites already identify the browser host.
  let browser_host = if $site in [datadoghq.com datadoghq.eu ddog-gov.com datad0g.com] {
    $"app.($site)"
  } else {
    $site
  }
  $"https://($browser_host)"
}

export def --wrapped run-pup-json [...arguments: string] {
  if (which '^pup' | is-empty) {
    error make {msg: "Pup is required. Install it with: mise use -g github:DataDog/pup"}
  }
  let command_result = ^pup --read-only --no-envelope --output json ...$arguments | complete
  if $command_result.exit_code != 0 {
    error make {msg: $"Pup failed: ($command_result.stderr | str trim)"}
  }
  $command_result.stdout | from json
}
