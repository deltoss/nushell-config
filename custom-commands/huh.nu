export def main [--mark: string = "❯"] {
  let all = (zellij action dump-screen --full | lines)

  let marks = ($all | enumerate | where {|r| $r.item | str contains $mark} | get index)
  if ($marks | length) < 2 {
    print $"Couldn't find two prompt lines matching ($mark)"
    return
  }

  let chunk = ($all | slice ($marks | last 2 | first)..<($marks | last) | str join "\n")

  # Strip obvious secrets from the command line itself
  let chunk = ($chunk | str replace -ra '(?i)(token|key|secret|password)\s*[=:]\s*\S+' '$1=REDACTED')

  $chunk | pi -p "Terminal output from my last command. Explain the error and suggest a fix." | bat -l md -p --paging=never
}