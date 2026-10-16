# Internal script for the live grep picker. JSON keeps paths separate from display text.
def text [value: record] {
  $value.text? | default { $value.bytes | decode base64 | decode utf-8 }
}

export def "parse matches" []: string -> table {
  $in | from json --objects | where type == 'match' | each {|event|
    {
      path: (text $event.data.path)
      line: $event.data.line_number
      column: ($event.data.submatches.0.start + 1)
      text: (text $event.data.lines | str replace --regex '\r?\n$' '')
    }
  }
}

def main [query: string] {
  ^rg --json --smart-case -- $query
  | parse matches
  | each {|match|
    # Base64 keeps arbitrary paths/content out of fzf's shell quoting and delimiters.
    let payload = $match | to json --raw | encode base64
    let display = $"($match.path):($match.line):($match.column):($match.text)"
      | str replace --all --regex '[\t\r\n]' ' '
    print $"($payload)\t($match.line)\t($display)"
  } | ignore
}