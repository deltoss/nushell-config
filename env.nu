# Configure Nushell command line editing experience to behave like vim.
$env.config.edit_mode = 'vi'
$env.config.cursor_shape.vi_insert = "blink_line"
$env.config.cursor_shape.vi_normal = "blink_block"

$env.config.completions.algorithm = "fuzzy"

# When true, the current directory and running command are shown in the terminal tab/window title.
# Also abbreviates the directory name by prepending ~ to the home directory and its subdirectories.
$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true

$env.config.datetime_format.normal = "%d/%m/%y %I:%M:%S%p"

# Display output tables with more information
$env.config.hooks.display_output = { table -e }

zoxide init nushell | save -f ~/.zoxide.nu
