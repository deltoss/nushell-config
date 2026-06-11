# Converts ASCIICast to gifs
@example "" { agg wezterm-recording.cast.txt recording.gif }
export def --wrapped main [
  ...rest
] {
  let $args = [
    '--idle-time-limit',
    '0.5',
    '--speed',
    '1.5',
    ...$rest
  ]

  ^agg ...$args
}