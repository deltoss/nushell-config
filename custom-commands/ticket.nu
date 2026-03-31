use ../tools/fzf.nu *

# Get ticket information from current branch
export def info [] {
  let current_branch = ^git rev-parse --abbrev-ref HEAD
  let match = ($current_branch | parse --regex $env.PROJECTMANAGEMENTKEYPATTERN)

  if not ($match | is-empty) {
    let issue_key = $match | first | get project_key
    return {
      key: $issue_key
      url: $"($env.PROJECTMANAGEMENTBASEURL)/browse/($issue_key)"
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

# List available tickets
export def list [
  --all # Whether to show all tickets, including completed ones
] {
  let additional_filter = if ($all) {
    ""
  } else {
    " AND status NOT IN (Done,Closed,Resolved)"
  }

  let jql = ("(assignee = currentUser() OR assignee was currentUser() OR reporter = currentUser())"
    + $additional_filter
    + " ORDER BY updated DESC, created ASC")

  (http post --content-type application/json --headers {
    accept: application/json
    authorization:$"Basic ($env.JIRABASE64AUTHTOKEN)"
  } $"($env.JIRABASEURL)/rest/api/3/search/jql?jql" {
    "jql": $jql,
    "fields": [
      "summary",
      "status",
      "assignee",
      "project",
      "priority",
      "updated",
      "created"
    ],
    "maxResults": 50 # Hack for now. This assumes no pagination is needed.
  } | get issues | select key fields self)
}

# Select a ticket from Jira list
export def "menu select" [
  --all # Whether to show all tickets, including completed ones
] {
  list --all=$all | fzf --format {|it| $"($it.key) - ($it.fields.summary)"}
}

# Open ticket in browser from current branch information
export def "menu open" [
  --all # Whether to show all tickets, including completed ones
] {
  let issue = menu select --all
  if ($issue | is-not-empty) {
    start $"($env.PROJECTMANAGEMENTBASEURL)/browse/($issue.key)"
  }
}