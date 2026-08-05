use std/log
use ./git-helpers.nu [ repo-info, pr-reviews-folder ]
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

# Parse a Bitbucket PR URL into its workspace, repo slug and PR id
export def "parse pr-url" [pr_url: string] {
  let parsed = $pr_url
    | parse --regex 'bitbucket\.org\/(?<workspace>[^\/]+)\/(?<repository>[^\/]+)\/pull-requests\/(?<id>\d+)'
  if ($parsed | is-empty) {
    error make {msg: $"Not a recognizable Bitbucket PR URL: ($pr_url)"}
  }
  $parsed | first
}

# Check out a Bitbucket pull request into a dedicated worktree under ~/PRs.
# Clones the repo once per repository (bare clone at ~/PRs/<repo>/.bare), then
# adds a worktree per PR (~/PRs/<repo>/<pr-id>), so reviewing more PRs of the
# same repo never re-clones. Re-running for the same PR syncs the worktree to
# the latest commits instead.
# To clean up a finished review: git -C ~/PRs/<repo>/.bare worktree remove <pr-id> --force
export def --env review [
  pr_url: string # Bitbucket PR URL, e.g. https://bitbucket.org/<workspace>/<repo>/pull-requests/<id>
] {
  let pr = parse pr-url $pr_url

  log info $"Fetching PR #($pr.id) from Bitbucket..."
  let bb_pr = http get --headers {
    accept: application/json
    authorization: $"Basic ($env.BITBUCKETBASE64AUTHTOKEN)"
  } $"https://api.bitbucket.org/2.0/repositories/($pr.workspace)/($pr.repository)/pullrequests/($pr.id)"

  if $bb_pr.source.repository.full_name != $bb_pr.destination.repository.full_name {
    error make {msg: "pr review doesn't support pull requests raised from a fork yet"}
  }

  let source_branch = $bb_pr.source.branch.name
  let dest_branch = $bb_pr.destination.branch.name
  let repo_dir = (pr-reviews-folder | path join $pr.repository)
  let bare_dir = ($repo_dir | path join ".bare")
  let target_dir = ($repo_dir | path join $pr.id)
  let clone_url = $"git@bitbucket.org:($pr.workspace)/($pr.repository).git"

  if not ($bare_dir | path exists) {
    print $"(ansi green)Cloning ($pr.repository) into ($bare_dir)...(ansi reset)"
    mkdir $repo_dir
    let clone_result = ^git clone --bare $clone_url $bare_dir | complete
    if $clone_result.exit_code != 0 {
      error make {msg: $"git clone failed: ($clone_result.stderr)"}
    }
    # Bare clones have no fetch refspec; add the standard one so
    # `git fetch` maintains refs/remotes/origin/* like a normal clone
    ^git -C $bare_dir config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  }

  print $"(ansi green)Fetching latest '($source_branch)' and '($dest_branch)'...(ansi reset)"
  ^git -C $bare_dir fetch origin $source_branch $dest_branch

  if not ($target_dir | path exists) {
    let wt_result = ^git -C $bare_dir worktree add $target_dir -B $source_branch $"origin/($source_branch)" | complete
    if $wt_result.exit_code != 0 {
      error make {msg: $"git worktree add failed: ($wt_result.stderr)"}
    }
  }

  cd $target_dir
  ^git reset --hard $"origin/($source_branch)"

  print $"(ansi green)PR #($pr.id) checked out: ($source_branch) -> ($dest_branch)(ansi reset)"
  print $"(ansi green)Worktree: ($target_dir)(ansi reset)"
}

# Raise a git pull request for the current repository
export def main [dest_branch?: string]: nothing -> nothing {
  let $url = (url $dest_branch)
  if ($url | is-empty) {
    return
  }
  start $url
}