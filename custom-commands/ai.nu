# Bring up interactive menu for AI operations
export def menu [] {
  print $"(ansi bo)(ansi cyan)a(ansi bl) ⟶ (ansi reset)[(ansi bo)A(ansi reset)]I"
  print $"(ansi bo)(ansi cyan)e(ansi bl) ⟶ (ansi reset)[(ansi bo)E(ansi reset)]xecute shell command"
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)Generate [(ansi bo)C(ansi reset)]ode"
  print $"(ansi bo)(ansi cyan)s(ansi bl) ⟶ (ansi reset)Resume from a [(ansi bo)S(ansi reset)]ession"
  print $"(ansi bo)(ansi cyan)r(ansi bl) ⟶ (ansi reset)Start a [(ansi bo)R(ansi reset)]AG"
  print $"(ansi bo)(ansi cyan)m(ansi bl) ⟶ (ansi reset)Start a [(ansi bo)M(ansi reset)]acro"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  mut result = ''
  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['a', []] => { main; break }
      ['e', []] => { execute; break }
      ['c', []] => { code; break }
      ['s', []] => { session; break }
      ['r', []] => { rag; break }
      ['m', []] => { macro; break }
      ['q', []] => { break }
      ['c', [keymodifiers(control)]] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }

  $result
}

def "select role" [] {
  let role = (^aichat --list-roles | fzf --header "Roles" | str trim)
  if ($role | is-not-empty) {
    ["--role", $role]
  } else {
    []
  }
}

def "select model" [] {
  let model = (^aichat --list-models | fzf --header "Models" | str trim)
  if ($model | is-not-empty) {
    ["--model", $model]
  } else {
    []
  }
}

export def main --wrapped [...rest] {
  let no_args = ($rest | is-empty)
  let single_plain_arg = (($rest | length) == 1 and not ($rest | first | str starts-with "-"))

  if $no_args or $single_plain_arg {
    let prompt_args = (select model) ++ (select role)
    if $no_args {
      ^aichat --session ...$prompt_args
    } else {
      ^aichat ...$prompt_args ...$rest
    }
  } else {
    ^aichat ...$rest
  }
}

# Execute a shell command
export def execute --wrapped [...rest] {
  ^aichat --session --execute ...$rest
}

# Generate some code
export def code --wrapped [...rest] {
  ^aichat --session --code ...$rest
}

# Resume from a interactively selected session
export def session --wrapped [...rest] {
  let session = (^aichat --list-sessions | ^fzf --header "Sessions" | str trim)
  ^aichat --session $session ...$rest
}

# Start a RAG
export def rag [...rest] {
  let rag = (^aichat --list-rags | fzf --header "RAGs" | str trim)
  ^aichat --rag $rag ...$rest
}

# Start a macro
export def macro --wrapped [...rest] {
  let macro = (^aichat --list-macros | fzf --header "Macros" | str trim)
  ^aichat --macro $macro ...$rest
}
