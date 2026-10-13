use ../tools/fzf.nu *
use ./atlassian-helpers.nu [jira-basic-token, base-url, jira-account]

# Get ticket information from current branch
export def info [] {
  let current_branch = ^git rev-parse --abbrev-ref HEAD
  let match = ($current_branch | parse --regex $env.PROJECTMANAGEMENTKEYPATTERN)

  if not ($match | is-empty) {
    let issue_key = $match | first | get project_key
    return {
      key: $issue_key
      url: $"(base-url)/browse/($issue_key)"
    }
  }

  print "No issue number found from the current branch name"
}

# Open ticket in browser from current branch information
export def open [] {
  let issue_info = info
  if ($issue_info | is-not-empty) {
    start $issue_info.url
  }
}

# Fetch raw issues for both the table and the ticket picker
def assigned-tickets [all: bool] {
  let url = base-url | str trim --right --char '/'
  let headers = {
    accept: application/json
    authorization: $"Basic (jira-basic-token)"
  }
  let account_id = jira-account | get accountId | str trim
  if ($account_id | is-empty) or $account_id == "unknown" {
    error make {msg: "Jira did not return a valid account ID"}
  }

  # WAS does not support currentUser(); use a quoted account ID instead
  let user = $account_id | to json --raw
  let additional_filter = if $all { "" } else { " AND statusCategory != Done" }
  mut request = {
    jql: ("(assignee = currentUser() OR assignee WAS " + $user + ")"
      + $additional_filter
      + " ORDER BY updated DESC, created ASC")
    fields: [summary priority status]
    maxResults: 50
  }
  mut issues = []

  loop {
    let page = http post --content-type application/json --headers $headers $"($url)/rest/api/3/search/jql" $request
    $issues ++= $page.issues
    let next_page = $page | get --optional nextPageToken
    if ($page | get --optional isLast | default false) or ($next_page | is-empty) {
      break
    }
    if $next_page == ($request | get --optional nextPageToken) {
      error make {msg: "Jira returned a repeated pagination token"}
    }
    $request = ($request | upsert nextPageToken $next_page)
  }

  $issues
}

# List tickets currently or previously assigned to you as a Nushell table
export def list [
  --all # Whether to show all tickets, including completed ones
] {
  assigned-tickets $all | each {|issue|
    {
      key: $issue.key
      name: $issue.fields.summary
      priority: ($issue | get --optional fields.priority.name | default "None")
      status: $issue.fields.status.name
    }
  }
}

# Select a ticket from Jira list
export def "menu select" [
  --all # Whether to show all tickets, including completed ones
] {
  assigned-tickets $all | fzf --format {|it| $"($it.key) - ($it.fields.summary)"}
}

# Open ticket in browser from current branch information
export def "menu open" [
  --all # Whether to show all tickets, including completed ones
] {
  let issue = menu select --all
  if ($issue | is-not-empty) {
    start $"(base-url)/browse/($issue.key)"
  }
}