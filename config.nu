# config.nu
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

use ./profiles/platform.nu [IS_TERMUX]

# Select at parse time so commands and aliases remain available in the shell.
source (if $IS_TERMUX { "./profiles/termux.nu" } else { "./profiles/desktop.nu" })