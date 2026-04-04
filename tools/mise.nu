const mise_dir_path = $nu.data-dir | path join "mise"
const mise_path = $mise_dir_path | path join "mise.nu"

if not ($mise_path | path exists) {
  mkdir $mise_dir_path
  ^mise activate nu | save $mise_path --force
}

use (if ($mise_path | path exists) { $mise_path } else { null })