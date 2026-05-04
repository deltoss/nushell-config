export def main --wrapped [...rest] {
  let is_subcommand = ($rest | is-not-empty) and (($rest | first) | str starts-with '-' | not $in)
  let filtered_args = if $is_subcommand or ('--port' in $rest) {
    $rest
  } else {
    $rest | append ['--port', $env.OPENCODE_PORT]
  }

  ^opencode ...$filtered_args
}