export def main --wrapped [cmd, ...rest] {
  let os = $nu.os-info.name

  if $os == "windows" {
    let arg_list = ($rest | each { |a| $'"`"($a)`""' } | str join ',')
    let command = $"Start-Process -FilePath '($cmd)' -ArgumentList ($arg_list)";
    # print $arg_list
    # print $command
    ^powershell -NoProfile -NoLogo -Command $command
  } else {
    print "Not supported to run on any OS aside from Windows"
  }
}