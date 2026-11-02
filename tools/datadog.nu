export def --wrapped run-pup-json [...arguments: string] {
  if (which pup | is-empty) {
    error make {msg: "Pup is required. Install it with: mise use -g github:DataDog/pup"}
  }
  let command_result = ^pup --read-only --no-envelope --output json ...$arguments | complete
  if $command_result.exit_code != 0 {
    error make {msg: $"Pup failed: ($command_result.stderr | str trim)"}
  }
  $command_result.stdout | from json
}

def load-log-page [query: record, cursor?: string] {
  let pagination = if ($cursor | is-empty) { [] } else { [--cursor $cursor] }
  let response = (run-pup-json logs search
    --query $query.filter --from $query.start --to $query.end
    --limit ($query.limit | into string) --sort desc ...$pagination)
  {
    rows: ($response.data | each {|entry| $entry.attributes })
    next_cursor: ($response.meta?.page?.after? | default "")
  }
}

export def validate-log-options [from: duration, limit: int] {
  if $from <= 0sec { error make {msg: "From must be a positive duration, such as 30min or 1hr"} }
  if $limit < 1 or $limit > 1000 { error make {msg: "Limit must be between 1 and 1000"} }
}

def new-log-browser [service: string, environment: string, from: duration, limit: int, search_query: string] {
  validate-log-options $from $limit
  let search_query = $search_query | str trim
  let service_filter = $"service:($service | to json --raw) env:($environment | to json --raw)"
  let filter = if ($search_query | is-empty) {
    $service_filter
  } else {
    $service_filter + " AND (" + $search_query + ")"
  }
  # Freeze both bounds so relative times cannot shift between cursor requests.
  let end = date now
  let query = {
    filter: $filter
    start: ($end - $from | format date "%+")
    end: ($end | format date "%+")
    limit: $limit
  }
  {
    service: $service
    environment: $environment
    from: $from
    limit: $limit
    search_query: $search_query
    query: $query
    pages: [(load-log-page $query)]
    page_index: 0
    message: ""
  }
}

def edit-log-option [title: string, value: string] {
  let result = (tui textbox --id option --title $title --value $value --focus
    | tui label --status "Enter: Apply  Ctrl+C: Cancel"
    | tui run --dialog --size [60 7])
  if $result.action == "submit" { $result.values.option | str trim }
}

def update-log-browser [browser: record, action: string] {
  match $action {
    previous => {
      if $browser.page_index == 0 { return $browser }
      $browser | merge {page_index: ($browser.page_index - 1), message: ""}
    }
    next => {
      let page_index = $browser.page_index + 1
      if $page_index < ($browser.pages | length) {
        return ($browser | merge {page_index: $page_index, message: ""})
      }
      let cursor = $browser.pages | last | get next_cursor
      if ($cursor | is-empty) { return ($browser | update message "Last page") }
      let page = load-log-page $browser.query $cursor
      if ($page.rows | is-empty) {
        let last_page = $browser.pages | last | update next_cursor ""
        return ($browser | merge {
          pages: ($browser.pages | drop 1 | append $last_page)
          message: "Last page"
        })
      }
      $browser | merge {pages: ($browser.pages | append $page), page_index: $page_index, message: ""}
    }
    from => {
      let from = edit-log-option "Time range (e.g. 30min, 1hr, 7day)" ($browser.from | into string)
      if $from == null { return $browser }
      new-log-browser $browser.service $browser.environment ($from | into duration) $browser.limit $browser.search_query
    }
    limit => {
      let limit = edit-log-option "Logs per page (1-1000)" ($browser.limit | into string)
      if $limit == null { return $browser }
      if $limit !~ '^\d+$' { error make {msg: "Limit must be a whole number between 1 and 1000"} }
      new-log-browser $browser.service $browser.environment $browser.from ($limit | into int) $browser.search_query
    }
    search => {
      let search_query = edit-log-option "Search logs (Datadog syntax; empty clears)" $browser.search_query
      if $search_query == null { return $browser }
      new-log-browser $browser.service $browser.environment $browser.from $browser.limit $search_query
    }
    refresh => {
      new-log-browser $browser.service $browser.environment $browser.from $browser.limit $browser.search_query
    }
    _ => { $browser }
  }
}

def log-browser-widget [browser: record] {
  let page = $browser.pages | get $browser.page_index
  let columns = [timestamp status message]
  let labels = $columns | str pascal-case
  let rows = $page.rows | each {|log|
    $log | select --optional ...$columns
      | rename --block { str pascal-case }
      | insert details $log
  }
  let title = $"($browser.service) / ($browser.environment) | Time range: ($browser.from) | Limit: ($browser.limit) | Page ($browser.page_index + 1)"
  let hint = " / : Move  s: Search  /: Filter  [/,: Previous  ]/.: Next  t: Time range  l: Limit  Ctrl+R: Refresh  q: Quit"
  let ui = ($rows
    | tui label --titlebar $title
    | tui label $"Search: ($browser.search_query | default --empty '*')"
    | tui label $browser.message
    | tui search --id log-search --bind / --fuzzy --columns $labels --placeholder "/ to filter this page"
    | tui split --vertical --sizes [60% 1fr] [
        (tui table --id logs --focus --columns $labels)
        (tui preview --from logs --title Details {|row| $row.details | to json | nu-highlight })
      ]
    | tui label --status $hint
    | tui bind enter {|| null })
  [
    [key action];
    ['[' previous] [',' previous]
    [']' next] ['.' next]
    [s search] [t from] [l limit] [ctrl+r refresh]
  ] | reduce --fold $ui {|binding, ui|
    $ui | tui bind $binding.key {|| {action: submit, selected: $binding.action} }
  }
}

export def run-log-browser [service: string, environment: string, from: duration, limit: int, search_query: string] {
  mut browser = new-log-browser $service $environment $from $limit $search_query
  loop {
    let result = log-browser-widget $browser | tui run
    if $result.action != "submit" { return }
    let current_browser = $browser
    $browser = try {
      update-log-browser $current_browser $result.selected
    } catch {|error|
      $current_browser | update message $error.msg
    }
  }
}