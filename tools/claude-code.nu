# Configures Claude Code to use Serena.
# See https://oraios.github.io/serena/02-usage/030_clients.html#claude-code
#
# The extern must be imported here, before the alias: an alias over a same-named
# extern inherits its signature, the only way to keep completions on a shadowed
# command (`def --wrapped` loses them). Importing it anywhere loaded after tools/
# would win and replace this alias with the bare external command.
export use ../nu_scripts/custom-completions/claude/claude-completions.nu *

const prompt_cache = ($nu.cache-dir | path join "serena-cc-system-prompt.txt")

# The serena call takes ~4s, so cache it instead of computing per launch. Aliases
# can't run logic, hence priming here. Delete the cache file after a Serena upgrade.
export-env {
  if (not ($prompt_cache | path exists)) and (which serena | is-not-empty) {
    # `decode utf-8`: external stdout is a byte stream here.
    let prompt = serena prompts print-cc-system-prompt-override | decode utf-8
    if ($prompt | str trim | is-empty) {
      # Not `error make`: a bad serena shouldn't break every new shell.
      print -e "serena returned an empty system prompt, not caching it"
    } else {
      mkdir ($prompt_cache | path dirname)
      $prompt | save -f $prompt_cache
    }
  }
}

export alias claude = claude --dangerously-skip-permissions --system-prompt-file $prompt_cache