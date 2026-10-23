use ./tui.nu [tui-picker]
use "../custom-commands/start.nu"

const vswhere_path = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'

# Visual Studio is Windows-only; vswhere is its canonical locator.
# Cheap path check (no process spawn) so callers can gate VS-only features
export def "devenv is-installed" [] {
  $nu.os-info.name == "windows" and ($vswhere_path | path exists)
}

# Sample usage:
#   devenv MySolution.sln
#   devenv MySolution.sln /build "Debug|Any CPU"
#   devenv MySolution.sln /rebuild "Release|x64"
#   devenv MySolution.sln /clean
export def --wrapped devenv [...rest] {
  let vsPath = (
    ^$vswhere_path
    -latest
    -prerelease
    -property installationPath
    | str trim
  )

  if ($vsPath | is-not-empty) {
    let devenvPath = ($vsPath | path join "Common7" "IDE" "devenv.exe")
    start detached $devenvPath ...$rest
  } else {
    error make { msg: "No Visual Studio installation found" }
  }
}

# Launch a solution file in current directory or sub directories
export def --wrapped "devenv solution" [...rest] {
  let query = $in | default ''
  let solutions = glob "**/*.sln"
    | where {|path| ($query | is-empty) or ($path | str contains --ignore-case $query) }
    | each {|path| {path: $path} }
  let selected = $solutions | tui-picker "Select .NET solutions" [path] --multi
  for solution in $selected {
    devenv $solution.path
  }
}