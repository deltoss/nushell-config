use std/log
use ./git-helpers.nu [ repo-info, pr-reviews-folder ]
use ./git.nu
use ./worktree-apps.nu
use ./bitbucket.nu [ pr-info ]

def resolve-dest-branch [dest_branch?: string] {
  $dest_branch | default {
    git select branch | if ($in | is-not-empty) {
      get branch | str replace '^origin\/' ''
    }
  }
}

export def url [
  dest_branch?: string # Destination branch to create a pull request for
  repo_info?: record # The repo information
] {
  let repo = $repo_info | default { repo-info }
  let src_branch = $repo.branch
  let dest = resolve-dest-branch $dest_branch

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
    ls --short-names $repo_dir
      | where type == dir and ($it.name | str starts-with $"($pr_id)-")
      | get name
      | each {|name| $repo_dir | path join $name }
  } else {
    []
  }

  $existing | get --optional 0 | default ($repo_dir | path join $"($pr_id)-(slugify $title)")
}

# Add a worktree for the branch if it isn't there yet
def ensure-worktree [bare_dir: string, target_dir: string, branch: string] {
  if ($target_dir | path exists) {
    return
  }

  ^git -C $bare_dir worktree add $target_dir -B $branch $"origin/($branch)"
}

def available-review-modes [] { worktree-apps available-modes }

def open-hunk-pane [dest_branch: string, worktree: string] {
  let command = worktree-apps launch-command "hunk" $"origin/($dest_branch)"

  if ($env.ZELLIJ? | is-not-empty) {
    (^zellij action new-pane
      --cwd $worktree --stacked --no-focus --close-on-exit --name hunk
      -- ...$command) | ignore
  } else {
    run-external ($command | first) ...($command | skip 1)
  }
}

export def self-review [dest_branch: string] {
  let worktree = (^git rev-parse --show-toplevel | str trim)
  ^git fetch origin $dest_branch

  if ($env.ZELLIJ? | is-not-empty) {
    let command = worktree-apps launch-command "nvim" $"origin/($dest_branch)"
    (^zellij action new-pane
      --cwd $worktree --stacked --no-focus --close-on-exit --name nvim
      -- ...$command) | ignore
  }

  open-hunk-pane $dest_branch $worktree

  if ($env.ZELLIJ? | is-not-empty) {
    (^zellij action new-pane
      --cwd $worktree --stacked --no-focus --close-on-exit --name pi
      -- pi "/skill:hunk-self-review") | ignore
  } else {
    ^pi "/skill:hunk-self-review"
  }
}

# Check out a pull request into a dedicated worktree under ~/PRs.
# Clones the repo once per repository (bare clone at ~/PRs/<repo>/.bare), then
# adds a worktree per PR (~/PRs/<repo>/<pr-id>-<title-slug>), so reviewing more
# PRs of the same repo never re-clones. Re-running for the same PR syncs the
# worktree to the latest commits instead.
# To clean up a finished review: git -C ~/PRs/<repo>/.bare worktree remove <folder-name> --force
export def --env review [
  pr_url: string # Pull request URL, e.g. https://bitbucket.org/<workspace>/<repo>/pull-requests/<id>
  --mode: list<string>@available-review-modes # Diff tools to open after checkout. Prompts when omitted
] {
  log info $"Fetching ($pr_url)..."
  let pr = pr-info $pr_url

  let repo_dir = pr-reviews-folder | path join $pr.repository
  let bare_dir = $repo_dir | path join ".bare"
  let target_dir = pr-target-dir $repo_dir $pr.id $pr.title

  ensure-bare-clone $bare_dir $pr.clone_url

  print $"(ansi green)Fetching latest '($pr.source_branch)' and '($pr.dest_branch)'...(ansi reset)"
  ^git -C $bare_dir fetch origin $pr.source_branch $pr.dest_branch

  ensure-worktree $bare_dir $target_dir $pr.source_branch
  cd $target_dir
  ^git reset --hard $"origin/($pr.source_branch)"

  print $"(ansi green)PR #($pr.id) checked out: ($pr.source_branch) -> ($pr.dest_branch)(ansi reset)"
  print $"(ansi green)Worktree: ($target_dir)(ansi reset)"

  worktree-apps launch $"origin/($pr.dest_branch)" $target_dir $mode
}

# Raise a git pull request for the current repository
# Runs pre-pr-raise handlers with the URL and destination branch. Returning false cancels the page.
export def main [dest_branch?: string]: nothing -> nothing {
  let resolved_dest = resolve-dest-branch $dest_branch
  if ($resolved_dest | is-empty) {
    log info "Destination branch not selected. Quitting..."
    return
  }

  let $url = (url $resolved_dest)
  if ($url | is-empty) {
    return
  }
  let hooks = $env.hooks?.pre-pr-raise? | default [] | append []
  for hook in $hooks {
    if (do $hook $url $resolved_dest) == false {
      log info "PR raise cancelled by pre-pr-raise hook."
      return
    }
  }
  start $url
}