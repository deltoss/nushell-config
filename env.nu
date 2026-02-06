# Configure Nushell command line editing experience to behave like vim.
$env.config.edit_mode = 'vi'

# Display output tables with more information
$env.config.hooks.display_output = { table -e }

zoxide init nushell | save -f ~/.zoxide.nu
