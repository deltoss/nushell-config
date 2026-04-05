export def --wrapped main [...rest] {
  blkid ...$rest | lines | parse '{device}: {fields}' | each { |row|
    let parsed = ($row.fields | split row '" ' | each { parse '{key}="{value}' } | flatten | reduce --fold {} { |it, acc| $acc | insert ($it.key | str downcase) ($it.value | str trim --char '"') })
    $parsed | insert device $row.device
  }
}