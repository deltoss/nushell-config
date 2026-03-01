# Bring up interactive menu for AI operations
export def menu [] {
  print $"(ansi bo)(ansi cyan)a(ansi bl) ⟶ (ansi reset)[(ansi bo)A(ansi reset)]I"
  print $"(ansi bo)(ansi cyan)e(ansi bl) ⟶ (ansi reset)[(ansi bo)E(ansi reset)]xecute shell command"
  print $"(ansi bo)(ansi cyan)c(ansi bl) ⟶ (ansi reset)Generate [(ansi bo)C(ansi reset)]ode"
  print $"(ansi bo)(ansi cyan)s(ansi bl) ⟶ (ansi reset)Resume from existing [(ansi bo)S(ansi reset)]ession"
  print $"(ansi bo)(ansi cyan)r(ansi bl) ⟶ (ansi reset)Start a [(ansi bo)R(ansi reset)]AG"
  print $"(ansi bo)(ansi cyan)m(ansi bl) ⟶ (ansi reset)Start a [(ansi bo)M(ansi reset)]acro"
  print $"(ansi bo)(ansi cyan)C(ansi bl) ⟶ (ansi reset)Suggest a [(ansi bo)C(ansi reset)]ommit message"
  print $"(ansi bo)(ansi cyan)d(ansi bl) ⟶ (ansi reset)Review codebase [(ansi bo)D(ansi reset)]iffs"
  print $"(ansi bo)(ansi cyan)S(ansi bl) ⟶ (ansi reset)Review codebase [(ansi bo)S(ansi reset)]tructure"
  print $"(ansi bo)(ansi cyan)q(ansi bl) ⟶ (ansi reset)[(ansi bo)Q(ansi reset)]uit"

  loop {
    let key = (input listen --types [key])
    match [$key.code $key.modifiers] {
      ['a', []] => { main; break }
      ['e', []] => { execute; break }
      ['c', []] => { code; break }
      ['s', []] => { session; break }
      ['r', []] => { rag; break }
      ['m', []] => { macro; break }
      ['C', ['keymodifiers(shift)']] => { suggest commit; break }
      ['d', []] => { review diffs; break }
      ['S', []] => { review structure; break }
      ['q', []] => { break }
      ['esc', []] => { break }
      ['c', ['keymodifiers(control)']] => { print 'Terminated with Ctrl-C'; break }
      _ => {
        print "That key wasn't recognized."
      }
    }
  }
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

# Suggests a git commit message
export def "suggest commit" [
  --session: string = ""
] {
  let session_name = $session | default --empty $"code-suggest-commit-message-(date now | format date '%Y-%m-%d-%H%M')"

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

# Review your code structure
export def "review structure" [] {
  ^eza --recurse --tree --git-ignore | ^aichat --session "Analyze this project structure and suggest improvements in the context of software development."
}

# Review your git changes
export def "review diffs" [
  --session: string = ""
] {
  let session_name = $session | default --empty $"code-review-(date now | format date '%Y-%m-%d-%H%M')"

  print $"Session name: ($session_name)"

  let initial_prompt = "I will give you code files, and the git diffs. You are an experienced developer with 10 years of reviewing pull requests. I want you to review the code change in the context of the full file. Consider:
    1. Does the change make sense given the overall file structure?
    2. Are there any potential issues or improvements?
    3. Does it follow best practices for the given language?"

  ^aichat -s $session_name $initial_prompt

  let selected_files = (
    ^git status --porcelain
    | fzf -m --header "Select multiple with [TAB] and [SHIFT-TAB]"
    | lines
    | str substring 3..
  )

  if ($selected_files | is-empty) {
    print "No selection made..."
    return
  }

  for $file in $selected_files {
    let diff = (^git --no-pager diff --no-color --no-ext-diff HEAD -- $file)
    let prompt = $"Here's the git diff for this file. Please review and provide any feedback:\n($diff)"
    ^aichat --session $session_name --file $file $prompt
  }
}
