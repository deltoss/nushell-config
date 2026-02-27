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

export def "suggest commit" [
  --session: string = ""
] {
  let session_name = if $session == "" {
    $"code-suggest-commit-message-(date now | format date '%Y-%m-%d-%H%M')"
  } else {
    $session
  }

  print $"Session name: ($session_name)"

  let initial_prompt = "I will give you the git diffs, then I will ask you to generate me a short, concise & relevant commit message."
  ^aichat -s $session_name $initial_prompt

  let selected_files = (
    ^git status --porcelain
    | fzf -m --header "Select multiple with [TAB] and [SHIFT-TAB]"
    | lines
    | str substring 3.. # Extract filename by removing the first 3 characters (status code + space)
  )

  if ($selected_files | is-empty) {
    print "No selection made..."
    return
  }

  let diff_prompt = (
    $selected_files
    | each {|file|
        let diff = (^git --no-pager diff --word-diff=porcelain --no-color --no-ext-diff HEAD -- $file)
        $"Here's the git diff for the file '($file)':\n($diff)"
      }
    | str join "\n"
  )

  let final_prompt = $"($diff_prompt)\n\n... Now give me the final commit message. Make it short and sweet, with at most 80 characters for the main message, and at most a few lines for the description."

  ^aichat --session $session_name $final_prompt
}
