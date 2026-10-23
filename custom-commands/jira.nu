use ./atlassian-helpers.nu [base-url, jira-basic-token, jira-account-id]
use ../tools/tui.nu [tui-picker]

# Load saved Jira choices, prompting for projects and active statuses when needed.
def load-or-configure-choices [
  site: string # Jira site URL without a trailing slash
  account_id: string # Jira account ID used to scope the saved choices
  --configure # Choose again; cancellation keeps the saved choices
] {
  # Separate sites and accounts without putting URLs or account IDs in file names.
  let scope_hash = [$site $account_id] | to json --raw | hash sha256
  # Keep the existing path so saved choices still load.
  let choices_file = $nu.cache-dir | path join "ticket" $"active-statuses-($scope_hash).json"
  if not $configure and ($choices_file | path exists) {
    let saved = open $choices_file
    # Older files used status_ids. Normalize it at the storage boundary.
    let active_status_ids = $saved | get --optional active_status_ids | default { $saved | get --optional status_ids }
    if ($saved | get --optional project_ids | is-not-empty) and ($active_status_ids | is-not-empty) {
      return {
        site: $site
        account_id: $account_id
        project_ids: $saved.project_ids
        active_status_ids: $active_status_ids
      }
    }
  }

  let headers = {accept: application/json, authorization: $"Basic (jira-basic-token)"}
  let projects = fetch-projects $site $headers
  if ($projects | is-empty) { return }

  let selected_projects = $projects | sort-by key | tui-picker "Choose projects" [key name] --multi
  if ($selected_projects | is-empty) { return }

  let statuses = fetch-project-statuses $site $headers $selected_projects
  if ($statuses | is-empty) { return }

  let selected_statuses = $statuses | tui-picker "Choose active statuses" [name id] --multi
  if ($selected_statuses | is-empty) { return }

  let choices = {
    site: $site
    account_id: $account_id
    project_ids: ($selected_projects | get id)
    active_status_ids: ($selected_statuses | get id)
  }
  mkdir ($choices_file | path dirname)
  $choices | to json | save --force $choices_file
  $choices
}

# Fetch every browsable project using Jira's offset-based pagination.
def fetch-projects [site: string headers: record] {
  mut projects = []
  mut start_at = 0
  loop {
    let page = http get --headers $headers $"($site)/rest/api/3/project/search?action=browse&startAt=($start_at)&maxResults=100"
    $projects ++= $page.values
    if $page.isLast or ($page.values | is-empty) { break }
    $start_at += ($page.values | length)
  }
  $projects
}

# Projects share statuses across issue types, so merge them by status ID.
def fetch-project-statuses [site: string headers: record projects: table] {
  $projects | each {|project|
    let issue_types = http get --headers $headers $"($site)/rest/api/3/project/($project.id)/statuses"
    if ($issue_types | is-empty) { [] } else { $issue_types | get statuses | flatten }
  }
  | flatten
  | uniq-by id
  | sort-by name
}

# Initialize Jira project choices and your definition of active statuses.
#
# Uses the current Jira site and account. Choices survive shell restarts.
# Returns site, account_id, project_ids, and active_status_ids, or nothing on cancellation.
export def setup [
  --configure # Choose projects and active statuses again; cancellation keeps the saved choices
] {
  let site = base-url
  let account_id = jira-account-id
  load-or-configure-choices $site $account_id --configure=$configure
}

# Get the chosen project IDs. Prompts for setup on first use.
export def selected-project-ids [] {
  setup | get --optional project_ids | default []
}

# Get the status IDs you count as active. Prompts for setup on first use.
export def active-status-ids [] {
  setup | get --optional active_status_ids | default []
}