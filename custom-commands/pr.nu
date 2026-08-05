use std/log
use ./git-helpers.nu [ repo-info, pr-reviews-folder ]
use ./git.nu
use ../tools/visual-studio.nu ['devenv solution', 'devenv is-installed']
use ../tools/1password.nu [op-secret]

# Basic-auth token for the Bitbucket API, from 1Password
# (or $env.BITBUCKETBASE64AUTHTOKEN when set)
def bitbucket-token [] {
  op-secret BITBUCKETBASE64AUTHTOKEN "op://Work/Atlassian - Work/Scripting - BitBucket"
}

# Perform an authenticated GET against the Bitbucket Cloud v2 API
def bitbucket-get [path: string] {
  http get --headers {
    accept: application/json
    authorization: $"Basic (bitbucket-token)"
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

  bitbucket-get $"repositories/($workspace | url encode)?role=contributor($full_query)"
    | get values
    | select name slug
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

export def "get pull-request" [
  # Workspace name or slug
  workspace: string
  # Repository slug
  repository: string
  # Pull request id
  id: string
] {
  bitbucket-get $"repositories/($workspace)/($repository)/pullrequests/($id)"
}

# Clone the repo as a bare clone if it isn't there yet.
# One bare clone is shared by every PR worktree of that repo.
def ensure-bare-clone [bare_dir: string, clone_url: string] {
  if ($bare_dir | path exists) {
    return
  }

  print $"(ansi green)Cloning ($clone_url) into ($bare_dir)...(ansi reset)"
  mkdir ($bare_dir | path dirname)
  ^git clone --bare $clone_url $bare_dir
  # Bare clones have no fetch refspec; add the standard one so
  # `git fetch` maintains refs/remotes/origin/* like a normal clone
  ^git -C $bare_dir config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
}

# Turn a PR title into a filesystem-friendly folder name fragment
def slugify [text: string] {
  $text
    | str lowercase
    | str replace --all --regex '[^a-z0-9]+' '-'
    | str substring 0..49
    | str trim --char '-'
}

# Find the PR's existing worktree folder (so a retitled PR reuses it),
# or derive a fresh `<id>-<title-slug>` name from the current title
def pr-target-dir [repo_dir: string, pr_id: string, title: string] {
  let existing = if ($repo_dir | path exists) {
    glob ($repo_dir | path join $"($pr_id)-*")
  } else {
    []
  }

  if ($existing | is-not-empty) {
    $existing | first
  } else {
    $repo_dir | path join $"($pr_id)-(slugify $title)"
  }
}

# Add a worktree for the branch if it isn't there yet
def ensure-worktree [bare_dir: string, target_dir: string, branch: string] {
  if ($target_dir | path exists) {
    return
  }

  ^git -C $bare_dir worktree add $target_dir -B $branch $"origin/($branch)"
}

# Visual Studio is Windows-only, so offer it as a diff tool only where installed
def available-review-modes [] {
  if (devenv is-installed) {
    [nvim, hunk, vs, none]
  } else {
    [nvim, hunk, none]
  }
}

def "nu-complete review-modes" [] {
  available-review-modes
}

# Open the checked-out PR diff in the chosen tool, prompting if none was given
def open-diff [dest_branch: string, mode?: string] {
  let mode = $mode | default {
    available-review-modes | input list "Open diff with:"
  }

  # origin/<dest> always exists here (fetched before checkout); a local <dest> branch may not
  let range = $"origin/($dest_branch)...HEAD"
  match $mode {
    "nvim" => { ^nvim -c $"CodeDiff ($range)" }
    "hunk" => { ^hunk $range }
    "vs" => {
      if not (devenv is-installed) {
        log warning "Visual Studio isn't available on this machine"
        return
      }
      print $"(ansi yellow)Visual Studio can't open a branch diff from the command line. To see the full diff:(ansi reset)"
      print $"(ansi bo)(ansi cyan)Git(ansi reset) > (ansi bo)(ansi cyan)Manage Branches(ansi reset) > right-click (ansi bo)(ansi green)origin/($dest_branch)(ansi reset) > (ansi bo)(ansi cyan)Compare with Current Branch(ansi reset)"
      devenv solution
    }
    "none" | "" | null => {}
    _ => { log warning $"Unknown mode '($mode)', skipping diff" }
  }
}

# Check out a Bitbucket pull request into a dedicated worktree under ~/PRs.
# Clones the repo once per repository (bare clone at ~/PRs/<repo>/.bare), then
# adds a worktree per PR (~/PRs/<repo>/<pr-id>-<title-slug>), so reviewing more
# PRs of the same repo never re-clones. Re-running for the same PR syncs the
# worktree to the latest commits instead.
# To clean up a finished review: git -C ~/PRs/<repo>/.bare worktree remove <folder-name> --force
export def --env review [
  pr_url: string # Bitbucket PR URL, e.g. https://bitbucket.org/<workspace>/<repo>/pull-requests/<id>
  --mode: string@"nu-complete review-modes" # Diff tool to open after checkout: nvim, hunk, vs (Windows only) or none. Prompts when omitted
] {
  let pr = parse pr-url $pr_url

  log info $"Fetching PR #($pr.id) from Bitbucket..."
  let bb_pr = get pull-request $pr.workspace $pr.repository $pr.id
  if $bb_pr.source.repository.full_name != $bb_pr.destination.repository.full_name {
    error make {msg: "pr review doesn't support pull requests raised from a fork yet"}
  }
  let source_branch = $bb_pr.source.branch.name
  let dest_branch = $bb_pr.destination.branch.name

  let repo_dir = (pr-reviews-folder | path join $pr.repository)
  let bare_dir = ($repo_dir | path join ".bare")
  let target_dir = pr-target-dir $repo_dir $pr.id $bb_pr.title

  ensure-bare-clone $bare_dir $"git@bitbucket.org:($pr.workspace)/($pr.repository).git"

  print $"(ansi green)Fetching latest '($source_branch)' and '($dest_branch)'...(ansi reset)"
  ^git -C $bare_dir fetch origin $source_branch $dest_branch

  ensure-worktree $bare_dir $target_dir $source_branch
  cd $target_dir
  ^git reset --hard $"origin/($source_branch)"

  print $"(ansi green)PR #($pr.id) checked out: ($source_branch) -> ($dest_branch)(ansi reset)"
  print $"(ansi green)Worktree: ($target_dir)(ansi reset)"

  open-diff $dest_branch $mode
}

# Raise a git pull request for the current repository
export def main [dest_branch?: string]: nothing -> nothing {
  let $url = (url $dest_branch)
  if ($url | is-empty) {
    return
  }
  start $url
}