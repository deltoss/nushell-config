use ../tools/fzf.nu ['fzf table']

export def menu [] {
  let processes = (
    ps
    | sort-by mem --reverse
    | fzf table --multi --format {|p|
      $"($p.pid | fill -a r -w 8) ($p.name | fill -a l -w 35) ($p.cpu | math round --precision 1 | fill -a r -w 10) ($p.mem | format filesize MB | fill -a r -w 10)"
    } --header="PID     Process Name                   CPU     Memory (Tab to select multiple)"
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