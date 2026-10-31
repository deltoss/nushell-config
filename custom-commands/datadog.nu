use ../tools/tui.nu [tui-link-actions]

def --wrapped pup-json [...args: string] {
  let result = ^pup --read-only --no-envelope --output json ...$args | complete
  if $result.exit_code != 0 {
    error make {msg: $"Pup failed: ($result.stderr | str trim)"}
  }
  $result.stdout | from json
}

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
  let auth = pup-json auth status
  if not $auth.authenticated {
    error make {msg: "Sign in to Datadog first with: pup auth login"}
  }
  # Bare sites use app.; regional sites already identify the browser host.
  let host = if $auth.site in [datadoghq.com datadoghq.eu ddog-gov.com datad0g.com] {
    $"app.($auth.site)"
  } else {
    $auth.site
  }
  let query = $query | default ($env.DATADOG_MONITOR_QUERY? | default 'status:(Alert OR Warn OR "No Data")')
  pup-json monitors search --query $query --page '0' --per-page '20' --sort 'status,asc'
  | get monitors
  | each {|monitor|
      {
        key: ($monitor.id | into string)
        name: $monitor.name
        status: $monitor.status
        url: $"https://($host)/monitors/($monitor.id)"
      }
    }
}

def display-rows [query?: string] {
  list --query $query | each {|monitor|
    { ...$monitor, Status: $monitor.status, Name: $monitor.name }
  }
}

@example "Compose an interactive Datadog widget" {
  datadog widget | tui run
}
export def widget [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
] {
  let columns = [Status Name]
  display-rows $query
  | tui search --id datadog-query --bind / --fuzzy --columns $columns
  | tui table --id datadog-rows --focus --multi --columns $columns
  | tui bind ctrl+r {|state|
      # Checked rows use positions, so unmark before replacing the data.
      if ($state.values.datadog-rows.checked? | is-not-empty) { return }
      display-rows $query
    }
  | tui-link-actions
}

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