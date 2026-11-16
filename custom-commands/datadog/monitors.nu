use ../../tools/tui.nu [tui-link-actions]
use ./client.nu [browser-base-url run-pup-json]

export def load-monitor-page [query?: string, page: int = 0]: nothing -> record {
  if $page < 0 { error make {msg: "Page must not be negative"} }
  let authentication_status = run-pup-json auth status
  if not $authentication_status.authenticated {
    error make {msg: "Sign in to Datadog first with: pup auth login"}
  }
  let browser_url = browser-base-url $authentication_status.site
  let monitor_query = $query
    | default $env.DATADOG_MONITOR_QUERY?
    | default 'status:(Alert OR Warn OR "No Data")'

  let response = run-pup-json monitors search --query $monitor_query --page ($page | into string) --per-page '20' --sort 'status,asc'
  let rows = $response.monitors | each {|monitor|
    {
      key: ($monitor.id | into string)
      name: $monitor.name
      status: $monitor.status
      url: $"($browser_url)/monitors/($monitor.id)"
    }
  }
  let page_count = $response.metadata?.page_count?
  {
    rows: $rows
    page: $page
    page_count: $page_count
    message: ""
    has_next: (if $page_count == null { ($rows | length) == 20 } else { $page + 1 < $page_count })
  }
}

export def monitor-widget [query?: string, page: int = 0] {
  load-monitor-page $query $page | monitor-page-widget $query
}

def monitor-display-rows []: table -> table {
  each {|monitor| { ...$monitor, Status: $monitor.status, Name: $monitor.name } }
}

def monitor-page-widget [query?: string, --paging] {
  let page = $in
  let display_columns = [Status Name]
  let page_total = if $page.page_count == null { "" } else { $" of ([$page.page_count 1] | math max)" }
  let ui = ($page.rows | monitor-display-rows
    | tui label --titlebar $"Monitors | Page ($page.page + 1)($page_total)"
    | tui label $page.message
    | tui search --id datadog-query --bind / --fuzzy --columns $display_columns
    | tui table --id datadog-rows --focus --multi --columns $display_columns
    | tui-link-actions)
  if not $paging {
    return ($ui | tui bind ctrl+r {|state|
      if ($state.values.datadog-rows.checked? | is-not-empty) { return }
      load-monitor-page $query $page.page | get rows | monitor-display-rows
    })
  }
  [
    [key action];
    ['[' previous] [',' previous]
    [']' next] ['.' next]
    [ctrl+r refresh]
  ] | reduce --fold $ui {|binding, ui|
    $ui | tui bind $binding.key {|state|
      # Checked rows use positions, so unmark before replacing the page.
      if ($state.values.datadog-rows.checked? | is-not-empty) { return }
      {action: submit, selected: {action: $binding.action}}
    }
  }
}

def update-monitor-page [page: record, action: string, query?: string]: nothing -> record {
  let number = match $action {
    previous if $page.page > 0 => { $page.page - 1 }
    next if $page.has_next => { $page.page + 1 }
    refresh => { 0 }
    _ => { return $page }
  }
  let next = load-monitor-page $query $number
  # Monitors can disappear between requests. Keep the current page if next is now empty.
  if $action == 'next' and ($next.rows | is-empty) {
    $page | update has_next false
  } else {
    $next
  }
}

export def run-monitor-tui [query?: string] {
  mut page = load-monitor-page $query
  loop {
    let result = ($page | monitor-page-widget --paging
      | tui label --status "[/,: Previous  ]/.: Next  Ctrl+R: First page/refresh (unmark first)  Space: Check  y: Copy IDs  Y: Copy URLs  b: Browse  /: Filter  q: Quit"
      | tui run)
    if $result.action != 'submit' { return }
    let action = match $result.selected {
      {action: $action} => { $action }
      _ => { continue }
    }
    let current_page = $page
    $page = try {
      update-monitor-page $current_page $action $query | update message ""
    } catch {|error|
      $current_page | update message $error.msg
    }
  }
}
