use ../tools/tui.nu [tui-link-actions tui-picker]
use ../tools/datadog.nu [browser-base-url run-pup-json run-log-browser validate-log-options]

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
  datadog monitor widget | tui run
}
export def "monitor widget" [
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
  datadog monitor tui
}
export def "monitor tui" [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
] {
  monitor widget --query $query
  | tui label --status "Ctrl+R: Refresh (unmark first)  Space: Check  y: Copy IDs  Y: Copy URLs  b: Browse  /: Filter  q: Quit"
  | tui run
  | ignore
}

def project-service-name [] {
  # Repository detection is stubbed; DD_SERVICE supplies the name for now.
  let service = $env.DD_SERVICE? | default "" | str trim
  if ($service | is-empty) {
    error make {msg: "Service detection is not implemented yet. Set $env.DD_SERVICE to your Datadog service name"}
  }
  $service
}

# Select an environment with recent logs for a Datadog service.
#
# Cancellation returns null.
@example "Choose an environment for a service" {
  datadog select environment orders-api
}
export def "select environment" [service: string] {
  let environments = (run-pup-json logs aggregate
    --query $"service:($service | to json --raw)" --from 7d
    --compute count --group-by env --limit '1000'
    | get data.buckets
    | get --optional by.env
    | compact --empty | uniq | sort
    | each {|environment| {environment: $environment} })
  if ($environments | is-empty) {
    error make {msg: $"No environments found in recent logs for ($service). Use datadog logs tui --env <name> to specify one"}
  }
  let selected = $environments | tui-picker $"Select environment for ($service)" [environment]
  $selected.environment?
}

# Browse a service's Datadog logs with paging and editable query settings.
#
# Service detection currently reads DD_SERVICE. Omit --env to choose an environment.
# Refresh and query changes restart at the first page.
# Search uses Datadog syntax within the selected service and environment; an empty query clears it.
# Browsing opens the current search and time window in Datadog.
@example "Choose an environment and browse service logs" {
  datadog logs tui
}
@example "Browse recent production logs" {
  datadog logs tui --env prod --from 30min --limit 50
}
@example "Find errors mentioning a timeout" {
  datadog logs tui --env prod --query 'status:error *:timeout'
}
export def --wrapped "logs tui" [
  --help(-h) # Show command help
  --from: duration = 1hr # How far back to search
  --limit: int = 50 # Logs per page, from 1 to 1000
  --query: string = "" # Datadog log search expression
  ...arguments: string # Optional --env <name> or --env=<name>; otherwise choose from Datadog
] {
  if $help { help "datadog logs tui" | print; return }
  validate-log-options $from $limit
  let service = project-service-name
  # Nushell reserves $env, so --env cannot be declared as a named parameter.
  let environment = match $arguments {
    [] => { select environment $service }
    [--env $name] => { $name }
    [$argument] if ($argument | str starts-with '--env=') => { $argument | str substring 6.. }
    _ => { error make {msg: "Expected --env <name> or --env=<name>"} }
  }
  if $environment == null { return }
  if ($environment | str trim | is-empty) or ($environment | str starts-with '--') {
    error make {msg: "Expected a non-empty environment name after --env"}
  }
  run-log-browser $service $environment $from $limit $query
}