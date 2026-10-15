use ./atlassian-helpers.nu [base-url, jira-basic-token, jira-account-id]

# Load saved Jira choices, prompting for projects and active statuses when needed.
def saved-choices [
  site: string # Jira site URL without a trailing slash
  account_id: string # Jira account ID used to scope the saved choices
  --configure # Choose again; cancellation keeps the saved choices
] {
  # Separate sites and accounts without putting URLs or account IDs in file names.
  let scope_hash = [$site $account_id] | to json --raw | hash sha256
  # Keep the legacy cache location and status_ids field compatible with saved choices.
  let cache_file = $nu.cache-dir | path join "ticket" $"active-statuses-($scope_hash).json"
  if not $configure and ($cache_file | path exists) {
    let saved = open $cache_file
    if ($saved | get --optional project_ids | is-not-empty) and ($saved | get --optional status_ids | is-not-empty) {
      return $saved
    }
  }

  let headers = {accept: application/json, authorization: $"Basic (jira-basic-token)"}
  mut projects = []
  mut start_at = 0
  loop {
    let page = http get --headers $headers $"($site)/rest/api/3/project/search?action=browse&startAt=($start_at)&maxResults=100"
    $projects ++= $page.values
    if $page.isLast or ($page.values | is-empty) { break }
    $start_at += ($page.values | length)
  }
  if ($projects | is-empty) { return }

  let selected_projects = (
    $projects | sort-by key
    | input list --fuzzy --multi "Choose projects (Tab to toggle, Enter to confirm):" --display {|project|
      $"($project.key) - ($project.name)"
    }
  )
  if ($selected_projects | is-empty) { return }

  let statuses = (
    $selected_projects | each {|project|
      let types = http get --headers $headers $"($site)/rest/api/3/project/($project.id)/statuses"
      if ($types | is-empty) { [] } else { $types | get statuses | flatten }
    }
    | flatten
    | uniq-by id
    | sort-by name
  )
  if ($statuses | is-empty) { return }

  let selected_statuses = $statuses | input list --fuzzy --multi --display name "Choose active statuses (Tab to toggle, Enter to save):"
  if ($selected_statuses | is-empty) { return }

  let choices = {
    site: $site
    account_id: $account_id
    project_ids: ($selected_projects | get id)
    status_ids: ($selected_statuses | get id)
  }
  mkdir ($cache_file | path dirname)
  $choices | to json | save --force $cache_file
  $choices
}

# Initialize Jira project choices and your definition of active statuses.
#
# Uses the current Jira site and account. Choices survive shell restarts.
# Returns site, account_id, project_ids, and active_status_ids, or nothing on cancellation.
export def setup [
  --configure # Choose projects and active statuses again; cancellation keeps the saved choices
] {
  let site = base-url | str trim --right --char '/'
  let account_id = jira-account-id
  let choices = saved-choices $site $account_id --configure=$configure
  if ($choices | is-empty) { return }

  {
    site: $site
    account_id: $account_id
    project_ids: $choices.project_ids
    active_status_ids: $choices.status_ids
  }
}

# Get the project IDs chosen during Jira setup, initializing on first use.
export def selected-projects [] {
  setup | get --optional project_ids | default []
}

# Get the status IDs you count as active, initializing on first use.
export def active-statuses [] {
  setup | get --optional active_status_ids | default []
}