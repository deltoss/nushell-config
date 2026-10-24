const preview_line_limit = 80
const preview_byte_limit = 65536 # 64 KiB

# List changed files with literal paths and rename/copy source paths.
export def --wrapped changed-files [...rest] {
  let root = git-output rev-parse --show-toplevel | str trim
  git-output status --porcelain=v1 -z --untracked-files=all ...$rest
  | parse-status $root
}

# Preview a record returned by changed-files.
export def file-preview [file: record] {
  let text = if $file.status == "??" {
    let content = read-text-preview ($file.root | path join $file.path)
    $"Untracked: ($file.path) \(first 64 KiB\)\n\n($content)"
  } else {
    [
      $file.path
      (file-diff $file --staged | format-diff-section "Staged changes")
      (file-diff $file | format-diff-section "Unstaged changes")
    ] | compact --empty | str join "\n\n"
  }
  $text | limit-preview-lines
}

# Preview a record with a Git commit hash.
export def commit-preview [commit: record] {
  let options = [
    --no-ext-diff --no-textconv --color=always
    --format=fuller "--stat=70,45,20"
  ]
  git-output show ...$options $commit.hash -- | limit-preview-lines
}

# Preview an actual ref, HEAD, or the branch picker's special --all entry.
export def branch-preview [reference: string] {
  let revisions = if $reference == "--all" {
    [--all --end-of-options]
  } else {
    [--end-of-options $reference]
  }
  git-output log --color=always --oneline -20 ...$revisions -- | limit-preview-lines
}

# Porcelain -z uses "XY path\0", or "XY destination\0source\0" for renames/copies.
def parse-status [root: string] {
  let entries = $in | split row (char nul) | compact --empty
  mut rows = []
  mut index = 0
  while $index < ($entries | length) {
    let entry = $entries | get $index
    let status = $entry | str substring 0..1
    let has_source_path = $status =~ '[RC]'
    let original_path = if $has_source_path { $entries | get ($index + 1) } else { null }
    $rows ++= [{
      status: $status
      path: ($entry | str substring 3..)
      original_path: $original_path
      root: $root
    }]
    $index += (if $has_source_path { 2 } else { 1 })
  }
  $rows
}

def file-diff [file: record, --staged] {
  let paths = [$file.original_path $file.path] | compact --empty
  # Do not invoke configured external diff tools or text converters for previews.
  let options = [--no-ext-diff --no-textconv --color=always --find-renames]
  let options = if $staged { $options | prepend "--cached" } else { $options }
  git-output --literal-pathspecs -C $file.root diff ...$options -- ...$paths
}

def format-diff-section [heading: string] {
  let patch = $in
  if ($patch | is-empty) { return null }
  $"($heading)\n($patch)"
}

# Read at most 64 KiB; do not follow symlinks or open special files.
def read-text-preview [path: string] {
  let kind = $path | path type
  if $kind != "file" { return $"[($kind): preview omitted]" }

  try {
    let data = open --raw $path | bytes at ..($preview_byte_limit - 1)
    if ($data | bytes index-of 0x[00]) >= 0 {
      "[Binary file: preview omitted]"
    } else {
      $data | decode utf-8
    }
  } catch {
    "[Unable to read file]"
  }
}

# Native previews wrap text but do not provide an independent pager.
def limit-preview-lines [] {
  let lines = $in | lines | take ($preview_line_limit + 1)
  if ($lines | length) <= $preview_line_limit {
    return ($lines | str join "\n")
  }
  $lines | take $preview_line_limit | append "[Preview truncated]" | str join "\n"
}

def --wrapped git-output [...args: string] {
  let result = ^git --no-pager ...$args | complete
  if $result.exit_code != 0 {
    error make {msg: ($result.stderr | str trim)}
  }
  $result.stdout
}