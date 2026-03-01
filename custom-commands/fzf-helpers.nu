export def "parse fzf" [
  --grep (-g) # Whether to parse as grep search with start lines, end lines and content
] {
  let interaction = $in | lines
  if ($interaction | is-empty) {
    return
  }

  {
    query: $interaction.0
    selections: (if $grep {
      $interaction | skip 1 | par-each {|it|
        $it | split column ":" --number 4 path start end content | insert raw $it | first
      }
    } else {
      $interaction | skip 1
    })
  }
}
