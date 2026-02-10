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

export def select-branch --wrapped [
  ...rest  # Rest parameter for additional selections
] {
  let branches = git branch -a --color | lines
  let all_options = $rest | append $branches

  let interaction = (
    $all_options 
    | str join "\n" 
    | fzf --print-query --ansi --header="Git - Branches" 
    | lines
    | each { |line|
        $line 
        | str trim
        | str replace --regex '^\*\s*' ''
        | str replace --regex '^remotes/' ''
        | str replace --regex '\x1b\[[0-9;]*m' ''
        | str replace --regex '\+\s+' ''
        | str replace --regex '\s*->.+' ''
      }
  )

  # Return null if nothing selected
  if ($interaction | is-empty) {
    return null
  }

  # Check if we got a query only or query + selection
  if ($interaction | length) == 1 {
    return {
      query: ($interaction | get 0)
      branch: null
    }
  } else {
    return {
      query: ($interaction | get 0)
      branch: ($interaction | get 1)
    }
  }
}
