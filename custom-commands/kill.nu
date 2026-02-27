export def menu [] {
  let selected = (
    ps
    | sort-by mem --reverse
    | each { |p| $"($p.pid | fill -a r -w 8) ($p.name | fill -a l -w 35) ($p.cpu | math round --precision 1 | fill -a r -w 10) ($p.mem | format filesize MB | fill -a r -w 10)" }
    | str join "\n"
    | fzf --multi --header="PID     Process Name                   CPU (Tab to select multiple)"
    | lines
  )
  if ($selected | is-empty) { return }
  let processes = ($selected | each { |s| $s | str trim | parse --regex '(?P<id>\d+)\s+(?P<name>.*?)\s{2,}' | first })

  print $"(ansi yellow)About to kill ($processes | length) process\(es\):(ansi reset)"
  $processes | each { |p| print $"(ansi cyan)  - ($p.id) ($p.name)(ansi reset)" }

  print "Proceed? (y/N)"
  let key = (input listen --types [key])
  if ($key.code != "y") {
    print $"(ansi grey)Cancelled.(ansi reset)"
    return
  }

  $processes | each { |p|
    try {
      print $"(ansi red)Killing ($p.id) ($p.name)...(ansi reset)"
      kill --force ($p.id | into int)
      print $"(ansi green)✓ Killed ($p.id) ($p.name)(ansi reset)"
    } catch { |e|
      print $"(ansi red)✗ Failed ($p.id) ($p.name): ($e.msg)(ansi reset)"
    }
  } | ignore
}
