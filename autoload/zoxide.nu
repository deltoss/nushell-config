use ../profiles/platform.nu [IS_TERMUX]

# Termux uses the standard zoxide command without the desktop search fallback.
source (if $IS_TERMUX { null } else { "../profiles/desktop-zoxide.nu" })