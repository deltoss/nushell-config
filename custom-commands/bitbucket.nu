use ../tools/tui.nu [tui-picker]
use ./atlassian-helpers.nu [bitbucket-basic-token]

def bitbucket-headers [] {
  {
    accept: application/json
    authorization: $"Basic (bitbucket-basic-token)"
  }
}

def bitbucket-get [path: string, headers?: record] {
  http get --max-time 30sec --headers ($headers | default { bitbucket-headers }) $"https://api.bitbucket.org/2.0/($path)"
}

def bitbucket-pages [path: string, headers?: record] {
  let headers = $headers | default { bitbucket-headers }
  mut next = $path
  mut visited = []
  mut rows = []
  while ($next | is-not-empty) {
    if $next in $visited { error make {msg: "Bitbucket returned a repeated page URL"} }
    $visited ++= [$next]
    let page = bitbucket-get $next $headers
    $rows ++= $page.values
    $next = $page.next? | default '' | str replace --regex '^https://api\.bitbucket\.org/2\.0/' ''
  }
  $rows
}

export def "get workspaces" [] {
  bitbucket-pages "user/permissions/workspaces?pagelen=100"
    | select workspace.uuid workspace.slug workspace.name
    | rename id slug name
}

export def "select workspace" [] {
  let workspaces = get workspaces
  if ($workspaces | length) <= 1 {
    return ($workspaces | get --optional 0)
  }
  $workspaces | tui-picker "Select Bitbucket workspace" [name slug]
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

  bitbucket-pages $"repositories/($workspace | url encode)?role=contributor&pagelen=100($filter)"
    | select name slug
}

def pull-request-role [pr: record, user_id: string] {
  if $pr.author.uuid == $user_id { return "Author" }

  let is_reviewer = $pr.reviewers? | default []
    | any {|reviewer| $reviewer.uuid == $user_id }
  let participant = $pr.participants? | default []
    | where user.uuid == $user_id | get --optional 0

  if $is_reviewer or $participant.role? == "REVIEWER" {
    "Reviewer"
  } else if ($participant | is-not-empty) {
    "Participant"
  }
}

# Include authored PRs, assigned reviews, comments, and approvals.
export def "get pull-requests" [
  --workspace: string # Limit to one workspace; defaults to all your workspaces
  --all # Include merged, declined, and superseded PRs
] {
  let headers = bitbucket-headers
  let user = bitbucket-get user $headers
  let workspaces = if ($workspace | is-not-empty) { [{slug: $workspace}] } else { get workspaces }
  let states = if $all { "state=OPEN&state=MERGED&state=DECLINED&state=SUPERSEDED" } else { "state=OPEN" }

  $workspaces
  | each --flatten {|workspace|
      let slug = $workspace.slug | url encode
      bitbucket-pages $"repositories/($slug)?role=member&pagelen=100" $headers
    }
  | each --flatten {|repo|
      let path = $"repositories/($repo.full_name)/pullrequests"
      bitbucket-pages $"($path)?($states)&pagelen=50&sort=-updated_on" $headers
    }
  | each {|pr|
      let repository = $pr.destination.repository.full_name
      # Collection responses omit reviewers and participants.
      let pr = if $pr.author.uuid == $user.uuid {
        $pr
      } else {
        bitbucket-get $"repositories/($repository)/pullrequests/($pr.id)" $headers
      }
      let role = pull-request-role $pr $user.uuid
      if ($role | is-empty) { return }

      {
        key: $"($repository)#($pr.id)"
        repository: $repository
        title: $pr.title
        state: (if $pr.state == "OPEN" and $pr.draft? == true { "DRAFT" } else { $pr.state })
        role: $role
        author: $pr.author.display_name
        url: $pr.links.html.href
        updated: ($pr.updated_on | into datetime)
      }
    }
  | sort-by updated --reverse
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