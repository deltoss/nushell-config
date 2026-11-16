use ../git-helpers.nu [parse-git-url]

# Git origin, not the checkout path, identifies a project across worktrees and clones.
export def repository-key []: nothing -> string {
  let origin = ^git config --get remote.origin.url | complete
  if $origin.exit_code != 0 or ($origin.stdout | str trim | is-empty) {
    error make {msg: "No Git origin found in cwd. Run inside a repository with an origin, or set $env.DD_SERVICE"}
  }
  let repository = parse-git-url ($origin.stdout | str trim | str replace --regex '/+$' '')
  if $repository == null or ($repository.host? | is-empty) or ($repository.repository? | is-empty) {
    error make {msg: "Cannot identify the Git origin. Use an SSH/HTTPS origin, or set $env.DD_SERVICE"}
  }
  let host = $repository.host | str replace --regex '^.*@' '' | str lowercase
  $"($host)/($repository.path)"
}

export def repository-root []: nothing -> string {
  let result = ^git rev-parse --show-toplevel | complete
  if $result.exit_code != 0 {
    error make {msg: "Run inside a Git worktree, or set $env.DD_SERVICE"}
  }
  $result.stdout | str trim | path expand --strict
}

export def normalize-rule [rule: record]: nothing -> record {
  if not ('hint' in $rule) or ($rule.service? | describe) != 'string' or ($rule.service | str trim | is-empty) {
    error make {msg: 'Each service rule needs an explicit hint and a non-empty service string'}
  }
  let hint = if $rule.hint == null { '' } else {
    if ($rule.hint | describe) != 'string' { error make {msg: 'Hint must be a string or null'} }
    $rule.hint | str trim
  }
  let hint = if $hint == '' {
    null
  } else if ($hint | str starts-with 'regex:') {
    let pattern = $hint | str substring 6..
    if ($pattern | str trim | is-empty) { error make {msg: 'Regex hint must not be empty; use null for the repo root'} }
    try { '' =~ $pattern | ignore } catch {|error|
      error make {msg: $"Invalid regex hint ($hint): ($error.msg)"}
    }
    $hint
  } else {
    let literal = $hint | str replace --all '\' '/'
    let parts = $literal | str trim --right --char '/' | split row '/'
    if ($literal | str starts-with '/') or ($literal =~ '^[A-Za-z]:') or ($parts | any {|part| $part in ['' '.' '..']}) {
      error make {msg: 'Directory hints must stay relative to the repo root; use null for the root itself'}
    }
    if ($literal | str contains '/') and not ($literal | str ends-with '/') {
      error make {msg: 'Use a trailing / for a directory hint, or a plain filename for a file marker'}
    }
    if ($literal | str ends-with '/') { ($parts | str join '/') + '/' } else { $literal }
  }
  {hint: $hint, service: ($rule.service | str trim)}
}

def normalize-project [project: any]: nothing -> record {
  # Legacy single-service mappings retain their repo-wide behavior.
  let project = if ($project | describe) == 'string' {
    {hints: [{hint: null, service: $project}]}
  } else { $project }
  if ($project | describe --detailed | get type) != 'record' or ($project.hints? | describe --detailed | get type) != 'list' {
    error make {msg: 'Expected a project object with a hints list'}
  }
  {hints: ($project.hints | each {|rule| normalize-rule $rule })}
}

export def load [file: path]: nothing -> record {
  if ($file | path type) == null { return {} }
  let saved = open $file
  if ($saved | describe --detailed | get type) != 'record' {
    error make {msg: $"Expected a JSON object mapping Git origins to service hints in ($file)"}
  }
  $saved | columns | reduce --fold $saved {|repository, mappings|
    let project = try { normalize-project ($mappings | get $repository) } catch {|error|
      error make {msg: $"Invalid hints for ($repository) in ($file): ($error.msg)"}
    }
    $mappings | upsert $repository $project
  }
}

# Shared read operation for the CLI, hint manager and service detection. Never writes.
export def list-rules [file: path, repository: string]: nothing -> table {
  load $file | get --optional $repository | get --optional hints | default []
}

# Add a hint/service pair, or replace exactly the pair the editor originally loaded.
export def save-rule [file: path, repository: string, rule: record, --previous: record]: nothing -> nothing {
  let rule = normalize-rule $rule
  let previous = if $previous == null { null } else { normalize-rule $previous }
  let mappings = load $file
  let hints = $mappings | get --optional $repository | get --optional hints | default []
  if $previous != null and not ($previous in $hints) {
    error make {msg: 'This entry changed or was removed. Refresh and select it again'}
  }
  let hints = if $previous == null { $hints | append $rule } else {
    $hints | each {|existing| if $existing == $previous { $rule } else { $existing } }
  }
  $mappings | upsert $repository {hints: ($hints | uniq)} | write-mappings $file
}

export def remove-rule [file: path, repository: string, rule: record]: nothing -> nothing {
  let rule = normalize-rule $rule
  let mappings = load $file
  let hints = $mappings | get --optional $repository | get --optional hints | default []
  if not ($rule in $hints) {
    error make {msg: 'This entry changed or was removed. Refresh and select it again'}
  }
  $mappings | upsert $repository {hints: ($hints | where {|existing| $existing != $rule })} | write-mappings $file
}

def write-mappings [file: path]: record -> nothing {
  let mappings = $in
  let directory = $file | path dirname
  mkdir $directory
  let temporary = mktemp --tmpdir-path $directory '.project-services.XXXXXX'
  try {
    $mappings | to json | save --force $temporary
    mv --force $temporary $file
  } finally {
    rm --force $temporary
  }
}

# Inspect only cwd and its ancestors, including root. No sibling or recursive discovery.
# All literal matching is case-sensitive; regex hints can opt into (?i).
export def resolve [hints: table, root: path, cwd: path]: nothing -> record {
  let hints = (normalize-project {hints: $hints}).hints
  let root = $root | path expand --strict
  mut directory = $cwd | path expand --strict
  loop {
    # relative-to fails if a symlink or a bad caller puts cwd outside the root.
    let relative = $directory | path relative-to $root
    let relative = if $nu.os-info.name == 'windows' { $relative | str replace --all '\' '/' } else { $relative }
    let directory_hint = if $relative == '' { '' } else { $"($relative)/" }
    let entries = ls --all $directory
    if ($entries | any {|entry| $entry.type == null}) {
      error make {msg: $"Cannot inspect all entries in ($directory)"}
    }
    let files = $entries | where type == file | get name | path basename
    let paths = $files | each {|name| if $relative == '' { $name } else { $"($relative)/($name)" } }
    let candidates = [$directory_hint] | append $paths
    let matches = $hints | where {|rule|
      match $rule.hint {
        null => { $relative == '' }
        $hint if ($hint | str starts-with 'regex:') => {
          let pattern = $hint | str substring 6..
          $candidates | any {|candidate| $candidate =~ $pattern }
        }
        $hint if ($hint | str ends-with '/') => { $hint == $directory_hint }
        $hint => { $hint in $files }
      }
    }
    if ($matches | is-not-empty) {
      return {services: ($matches | get service | uniq | sort), directory: $directory}
    }
    if $relative == '' { break }
    $directory = $directory | path dirname
  }
  {services: ($hints | get service | uniq | sort), directory: null}
}
