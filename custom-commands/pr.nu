use std/log
use ./git-helpers.nu [ repo-info ]
use ./git.nu

export def "get workspaces" [] {
  http get --headers {
    accept: application/json
    authorization: $"Basic ($env.BITBUCKETBASE64AUTHTOKEN)"
  } https://api.bitbucket.org/2.0/user/permissions/workspaces | get values | select workspace.uuid workspace.slug workspace.name | rename id slug name
}

export def "select workspace" [] {
  let workspaces = get workspaces
  if ($workspaces | is-empty) {
    return
  } else if (($workspaces | length) == 1) {
    $workspaces | first
  } else {
    let selected_workspace = $workspaces | each {|row| $"($row.name) \(($row.slug)\)"} | str join | fzf
    if ($selected_workspace | is-empty) {
      return
    }
    let slug = $selected_workspace | parse "{name} ({slug})" | get slug | first
    $workspaces | where slug == $slug | first
  }
}

export def "get repositories" [
  # Workspace name or slug
  workspace?:string
  # Optional query to filter results by repository name
  query?:string
] {
  let workspace = $workspace | default --empty (select workspace | get slug)
  let full_query = if ($query | is-not-empty) {
    "&q=" + ($"name~\"($query)\"" | url encode)
  } else {
    ""
  }

  http get --headers {
    accept: application/json
    authorization: $"Basic ($env.BITBUCKETBASE64AUTHTOKEN)"
  } $"https://api.bitbucket.org/2.0/repositories/($workspace | url encode)?role=contributor($full_query)" | get values | select name slug
}

export def url [
  dest_branch?: string # Destination branch to create a pull request for
  repo_info?: record # The repo information
] {
  let repo = $repo_info | default { repo-info }
  let src_branch = $repo.branch
  let dest = $dest_branch | default {
    git select branch | if ($in | is-not-empty) {
      get branch | str replace '^origin\/' ''
    }
  }

  if ($dest | is-empty) {
    log info "Destination branch not selected. Quitting..."
    return null
  }

  match $repo.type {
    "GitHub" => {
      $"https://github.com/($repo.organization)/($repo.repository)/compare/($src_branch)...($dest)?expand=1"
    },
    "BitBucketCloud" => {
      $"https://bitbucket.org/($repo.organization)/($repo.repository)/pull-requests/new?source=($src_branch)&dest=($dest)"
    },
    _ => null
  }
}

# Raise a git pull request for the current repository
export def main [dest_branch?: string]: nothing -> nothing {
  let $url = (url $dest_branch)
  if ($url | is-empty) {
    return
  }
  start $url
}