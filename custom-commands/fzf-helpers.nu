export def "parse fzf" [--code] {
  let interaction = $in | lines
  if ($interaction | is-empty) {
    return
  }

  {
    query: $interaction.0
    selections: (if ($code | is-not-empty) {
        $interaction | skip 1 | each {|it|
          $it | split column ":" --number 4 path start end content | insert raw $it | first
        }
      } else {
        ($interaction | skip 1)
      })
  }
}
