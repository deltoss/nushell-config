export def repo-folder [] {
  # Get the common .git directory
  let $gitCommonDir = git rev-parse --path-format=absolute --git-common-dir

  # Get the main worktree from that
  $gitCommonDir | path dirname
}

export def worktrees-folder [] {
  $"(repo-folder).worktrees/"
}

export def parse-git-url [url: string] {
  let url_info = { protocol: null, host: null, path: null, owner: null, repository: null, full_url: $url }

  let url_info = if ($url =~ '^git@([^:]+):(.+)$') { # Handle SSH format (git@host:path)
    let matches = $url | parse --regex '^git@(?P<host>[^:]+):(?P<path>.+)$' | first
    $url_info | merge { protocol: 'ssh', host: $matches.host, path: ($matches.path | str replace --regex '\.git$' '') }
  } else if ($url =~ '^(\w+)://([^/]+)/(.+)$') { # Handle standard HTTP/HTTPS URLs
    let matches = $url | parse --regex '^(?P<protocol>\w+)://(?P<host>[^/]+)/(?P<path>.+)$' | first
    $url_info | merge { protocol: $matches.protocol, host: $matches.host, path: ($matches.path | str replace --regex '\.git$' '') }
  } else {
    print $"Warning: Could not parse Git URL: ($url)"
    return
  }

  # Extract owner and repo from path
  let path_parts = ($url_info.path | split row '/')
  if ($path_parts | length) >= 2 {
    $url_info | merge {
      repository: ($path_parts | last)
      # Everything except the last part is the owner (handles org/user or just user)
      owner: ($path_parts | drop | str join '/')
    }
  } else {
    $url_info
  }
}

export def repo-info [] {
  let remote_url = (git config --get remote.origin.url | str trim)
  let branch = (git branch --show-current | str trim)

  # Try GitHub
  let github = ($remote_url | parse -r 'github\.com[:\/]([^\/:]+)\/([^.]+)\.git')
  if not ($github | is-empty) {
    return {
      organization: ($github | get capture0.0)
      repository: ($github | get capture1.0)
      branch: $branch
      url: $remote_url
      type: "GitHub"
    }
  }

  # Try Bitbucket
  let bitbucket = ($remote_url | parse -r 'bitbucket\.org[:\/]([^\/:]+)\/([^.]+)\.git')
  if not ($bitbucket | is-empty) {
    return {
      organization: ($bitbucket | get capture0.0)
      repository: ($bitbucket | get capture1.0)
      branch: $branch
      url: $remote_url
      type: "BitBucketCloud"
    }
  }

  null
}
