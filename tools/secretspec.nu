# Fetch a secret with SecretSpec. An environment override always wins.
# Cached values are managed by SecretSpec's OS-keyring provider, not this shell.
export def secret-value [key: string] {
  let override = $env | get --optional $key
  if ($override | is-not-empty) {
    return $override
  }

  let manifest = $nu.default-config-dir | path join "secretspec.toml"
  let result = ^secretspec --file $manifest get $key | complete
  if $result.exit_code != 0 {
    error make {msg: $"Could not read ($key) with SecretSpec: ($result.stderr | str trim)"}
  }
  let value = $result.stdout | str trim
  if ($value | is-empty) {
    error make {msg: $"SecretSpec returned an empty value for ($key)"}
  }
  $value
}