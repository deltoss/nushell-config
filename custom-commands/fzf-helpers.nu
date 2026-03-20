export def "parse fzf" [
--grep (-g) # Whether to parse as grep search with start lines, end lines and content
] : string -> record {
  let interaction = $in | lines
  if ($interaction | is-empty) {
    return
  }

  {
    query: $interaction.0
    selections: ($interaction | skip 1)
  }
}