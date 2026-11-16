use ./client.nu [browser-base-url run-pup-json]
use ./pi.nu [investigate-logs]

def log-search-url [query: record]: nothing -> string {
  let site = run-pup-json auth status | get site
  let parameters = {
    query: $query.filter
    from_ts: ($query.start | into datetime | into int | $in // 1_000_000)
    to_ts: ($query.end | into datetime | into int | $in // 1_000_000)
    live: false
  } | url build-query
  $"(browser-base-url $site)/logs?($parameters)"
}

def load-log-page [query: record, cursor?: string]: nothing -> record {
  let pagination = if ($cursor | is-empty) { [] } else { [--cursor $cursor] }
  let response = (run-pup-json logs search
    --query $query.filter --from $query.start --to $query.end
    --limit ($query.limit | into string) --sort desc ...$pagination)
  {
    rows: ($response.data | get attributes)
    next_cursor: ($response.meta?.page?.after? | default "")
  }
}

export def validate-log-options [from: duration, limit: int]: nothing -> nothing {
  if $from <= 0sec { error make {msg: "From must be a positive duration, such as 30min or 1hr"} }
  if $limit < 1 or $limit > 1000 { error make {msg: "Limit must be between 1 and 1000"} }
}

def new-log-state [service: string, environment: string, from: duration, limit: int, search_query: string, levels: list<string> = []]: nothing -> record {
  validate-log-options $from $limit
  let search_query = $search_query | str trim
  let environment = $environment | str trim
  let service_filter = $"service:($service | to json --raw)"
  let service_filter = if $environment == '' { $service_filter } else {
    $"($service_filter) env:($environment | to json --raw)"
  }
  # Search both documented warning/emergency spellings rather than relying on query aliases.
  let statuses = $levels | each {|level|
    match $level {
      warning => { [warning warn] }
      emerg => { [emerg emergency] }
      _ => { [$level] }
    }
  } | flatten | uniq
  let service_filter = if ($statuses | is-empty) { $service_filter } else {
    $service_filter + ' status:(' + ($statuses | str join ' OR ') + ')'
  }
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
    levels: $levels
    query: $query
    pages: [(load-log-page $query)]
    page_index: 0
    message: ""
  }
}

def reload-log-state []: record -> record {
  let state = $in
  new-log-state $state.service $state.environment $state.from $state.limit $state.search_query $state.levels
}

def edit-log-option [title: string, value: string] {
  let result = (tui textbox --id option --title $title --value $value --focus
    | tui label --status "Enter: Apply  Ctrl+C: Cancel"
    | tui run --dialog --size [60 7])
  if $result.action == "submit" { $result.values.option | str trim }
}

def edit-log-levels [levels: list<string>] {
  let current = if ($levels | is-empty) { 'All' } else { $levels | str join ', ' | str uppercase }
  let result = ([error warning info debug notice critical alert emerg OK]
    | each {|level| {Level: ($level | str uppercase), level: $level} }
    | tui label --titlebar 'Filter log levels'
    | tui label $"Current: ($current)"
    | tui label 'Choose replacement levels, or press a for all levels'
    | tui table --id levels --focus --multi --columns [Level]
    | tui label --status 'Space: Check  Enter: Apply  a: All levels  Ctrl+C: Cancel'
    | tui bind a {|| {action: submit, selected: {mode: all}} }
    | tui run --dialog --size [72 18])
  if $result.action != 'submit' { return null }
  match $result.selected {
    {mode: all} => { [] }
    _ => { $result.selected | get level }
  }
}

def update-log-tui [state: record, action: string]: nothing -> record {
  match $action {
    previous => {
      if $state.page_index == 0 { return $state }
      $state | merge {page_index: ($state.page_index - 1), message: ""}
    }
    next => {
      let page_index = $state.page_index + 1
      if $page_index < ($state.pages | length) {
        return ($state | merge {page_index: $page_index, message: ""})
      }
      let cursor = $state.pages | last | get next_cursor
      if ($cursor | is-empty) { return ($state | update message "Last page") }
      let page = load-log-page $state.query $cursor
      if ($page.rows | is-empty) {
        let last_page = $state.pages | last | update next_cursor ""
        return ($state | merge {
          pages: ($state.pages | drop 1 | append $last_page)
          message: "Last page"
        })
      }
      $state | merge {pages: ($state.pages | append $page), page_index: $page_index, message: ""}
    }
    from => {
      let from = edit-log-option "Time range (e.g. 30min, 1hr, 7day)" ($state.from | into string)
      if $from == null { return $state }
      $state | update from ($from | into duration) | reload-log-state
    }
    limit => {
      let limit = edit-log-option "Logs per page (1-1000)" ($state.limit | into string)
      if $limit == null { return $state }
      if $limit !~ '^\d+$' { error make {msg: "Limit must be a whole number between 1 and 1000"} }
      $state | update limit ($limit | into int) | reload-log-state
    }
    search => {
      let search_query = edit-log-option "Search logs (Datadog syntax; empty clears)" $state.search_query
      if $search_query == null { return $state }
      $state | update search_query $search_query | reload-log-state
    }
    levels => {
      let levels = edit-log-levels $state.levels
      if $levels == null or $levels == $state.levels { return $state }
      $state | update levels $levels | reload-log-state
    }
    refresh => {
      $state | reload-log-state
    }
    _ => { $state }
  }
}

def mark-log-rows [selected_ids: list<int>]: table -> table {
  each {|row|
    let marker = if $row.log_index in $selected_ids { '[x]' } else { '[ ]' }
    $row | update Message $"($marker) ($row.search_text)"
  }
}

def open-logs-in-editor [logs: table]: nothing -> nothing {
  let editor = [$env.config.buffer_editor $env.VISUAL? $env.EDITOR?]
    | compact --empty
    | get --optional 0
  if $editor == null {
    error make {msg: 'Set $env.EDITOR to an editor executable, or configure $env.config.buffer_editor'}
  }
  let file = mktemp --suffix .json
  try {
    let content = if ($logs | length) == 1 { $logs.0 } else { $logs }
    $content | to json --indent 2 | save --force $file
    # Run in the foreground after the TUI has released the terminal. No shell evaluation.
    run-external $editor $file
  } finally {
    rm --force $file
  }
}

def log-widget [state: record, selection_file: path] {
  let page = $state.pages | get $state.page_index
  let labels = ['Time (local)' Message]
  let rows = $page.rows | enumerate | each {|entry|
    let log = $entry.item
    let prefix = if ($log.status? | is-empty) { '' } else { $"[($log.status)]" }
    let timestamp = try {
      # Epoch conversion respects DST at the log's date; date to-timezone local uses today's offset in Nu 0.116.1.
      $log.timestamp? | into datetime | into int | into datetime --timezone local | format date '%Y-%m-%d %I:%M:%S %p'
    } catch { $log.timestamp? }
    let message = [$prefix $log.message?] | compact --empty | str join ' '
    {
      'Time (local)': $timestamp
      Message: $message
      search_text: $message # Keep check markers out of the local search.
      log_index: $entry.index
      details: $log
    }
  }
  let title = $"($state.service) / ($state.environment | default --empty 'All environments') | Time range: ($state.from) | Limit: ($state.limit) | Page ($state.page_index + 1)"
  let level_label = if ($state.levels | is-empty) { 'All' } else { $state.levels | str join ', ' | str uppercase }
  let hint = "Space: Select  a: Pi  o: Editor  l: Levels  L: Limit  s: Search  b: Web  /: Filter  [ ]: Pages  t: Time  Ctrl+R: Refresh  q: Quit"
  let ui = ($rows | mark-log-rows (open $selection_file)
    | tui label --titlebar $title
    | tui label $"Levels: ($level_label)  Search: ($state.search_query | default --empty '*')"
    | tui label ($state.message | default --empty 'a/o use all selected records, including hidden ones; otherwise the highlighted row')
    | tui label --from logs {|_| $"Selected: (open $selection_file | length)" }
    | tui search --id log-search --bind / --fuzzy --columns ['Time (local)' search_text] --placeholder "/ to filter this page"
    | tui split --id log-split --sizes [1fr 60%] [
        (tui table --id logs --focus --columns $labels)
        (tui log --id log-details --from logs --title Details {|row| $row.details | to json | nu-highlight | lines })
      ]
    | tui label 'Tab/Shift+Tab: Focus  Up/Down/PgUp/PgDn: Scroll  Home/End: Top/Bottom'
    | tui label --status $hint
    | tui bind space {|tui_state|
        if $tui_state.focused != logs { return }
        let index = $tui_state.values.logs.row?.log_index?
        if $index == null { return }
        # Native checks follow filtered positions. Store only stable page-local IDs instead.
        let selected_ids = open $selection_file
        let selected_ids = if $index in $selected_ids {
          $selected_ids | where $it != $index
        } else {
          $selected_ids | append $index
        }
        $selected_ids | to nuon | save --force $selection_file
        $rows | mark-log-rows $selected_ids
      }
    | tui bind b {||
        try {
          start (log-search-url $state.query) | ignore
        } catch {|error|
          {action: submit, selected: {error: $error.msg}}
        }
      }
    | tui bind enter {|| null })
  let ui = [
    [key action];
    [o editor] [a investigate]
  ] | reduce --fold $ui {|binding, ui|
    $ui | tui bind $binding.key {|tui_state|
      if $tui_state.focused not-in [logs log-details] { return }
      let selected_ids = open $selection_file
      let logs = if ($selected_ids | is-not-empty) {
        $rows | where log_index in $selected_ids | get details
      } else {
        [$tui_state.values.logs.row?.details?] | compact
      }
      if ($logs | is-not-empty) { {action: submit, selected: {action: $binding.action, logs: $logs}} }
    }
  }
  [
    [key action];
    ['[' previous] [',' previous]
    [']' next] ['.' next]
    [s search] [t from] [l levels] [shift+l limit] [ctrl+r refresh]
  ] | reduce --fold $ui {|binding, ui|
    $ui | tui bind $binding.key {|| {action: submit, selected: {action: $binding.action}} }
  }
}

export def run-log-tui [service: string, environment: string, from: duration, limit: int, search_query: string] {
  mut state = new-log-state $service $environment $from $limit $search_query
  # TUI callbacks cannot share mutable locals. This scratch file holds only page-local row IDs.
  let selection_file = mktemp --suffix .nuon
  try {
    [] | to nuon | save --force $selection_file
    loop {
      let result = log-widget $state $selection_file | tui run
      if $result.action != "submit" { return }
      let action = match $result.selected {
        {error: $message} => {
          $state = $state | update message $message
          continue
        }
        {action: $action} => { $action }
        _ => { continue }
      }
      let current_state = $state
      $state = try {
        match $action {
          editor => {
            open-logs-in-editor $result.selected.logs
            $current_state | update message ''
          }
          investigate => {
            investigate-logs $result.selected.logs $current_state.query
            $current_state | update message ''
          }
          _ => { update-log-tui $current_state $action }
        }
      } catch {|error|
        $current_state | update message $error.msg
      }
      if $state.page_index != $current_state.page_index or $state.query != $current_state.query {
        [] | to nuon | save --force $selection_file
      }
    }
  } finally {
    rm --force $selection_file
  }
}
