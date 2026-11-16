use ../../tools/tui.nu [tui-picker]
use ./client.nu [run-pup-json]
use ./logs.nu [run-log-tui validate-log-options]
use ./monitors.nu [load-monitor-page monitor-widget run-monitor-tui]
use ./projects.nu
use ./hints.nu [run-hint-manager]

const project_services_file = ($nu.data-dir | path join datadog project-services.json)

# Return one page of Datadog monitors matching a search.
#
# Authenticate with `pup auth login` first. Pup manages the site and credentials.
# DATADOG_MONITOR_QUERY sets the default search; --query overrides it.
@example "Find production alerts" {
  datadog list --query 'env:prod status:Alert'
}
export def list [
  --query: string # Datadog monitor search; defaults to Alert, Warn and No Data
  --page: int = 0 # Zero-based page number; 20 monitors per page
]: nothing -> table {
  load-monitor-page $query $page | get rows
}

# Build a single-page Datadog monitor widget for composition, with in-place refresh.
# Use monitor tui for interactive pagination.
@example "Compose an interactive Datadog widget" {
  datadog monitor widget | tui run
}
export def "monitor widget" [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
  --page: int = 0 # Zero-based page number
] {
  monitor-widget $query $page
}

# Browse Datadog monitors interactively.
#
# [ or ,: previous page. ] or .: next page. Ctrl+R: refresh from the first page.
# Uncheck selected rows before paging or refreshing.
@example "Browse monitors needing attention" {
  datadog monitor tui
}
export def "monitor tui" [
  --query: string # Datadog monitor search; defaults to DATADOG_MONITOR_QUERY
] {
  run-monitor-tui $query
}

# List this repository's configured hint/service pairs as a table, without calling Datadog.
# Root rules have a null hint. Unconfigured repositories return an empty table.
@example "List service hints for the current repo" {
  datadog services list
}
export def "services list" []: nothing -> table {
  projects repository-root | ignore
  projects list-rules $project_services_file (projects repository-key)
}

# Add a hint/service pair, keeping any other services for the same hint.
# Omit --hint for a repo-root default. Directory hints end in /; regexes start with regex:.
@example "Add a default for the repo root" {
  datadog services add apidocs
}
@example "Identify an application by its project file" {
  datadog services add folder-record --hint LEAP.Infrastructure.LambdaFunctions.FolderRecord.csproj
}
@example "Identify an application directory" {
  datadog services add apidocs --hint 'src/Api/'
}
@example "Keep test and live services for the same project" {
  datadog services add lmd-documentrecord-test --hint 'Worker.csproj'
  datadog services add lmd-documentrecord-live --hint 'Worker.csproj'
}
export def "services add" [service: string, --hint: string]: nothing -> nothing {
  projects repository-root | ignore
  projects save-rule $project_services_file (projects repository-key) {hint: $hint, service: $service}
}

# Remove exactly one hint/service pair, preserving other hints and services.
# Omit --hint to remove only the repo-root pair. Missing pairs are an error.
@example "Remove one project-specific service" {
  datadog services remove lmd-documentrecord-test --hint 'Worker.csproj'
}
@example "Remove a repo-root default" {
  datadog services remove apidocs
}
export def "services remove" [service: string, --hint: string]: nothing -> nothing {
  projects repository-root | ignore
  projects remove-rule $project_services_file (projects repository-key) {hint: $hint, service: $service}
}

# Add, edit or remove this repository's service hints without editing JSON.
@example "Manage service hints for the current repo" {
  datadog services tui
}
export def "services tui" []: nothing -> nothing {
  projects repository-root | ignore
  run-hint-manager $project_services_file (projects repository-key)
}

def project-service-name [--reselect] {
  let override = $env.DD_SERVICE? | default "" | str trim
  if ($override | is-not-empty) { return $override }

  let repository = projects repository-key
  let root = projects repository-root
  let hints = projects list-rules $project_services_file $repository
  if not $reselect and ($hints | is-not-empty) {
    let resolved = projects resolve $hints $root $env.PWD
    if ($resolved.services | length) == 1 { return $resolved.services.0 }
    let selected = $resolved.services | each {|service| {service: $service} }
      | tui-picker $"Select service for ($repository)" [service]
    return $selected.service?
  }

  let selected = select-service $repository
  if $selected == null { return null }
  # Add the first-use default without replacing rules saved while the picker was open.
  if ($hints | is-empty) {
    projects save-rule $project_services_file $repository {hint: null, service: $selected}
  }
  $selected
}

def select-service [repository: string] {
  let services = (run-pup-json logs aggregate
    --query '*' --from 7d --compute count --group-by service --limit '1000'
    | get data.buckets | get --optional by.service
    | compact --empty | uniq | sort
    | each {|service| {service: $service} })
  let selected = $services | tui-picker $"Select service for ($repository)" [service] --on-new {|query|
    let service = $query | str trim
    if ($service | is-empty) { return null }
    {service: $service}
  }
  if $selected == null { return null }
  let service = $selected.service | str trim
  if ($service | is-empty) { return null }

  $service
}

# Select an environment with recent logs, or all environments without an env filter.
#
# An empty string means unfiltered. Cancellation returns null.
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
    | each {|environment| {environment: $environment, value: $environment} }
    | prepend {environment: 'All environments (unfiltered)', value: ''})
  let selected = $environments | tui-picker $"Select environment for ($service)" [environment]
  $selected.value?
}

# Browse a service's Datadog logs with paging and editable query settings.
#
# Resolves the nearest service hint from cwd up to the worktree root.
# Rules live in $nu.data-dir/datadog/project-services.json, keyed by Git origin.
# Conflicting hints or unmatched multi-service repos show a picker without changing the rules.
# On first use, select a service or type its name in search and press Ctrl+N to save a root default.
# Use datadog services tui to manage directory, filename or regex hints.
# DD_SERVICE overrides the saved choice without changing it. Omit --environment to choose one.
# An empty --environment disables the env filter, including logs without an env tag.
# The list shows machine-local timestamps with DST at the log's date; Details keeps the original timestamp.
# Logs and details are side by side. Tab focuses Details; Shift+Tab returns to the list.
# Details opens at the bottom. Home/End jump to the top/bottom; arrows and PgUp/PgDn scroll.
# Tab again focuses the split divider; Left/Right resizes it.
# Space: select/unselect logs. Local filtering keeps selections; paging, query changes and refresh clear them.
# o: open selected logs in your editor, or the highlighted log when none are selected.
# a: investigate the same records with Pi and the current repository.
# Inside Zellij, Pi opens in a stacked pane; otherwise it runs here until you exit it.
# Editor/Pi handoffs keep the cached page. Temporary JSON is removed when the consuming process exits.
# l: choose log levels (Space checks, Enter applies, a clears). Shift+L: change logs per page.
# Level filters apply server-side and survive paging, refresh, time range, limit and search changes.
# Refresh and filter changes restart at the first page.
# Search uses Datadog syntax within the selected service, environment and levels; an empty query clears it.
# Browsing opens the current search and time window in Datadog.
@example "Choose an environment and browse service logs" {
  datadog logs tui
}
@example "Browse recent production logs" {
  datadog logs tui --environment prod --from 30min --limit 50
}
@example "Find errors mentioning a timeout" {
  datadog logs tui -e prod --query 'status:error *:timeout'
}
@example "Browse without an environment filter" {
  datadog logs tui -e ''
}
@example "Choose a different service for this run" {
  datadog logs tui --reselect-service
}
export def "logs tui" [
  --environment(-e): string # Environment name; empty means unfiltered; omitted opens the picker
  --reselect-service # Choose from Datadog for this run without changing existing hints; DD_SERVICE still wins
  --from: duration = 1hr # How far back to search
  --limit: int = 50 # Logs per page, from 1 to 1000
  --query: string = "" # Datadog log search expression
] {
  validate-log-options $from $limit
  let environment = $environment | if $in == null { null } else { str trim }
  let service = project-service-name --reselect=$reselect_service
  if $service == null { return }
  let environment = if $environment == null { select environment $service } else { $environment }
  if $environment == null { return }
  run-log-tui $service $environment $from $limit $query
}