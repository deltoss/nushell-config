use ./cache-init.nu

# Activation embeds session state: always refresh, and finish before autoload reads it.
cache-init mise [activate nu] --force