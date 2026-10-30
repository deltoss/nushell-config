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
  bitbucket-pages "user/workspaces?pagelen=100"
    | each {|entry|
        {
          id: $entry.workspace.uuid
          slug: $entry.workspace.slug
          name: ($entry.workspace.name? | default $entry.workspace.slug)
        }
      }
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

# List up to 20 recent PRs you authored, including closed PRs.
export def "get pull-requests" [
  --workspace: string # Workspace slug; choose interactively when omitted
] {
  let workspace = $workspace | default --empty { select workspace | get --optional slug }
  if ($workspace | is-empty) { return [] }
  let headers = bitbucket-headers
  let user_id = bitbucket-get user $headers | get uuid | url encode
  let slug = $workspace | url encode
  let states = "state=OPEN&state=MERGED&state=DECLINED&state=SUPERSEDED"

  bitbucket-get $"workspaces/($slug)/pullrequests/($user_id)?($states)&pagelen=20&sort=-updated_on" $headers
  | get values
  | each {|pr|
      let repository = $pr.destination.repository.full_name
      {
        key: $"($repository)#($pr.id)"
        repository: $repository
        title: $pr.title
        state: (if $pr.state == "OPEN" and $pr.draft? == true { "DRAFT" } else { $pr.state })
        role: Author
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