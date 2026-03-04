use "../custom-commands/fzf-helpers.nu" ['parse fzf']

# Sample usage:
#   devenv MySolution.sln
#   devenv MySolution.sln /build "Debug|Any CPU"
#   devenv MySolution.sln /rebuild "Release|x64"
#   devenv MySolution.sln /clean
export def --wrapped devenv [...rest] {
  let vsPath = (
    ^'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    -latest
    -prerelease
    -property installationPath
    | str trim
  )

  if ($vsPath | is-not-empty) {
    let devenvPath = ($vsPath | path join "Common7" "IDE" "devenv.exe")
    job spawn { ^$devenvPath ...$rest } | ignore
  } else {
    error make { msg: "No Visual Studio installation found" }
  }
}

# Launch a solution file in current directory or sub directories
export def --wrapped "devenv solution" [...rest] {
  let query = $in | default ''
  let interaction = glob "**/*.sln" | str join "\n" | fzf --multi --header='Search - .NET Solution' --print-query --query $query | parse fzf
  if ($interaction | is-empty) or ($interaction | get selections | is-empty) {
    return
  }
  devenv ($interaction | get selections.0)
}