# 1Password SSH agent configurations
export-env {
  $env.SSH_AUTH_SOCK = if $nu.os-info.name == "windows" {
    '\\.\pipe\openssh-ssh-agent'
  } else {
    "~/.1password/agent.sock" | path expand
  }
}
