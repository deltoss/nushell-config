# 1Password SSH agent configurations
export-env {
  $env.SSH_AUTH_SOCK = if $nu.os-info.name == "windows" {
    '\\.\pipe\openssh-ssh-agent'
  } else {
    "~/.1password/agent.sock" | path expand
  }
}

# Read a secret via the 1Password CLI, so no credential material needs to
# live in config files. An already-set env var takes priority over the
# `op` round-trip, acting as a manual override
export def op-secret [
  env_key: string # Environment variable that overrides the 1Password lookup
  ref: string # 1Password secret reference, e.g. op://Vault/Item/Field
] {
  let override = $env | get --optional $env_key
  if ($override | is-not-empty) {
    return $override
  }
  ^op read $ref | str trim
}
