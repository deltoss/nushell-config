# Sample usage:
#   devenv MySolution.sln
#   devenv MySolution.sln /build "Debug|Any CPU"
#   devenv MySolution.sln /rebuild "Release|x64"
#   devenv MySolution.sln /clean
export def --wrapped devenv [...args] {
  let vsPath = (
    ^'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    -latest
    -prerelease
    -property installationPath
    | str trim
  )

  if ($vsPath | is-not-empty) {
    let devenvPath = ($vsPath | path join "Common7" "IDE" "devenv.exe")
    ^$devenvPath ...$args
  } else {
    error make { msg: "No Visual Studio installation found" }
  }
}
