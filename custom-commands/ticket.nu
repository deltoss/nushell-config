export def info [] {
  let current_branch = ^git rev-parse --abbrev-ref HEAD
  let base_url = $env.PROJECTMANAGEMENTBASEURL
  let pattern = $env.PROJECTMANAGEMENTKEYPATTERN

  let match = ($current_branch | parse --regex $pattern)
  if not ($match | is-empty) {
    let issue_key = $match | first | get project_key
    return {
      key: $issue_key
      url: ($base_url + $issue_key)
    }
  }

  print "No issue number found from the current branch name"
}

export def open [] {
  let issue_info = info
  if ($issue_info | is-not-empty) {
    start $issue_info.url
  }
}
