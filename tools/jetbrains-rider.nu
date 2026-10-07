use "../custom-commands/fzf-helpers.nu" ['parse fzf']
use "../custom-commands/start.nu"

# Prefer subcommands to bare paths. Use ./ for paths sharing their prefix.
def "nu-complete rider" [spans: list<string>] {
  if ($spans | length) != 2 { return null }
  let prefix = $spans | last | str lowercase
  let matches = [projects recent solution] | where {|name| $name | str starts-with $prefix}
  if ($matches | is-empty) { null } else { $matches }
}

# Launch JetBrains Rider.
#
# Add Rider's bin directory or Toolbox's shell scripts directory to PATH.
@example "Launch Rider" { rider }
@example "Open a solution" { rider MySolution.sln }
@complete "nu-complete rider"
export def --wrapped rider [...rest] {
  # Prefer the GUI launcher over scripts that launches console windows.
  let launcher = (which --all rider64 rider rider.sh | where type == external | get --optional path.0)
  if ($launcher | is-empty) {
    error make { msg: "No Rider launcher found on PATH. Add Rider's bin directory or JetBrains Toolbox's shell scripts directory to PATH." }
  }

  if $nu.os-info.name == "windows" {
    if ($rest | is-empty) {
      start $launcher
    } else {
      start detached $launcher ...$rest
    }
  } else {
    job spawn { ^$launcher ...$rest } | ignore
  }
}

# Find and launch solutions in the current directory and subdirectories.
@example "Select solutions with fzf" { rider solution }
@example "Start with a search query" { "MyApp" | rider solution }
export def --wrapped "rider solution" [...rest] {
  let query = $in | default ''
  let solutions = glob --no-dir "**/*.{sln,slnx}"
  if ($solutions | is-empty) {
    print "No .NET solutions found in the current directory or its subdirectories."
    return
  }

  pick solutions $solutions $query 'Search - .NET Solutions (Tab to Select)' $rest
}

# Pick and launch recent projects from Rider's saved history, newest first.
@example "Select recent projects with fzf" { rider recent }
@example "Start with a search query" { "MyApp" | rider recent }
export def --wrapped "rider recent" [...rest] {
  let query = $in | default ''
  let history = "~/.config/rider/options/recentSolutions.xml" | path expand
  let solutions = recent solutions $history
  if ($solutions | is-empty) {
    print "No existing recent Rider projects found."
    return
  }

  pick solutions $solutions $query 'Search - Rider Recent Projects (Tab to Select)' $rest
}

# Find and launch solutions recursively under the directories in PROJECT_DIRS.
# Uses fd's default hidden-file and ignore rules.
@example "Search all configured project directories" { rider projects }
@example "Start with a search query" { "MyApp" | rider projects }
export def --wrapped "rider projects" [...rest] {
  let query = $in | default ''
  let solutions = project solutions ($env.PROJECT_DIRS? | default [])
  if ($solutions | is-empty) {
    print "No .NET solutions found in the configured project directories."
    return
  }

  pick solutions $solutions $query 'Search - Project Solutions (Tab to Select)' $rest
}

# Register subcommand aliases so Nushell can complete rd pro, rd re, and rd so.
export alias rd = rider
export alias "rd solution" = rider solution
export alias "rd recent" = rider recent
export alias "rd projects" = rider projects

def "project solutions" [dirs: list<string>] {
  if ($dirs | is-empty) {
    error make { msg: "Set PROJECT_DIRS to an array of project-directory paths in ~/.config/nushell/.env.json." }
  }

  mut roots = []
  for directory in $dirs {
    let root = $directory | path expand
    if ($root | path type) != 'dir' {
      error make { msg: $"Project directory not found or not a directory: ($root)" }
    }
    $roots ++= [$root]
  }
  $roots = ($roots | uniq)

  let result = ^fd --type f --extension sln --extension slnx --absolute-path --color never '' ...$roots | complete
  if $result.exit_code != 0 {
    error make { msg: $"Project solution search failed: ($result.stderr | str trim)" }
  }
  $result.stdout | lines | uniq | sort
}

def "recent solutions" [history: path] {
  if not ($history | path exists) {
    error make { msg: $"Rider recent-project history not found: ($history)" }
  }

  let entries = open $history
    | get content
    | where attributes.name? == RiderRecentProjectsManager
    | get --optional 0.content
    | default []
    | where attributes.name? == additionalInfo
    | get --optional 0.content.0.content
    | default []

  $entries | each {|entry|
    {
      path: ($entry.attributes.key | str replace '$USER_HOME$' $nu.home-dir)
      last_used: ($entry | get --optional content.0.content.0.content | default [] | where attributes.name? == activationTimestamp | get --optional 0.attributes.value | default 0 | into int)
    }
  } | sort-by --reverse last_used | get --optional path | default [] | where { path exists } | uniq
}

def "pick solutions" [solutions: list<string>, query: string, header: string, rest: list] {
  let result = $solutions | str join "\n" | ^fzf --multi --header=$header --print-query --query $query | complete
  if $result.exit_code in [1 130] { return }
  if $result.exit_code != 0 {
    error make { msg: $"Solution picker failed: ($result.stderr | str trim)" }
  }

  let interaction = $result.stdout | parse fzf
  for solution in ($interaction | get --optional selections | default []) {
    rider $solution ...$rest
  }
}