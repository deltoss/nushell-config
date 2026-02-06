# So it more correctly & quickly detects the correct shell
# See: https://github.com/sigoden/aichat/wiki/Environment-Variables
export-env {
  $env.AICHAT_SHELL = $nu.current-exe
}

source ./shell-integrations.nu
export module ./autocompletions.nu
