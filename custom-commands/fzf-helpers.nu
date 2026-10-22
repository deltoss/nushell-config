export def "parse fzf" [
  --grep (-g) # Decode structured match payloads from the grep picker
] : string -> record {
  let interaction = $in | lines
  if ($interaction | is-empty) {
    return {}
  }

  {
    query: $interaction.0
    selections: (if $grep {
      $interaction | skip 1 | each { decode base64 | decode utf-8 | from json }
    } else {
      $interaction | skip 1
    })
  }
}