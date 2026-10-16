use ./atlassian-helpers.nu [jira-basic-token, base-url, jira-account-id]
use ./jira.nu [setup]

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

def open-ticket [] {
  let issue_info = info
  if ($issue_info | is-not-empty) {
    start $issue_info.url
  }
}

# Open ticket in browser from current branch information
export alias open = open-ticket

# Build JQL without fetching credentials, configuration, or issues.
def assigned-ticket-jql [
  account_id: string
  choices: record # Empty to search across all projects and statuses
] {
  # WAS does not support currentUser(); use a quoted account ID instead.
  let quoted_account_id = $account_id | to json --raw
  let ticket_filter = if ($choices | is-not-empty) {
    let projects = $choices.project_ids | each {|id| $id | into string | to json --raw} | str join ", "
    let statuses = $choices.active_status_ids | each {|id| $id | into string | to json --raw} | str join ", "
    " AND project IN (" + $projects + ") AND status IN (" + $statuses + ")"
  } else {
    ""
  }
  ("(assignee = currentUser() OR assignee WAS " + $quoted_account_id + ")"
    + $ticket_filter
    + " ORDER BY updated DESC, created ASC")
}

# Fetch raw Jira issues using the saved project and status filters.
def assigned-tickets [
  --all # Bypass the saved project and status filters
] {
  let choices = if $all { {} } else { setup }
  if not $all and ($choices | is-empty) { return [] }
  let account_id = if $all { jira-account-id } else { $choices.account_id }
  let site = base-url
  let headers = {
    accept: application/json
    authorization: $"Basic (jira-basic-token)"
  }
  mut request = {
    jql: (assigned-ticket-jql $account_id $choices)
    fields: [summary priority status]
    maxResults: 50
  }
  mut issues = []

  loop {
    let page = http post --content-type application/json --headers $headers $"($site)/rest/api/3/search/jql" $request
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

# List Jira tickets currently or previously assigned to you.
#
# On first use, choose projects and active statuses. Both choices survive shell restarts.
# Run `jira setup --configure` to change them.
export def list [
  --all # Bypass the saved project and status filters
] {
  assigned-tickets --all=$all | each {|issue|
    {
      key: $issue.key
      name: $issue.fields.summary
      priority: ($issue | get --optional fields.priority.name | default "None")
      status: $issue.fields.status.name
    }
  }
}

# Pick Jira tickets, returning the selected record or records.
#
# Type to search, press Enter to confirm, or Esc to cancel.
# Add --browse to open the selection without changing the return value.
export def pick [
  --all # Bypass the saved project and status filters
  --multi(-m) # Select multiple tickets; Tab toggles a ticket, Enter confirms
  --browse # Open each selected ticket in the browser
] {
  let tickets = list --all=$all
  if ($tickets | is-empty) { return }

  let selected = $tickets | input list --fuzzy --multi=$multi "Select tickets:" --display {|ticket|
    $"($ticket.key) [($ticket.status)] - ($ticket.name)"
  }

  if $browse and ($selected | is-not-empty) {
    let site = base-url
    let selected_tickets = if $multi { $selected } else { [$selected] }
    for ticket in $selected_tickets {
      start $"($site)/browse/($ticket.key)" | ignore
    }
  }
  $selected
}