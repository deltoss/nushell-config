# So it more correctly & quickly detects the correct shell
# See: https://github.com/sigoden/aichat/wiki/Environment-Variables
$env.AICHAT_SHELL = $nu.current-exe

source ./shell-integrations.nu
use ./autocompletions.nu *
