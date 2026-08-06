use std/log
use ./git-helpers.nu [ repo-info, pr-reviews-folder ]
use ./git.nu
use ../tools/visual-studio.nu ['devenv solution', 'devenv is-installed']
use ./bitbucket.nu

# Everything the review flow needs about a pull request, whichever host it lives on.
# Supporting another host means writing a `<host>.nu` with a `pr-info` command
# returning this same record, then adding an arm here
def pr-info [pr_url: string] {
  match ($pr_url | url parse | get host) {
    "bitbucket.org" => (bitbucket pr-info $pr_url)
    $host => (error make {msg: $"pr review doesn't support ($host) yet"})
  }
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

# Visual Studio is Windows-only, so offer it as a diff tool only where installed
def available-review-modes [] {
  if (devenv is-installed) {
    [nvim, hunk, vs]
  } else {
    [nvim, hunk]
  }
}

# `devenv solution` is a Nushell command, so a fresh shell has to import it first.
# zellij strips '\' from the args it forwards after '--', so the path has to use
# forward slashes; Nushell accepts those on Windows anyway.
def vs-launch-command [] {
  let script = $nu.default-config-dir | path join tools visual-studio.nu | str replace --all '\' '/'
  [nu -c $"use '($script)' ['devenv solution']; devenv solution"]
}

# The external command each mode runs, as [exe, ...args]. Null when unsupported.
def diff-command [mode: string, range: string] {
  match $mode {
    "nvim" => [nvim -c $"CodeDiff ($range)"]
    "hunk" => [hunk $range]
    "vs" => {
      if (devenv is-installed) {
        vs-launch-command
      } else {
        log warning "Visual Studio isn't available on this machine"
        null
      }
    }
    _ => { log warning $"Unknown mode '($mode)', skipping diff"; null }
  }
}

# Visual Studio can't take a branch diff from the CLI, so tell the user where to click
def print-vs-hint [dest_branch: string] {
  print $"(ansi yellow)Visual Studio can't open a branch diff from the command line. To see the full diff:(ansi reset)"
  print $"(ansi bo)(ansi cyan)Git(ansi reset) > (ansi bo)(ansi cyan)Manage Branches(ansi reset) > right-click (ansi bo)(ansi green)origin/($dest_branch)(ansi reset) > (ansi bo)(ansi cyan)Compare with Current Branch(ansi reset)"
}

# Open the checked-out PR diff in the chosen tools, prompting if none were given.
# Inside zellij each tool gets its own stacked pane rooted at the worktree, so
# several can be open at once; the calling pane stays free. Outside zellij the
# tools run one after another instead.
def open-diff [dest_branch: string, worktree: string, modes?: list<string>] {
  let modes = $modes
    | default { available-review-modes | input list --multi "Open diff with (space to pick, enter to confirm):" }
    | default []
    | where {|mode| $mode not-in ["" "none" null] }

  # origin/<dest> always exists here (fetched before checkout); a local <dest> branch may not
  let range = $"origin/($dest_branch)..." # Note we don't do ...HEAD so it compares against the working directory. Useful so LSPs may kick-in properly
  let in_zellij = $env.ZELLIJ? | is-not-empty

  for mode in $modes {
    let command = diff-command $mode $range
    if ($command | is-empty) { continue }
    if $mode == "vs" { print-vs-hint $dest_branch }

    if $in_zellij {
      (^zellij action new-pane
        --cwd $worktree --stacked --close-on-exit --name $mode
        -- ...$command) | ignore
    } else {
      run-external ($command | first) ...($command | skip 1)
    }
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

  open-diff $pr.dest_branch $target_dir $mode
}

# Raise a git pull request for the current repository
export def main [dest_branch?: string]: nothing -> nothing {
  let $url = (url $dest_branch)
  if ($url | is-empty) {
    return
  }
  start $url
}