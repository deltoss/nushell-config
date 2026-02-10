use std/log
use ./git.nu [ repo-info select-branch ]

export def url [
  dest_branch?: string # Destination branch to create a pull request for
  repo_info?: record # The repo information
] {
  let repo = $repo_info | default { repo-info }
  let src_branch = $repo.branch
  let dest = $dest_branch | default {
    select-branch | if ($in | is-not-empty) {
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
