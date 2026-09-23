export def main [count: int = 1 --mark: string = "❯"] {
  let all = (zellij action dump-screen --full | lines)

  let marks = ($all | enumerate | where {|r| $r.item | str contains $mark} | get index)
  if $count < 1 {
    print "Command count must be at least 1"
    return
  }
  if ($marks | length) <= $count {
    print $"Couldn't find (($count + 1)) prompt lines matching ($mark)"
    return
  }

  let start = ($marks | get (($marks | length) - $count - 1))
  let end = ($marks | last)
  let chunk = ($all | slice $start..<$end | str join "\n")

  # Strip obvious secrets from the command line itself
  let chunk = ($chunk | str replace -ra '(?i)(token|key|secret|password)\s*[=:]\s*\S+' '$1=REDACTED')

  let prompt = $"Terminal output from a command. Explain the error and suggest a fix:\n\n($chunk)"
  let prompt_file = (mktemp --suffix .md)
  $prompt | save -f $prompt_file
  ^nvim $prompt_file
  ^pi $"@($prompt_file)"
  rm -fp $prompt_file
}