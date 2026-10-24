use ../tools/tui.nu [tui-picker]

export def menu [] {
  let processes = (
    ps --long
    | sort-by mem --reverse
    | tui-picker "Processes to kill" [pid name cpu mem] --multi --preview {|process|
        $process | select --optional pid ppid name command cwd start_time | to yaml
      }
  )
  if ($processes | is-empty) { return }

  print $"(ansi yellow)About to kill ($processes | length) process\(es\):(ansi reset)"
  $processes | each { |p| print $"(ansi cyan)  - ($p.pid) ($p.name)(ansi reset)" }

  print "Proceed? (y/N)"
  let key = (input listen --types [key])
  if ($key.code != "y") {
    print $"(ansi grey)Cancelled.(ansi reset)"
    return
  }

  $processes | each { |p|
    try {
      print $"(ansi red)Killing ($p.pid) ($p.name)...(ansi reset)"
      kill --force $p.pid
      print $"(ansi green)✓ Killed ($p.pid) ($p.name)(ansi reset)"
    } catch { |e|
      print $"(ansi red)✗ Failed ($p.pid) ($p.name): ($e.msg)(ansi reset)"
    }
  } | ignore
}