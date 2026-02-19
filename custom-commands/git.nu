export def menu [] {
  print 'b ⟶ Select git [B]ranch'
  print 'c ⟶ Select git [C]ommit'
  print 'f ⟶ Select git [F]ile'
  print 'l ⟶ Show git [L]og'
  print 'g ⟶ Lazy[G]it'
  print 'G ⟶ Edit GitHub [G]ists'
  print 'm ⟶ Resolve git [M]erge conflicts'
  print 'p ⟶ Open [P]ull request'
  print 'w ⟶ [W]orktree'

  mut result = ''
  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['b', []] => { $result = (select-branch | get --optional branch); break }
      ['c', []] => { $result = select-commit; break }
      ['f', []] => { $result = select-file; break }
      ['l', []] => { $result = log; break }
      ['g', []] => { commandline edit  --accept --replace "lazygit"; break }
      ['G', []] => { commandline edit  --accept --replace "gh gist edit"; break }
      ['m', []] => { commandline edit  --accept --replace "git mergetool"; break }
      ['p', []] => { commandline edit  --accept --replace "pr"; break }
      ['w', []] => { break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  $result
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

export def select-branch --wrapped [
  --extra: list<string> = []
  ...rest
] {
  let branches = (git branch -a --color ...$rest | lines)
  let all = ($extra ++ $branches)
  let interaction = $all | str join "\n" | fzf --print-query --ansi --header="Git - Branches" | lines

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
      branch: ($interaction | get 1 
        | str trim 
        | str replace --regex '^\*\s*' ''
        | str replace --regex '^remotes/' ''
        | str replace --regex '\x1b\[[0-9;]*m' ''
        | str replace --regex '\+\s+' ''
        | str replace --regex '\s*->.+' '')
    }
  }
}

export def select-commit --wrapped [
  ...rest
] {
  ^git log --all --color=always --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset) %H" --date=format:"%Y-%m-%d %I:%M %p" ...$rest
  | fzf --print-query --ansi --header="Git - Commits" 
  | str trim
  | ansi strip
  | split row ' '
  | first
}

export def select-file --wrapped [
  ...rest
] {
  git status --porcelain ...$rest | fzf --header="Git - Changed Files"
  | str substring 3..-1
  | str trim
}

export def log --wrapped [
  ...rest
] {
  let $args = [
    '--graph',
    '--pretty=format:%C(yellow)%h%Creset %C(green)%ad%Creset %C(bold blue)%an%Creset %C(red)%d%Creset %s %C(dim white)%b%Creset',
    '--date=short',
    '--color',
    ...$rest
  ]

  ^git log ...$args
}

export def log-menu --wrapped [
  ...rest
] {
  let $selection = select-branch --extra ["  HEAD", "  --all"]
  if ($selection | is-empty) {
    return
  }

  log ($selection | get branch)
}
