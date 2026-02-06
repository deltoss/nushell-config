# Configure Nushell command line editing experience to behave like vim.
$env.config.edit_mode = 'vi'

# Display output tables with more information
$env.config.hooks.display_output = { table -e }

# 1Password SSH agent configurations
if $nu.os-info.name == "windows" {
  $env.SSH_AUTH_SOCK = '\\.\pipe\openssh-ssh-agent'
} else {
  $env.SSH_AUTH_SOCK = "~/.1password/agent.sock" | path expand
}

zoxide init nushell | save -f ~/.zoxide.nu
