# Cache generated Nushell code without running the generator on every startup.
# Session-specific activation output (such as mise) must always use --force.
export def main [
  tool: string
  args: list<string>
  --output: path # Defaults to vendor/autoload/<tool>.nu
  --force # Regenerate even when the fingerprint matches
] {
  # The ^ prefix skips aliases, custom commands and extern completion declarations.
  let command = (which $"^($tool)").0?
  if $command == null { return }

  try {
    let executable = $command.path | path expand
    let tool_name = $tool | path parse | get stem
    let cache_file = (
      $output
      | default ($nu.data-dir | path join vendor autoload $"($tool_name).nu")
      | path expand
    )

    let metadata = ls $executable | first
    # Keep the fingerprint in the script so content and metadata are replaced together.
    let fingerprint = {
      schema: 1
      executable: $executable
      modified: ($metadata.modified | into int)
      size: ($metadata.size | into int)
      args: $args
    }
    let expected_header = $"# cache-init: ($fingerprint | to json --raw)"
    let cached_header = try { open --raw $cache_file | lines | first } catch { null }
    if not $force and $cached_header == $expected_header { return }

    let result = ^$executable ...$args | complete
    if $result.exit_code != 0 {
      error make {msg: $"generator exited with ($result.exit_code): ($result.stderr | str trim)"}
    }
    if ($result.stdout | str trim | is-empty) {
      error make {msg: 'generator returned empty output'}
    }

    [$expected_header $result.stdout] | str join "\n" | write-cache $cache_file
  } catch {|err|
    print --stderr $"cache-init: ($tool): ($err.msg)"
  }
}

# Finish writing before replacing the current cache, and clean up on failure.
def write-cache [cache_file: path]: string -> nothing {
  let content = $in
  let cache_dir = $cache_file | path dirname
  mkdir $cache_dir

  # No .nu suffix: autoload must never source an unfinished temporary file.
  let temp_file = mktemp --tmpdir-path $cache_dir '.cache-init.XXXXXX'
  try {
    $content | save --force $temp_file
    mv --force $temp_file $cache_file
  } finally {
    rm --force $temp_file
  }
}