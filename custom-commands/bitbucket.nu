use ../tools/fzf.nu *
use ./atlassian-helpers.nu [bitbucket-basic-token]

# Perform an authenticated GET against the Bitbucket Cloud v2 API
def bitbucket-get [path: string] {
  http get --headers {
    accept: application/json
    authorization: $"Basic (bitbucket-basic-token)"
  } $"https://api.bitbucket.org/2.0/($path)"
}

export def "get workspaces" [] {
  bitbucket-get "user/permissions/workspaces"
    | get values
    | select workspace.uuid workspace.slug workspace.name
    | rename id slug name
}

export def "select workspace" [] {
  let workspaces = get workspaces
  if ($workspaces | length) <= 1 {
    return ($workspaces | get --optional 0)
  }
  $workspaces | fzf --format {|it| $"($it.name) \(($it.slug)\)" }
}

export def "get repositories" [
  workspace?: string # Workspace name or slug
  query?: string # Optional query to filter results by repository name
] {
  let workspace = $workspace | default --empty (select workspace | get slug)
  let filter = if ($query | is-not-empty) {
    "&q=" + ($"name~\"($query)\"" | url encode)
  } else {
    ""
  }

  bitbucket-get $"repositories/($workspace | url encode)?role=contributor($filter)"
    | get values
    | select name slug
}

# Everything `pr review` needs to know about a Bitbucket pull request URL
export def pr-info [pr_url: string] {
  let parsed = $pr_url
    | parse --regex 'bitbucket\.org/(?<workspace>[^/]+)/(?<repository>[^/]+)/pull-requests/(?<id>\d+)'
    | get --optional 0
  if ($parsed | is-empty) {
    error make {msg: $"Not a recognizable Bitbucket PR URL: ($pr_url)"}
  }

  let pr = bitbucket-get $"repositories/($parsed.workspace)/($parsed.repository)/pullrequests/($parsed.id)"
  if $pr.source.repository.full_name != $pr.destination.repository.full_name {
    error make {msg: "pr review doesn't support pull requests raised from a fork yet"}
  }

  {
    repository: $parsed.repository
    id: $parsed.id
    title: $pr.title
    source_branch: $pr.source.branch.name
    dest_branch: $pr.destination.branch.name
    clone_url: $"git@bitbucket.org:($parsed.workspace)/($parsed.repository).git"
  }
}