use ../tools/tui.nu [tui-link-actions]

def --wrapped run-pup-json [...arguments: string] {
  let command_result = ^pup --read-only --no-envelope --output json ...$arguments | complete
  if $command_result.exit_code != 0 {
    error make {msg: $"Pup failed: ($command_result.stderr | str trim)"}
  }
  $command_result.stdout | from json
}

def browser-base-url [site: string] {
  # Bare sites use app.; regional sites already identify the browser host.
  let browser_host = if $site in [datadoghq.com datadoghq.eu ddog-gov.com datad0g.com] {
    $"app.($site)"
  } else {
    $site
  }
  $"https://($browser_host)"
}

# Find Datadog monitors matching a search.
#
# Authenticate with `pup auth login` first. Pup manages the site and credentials.
# DATADOG_MONITOR_QUERY sets the default search; --query overrides it.
@example "Find production alerts" {
  datadog list --query 'env:prod status:Alert'
}
export def list [
  --query: string # Datadog monitor search; defaults to Alert, Warn and No Data
] {
  if (which pup | is-empty) {
    error make {msg: "Pup is required. Install it with: mise use -g github:DataDog/pup"}
  }
  let authentication_status = run-pup-json auth status
  if not $authentication_status.authenticated {
    error make {msg: "Sign in to Datadog first with: pup auth login"}
  }
  let browser_url = browser-base-url $authentication_status.site
  let monitor_query = $query
    | default $env.DATADOG_MONITOR_QUERY?
    | default 'status:(Alert OR Warn OR "No Data")'

  run-pup-json monitors search --query $monitor_query --page '0' --per-page '20' --sort 'status,asc'
  | get monitors
  | each {|monitor|
      {
        key: ($monitor.id | into string)
        name: $monitor.name
        status: $monitor.status
        url: $"($browser_url)/monitors/($monitor.id)"
      }
    }
}

def load-monitor-rows [monitor_query?: string] {
  list --query $monitor_query | each {|monitor|
    { ...$monitor, Status: $monitor.status, Name: $monitor.name }
  }
}

# Build a Datadog monitor widget for composition.
@example "Compose an interactive Datadog widget" {
  datadog widget | tui run
}
export def widget [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
] {
  let display_columns = [Status Name]
  load-monitor-rows $query
  | tui search --id datadog-query --bind / --fuzzy --columns $display_columns
  | tui table --id datadog-rows --focus --multi --columns $display_columns
  | tui bind ctrl+r {|tui_state|
      # Checked rows use positions, so unmark before replacing the data.
      if ($tui_state.values.datadog-rows.checked? | is-not-empty) { return }
      load-monitor-rows $query
    }
  | tui-link-actions
}

# Browse Datadog monitors interactively.
@example "Browse monitors needing attention" {
  datadog tui
}
export def tui [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
] {
  widget --query $query
  | tui label --status "Ctrl+R: refresh (unmark first)  Space: mark  y: IDs  Y: URLs  b: browse  /: search  q: quit"
  | tui run
  | ignore
}