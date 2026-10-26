# Nu checks PWD hooks before pre_prompt; mise only needs its unconditional prompt hook.
let is_mise_hook = {|hook|
  if ($hook | describe) =~ '^record' and ($hook.code? | describe) =~ '^closure' {
    # Match the generated hook only; leave unrelated directory hooks alone.
    (view source $hook.code | str trim) == '{ mise_hook }'
  } else {
    false
  }
}

# If a future integration stops providing the prompt hook, keep the PWD fallback.
if ($env.config.hooks.pre_prompt? | default [] | any $is_mise_hook) {
  $env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | where {|hook|
      not (do $is_mise_hook $hook)
    }
  )
}