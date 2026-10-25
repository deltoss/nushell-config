use ../tools/leader-tree.nu [run-menu]
use ../tools/tui.nu [tui-picker]
use ../tools/git-preview.nu [changed-files file-preview]

# Bring up interactive menu for AI operations
export def menu [] { run-menu (menu-items) }

def "select role" [] {
  let selected = (^aichat --list-roles | lines | each {|value| {value: $value} }
    | tui-picker "AI roles" [value])
  if ($selected | is-empty) { [] } else { ["--role", $selected.value] }
}

def "select model" [] {
  let selected = (^aichat --list-models | lines | each {|value| {value: $value} }
    | tui-picker "AI models" [value])
  if ($selected | is-empty) { [] } else { ["--model", $selected.value] }
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
  let selected = (^aichat --list-sessions | lines | each {|value| {value: $value} }
    | tui-picker "AI sessions" [value])
  if ($selected | is-empty) { return }
  ^aichat --session $selected.value ...$rest
}

# Start a RAG
export def rag [...rest] {
  let selected = (^aichat --list-rags | lines | each {|value| {value: $value} }
    | tui-picker "AI RAGs" [value])
  if ($selected | is-empty) { return }
  ^aichat --rag $selected.value ...$rest
}

# Start a macro
export def macro --wrapped [...rest] {
  let selected = (^aichat --list-macros | lines | each {|value| {value: $value} }
    | tui-picker "AI macros" [value])
  if ($selected | is-empty) { return }
  ^aichat --macro $selected.value ...$rest
}

def "select changed files" [] {
  changed-files
  | tui-picker "Select changed files" [status path] --multi --preview {|row| file-preview $row }
  | each {|row| $row.path }
}

# Suggests a git commit message
export def "suggest commit" [
  --session: string = ""
] {
  let session_name = $session | default --empty $"code-suggest-commit-message-(date now | format date '%Y-%m-%d-%H%M')"

  print $"Session name: ($session_name)"

  let initial_prompt = "I will give you the git diffs, then I will ask you to generate me a short, concise & relevant commit message."
  ^aichat -s $session_name $initial_prompt

  let selected_files = select changed files

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

  let selected_files = select changed files

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

# Download a model file into the local model directory.
@example "grab the turbo model for whisper.cpp" { ai get-model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin }
@example "a small English-only model for quick tests" { ai get-model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin }
@example "a GGUF model for llama.cpp" { ai get-model https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf }
@example "store it somewhere other than ~/models" { ai get-model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin --dir D:/models }
export def get-model [
  url: string
  --dir: string = "~/models"
] {
  let model_dir = ($dir | path expand)
  mkdir $model_dir

  let filename = ($url | url parse | get path | path basename)
  let dest = ($model_dir | path join $filename)

  if ($dest | path exists) {
    print $"already have ($filename)"
    return $dest
  }

  http get $url | save --progress $dest
  $dest
}

export def menu-items [] {
  [
    {key: a, label: "[A]I", action: {|| main}}
    {key: e, label: "[E]xecute shell command", action: {|| execute}}
    {key: c, label: "Generate [C]ode", action: {|| code}}
    {key: s, label: "Resume from existing [S]ession", action: {|| session}}
    {key: r, label: "Start a [R]AG", action: {|| rag}}
    {key: m, label: "Start a [M]acro", action: {|| macro}}
    {key: C, label: "Suggest a [C]ommit message", action: {|| suggest commit}}
    {key: d, label: "Review codebase [D]iffs", action: {|| review diffs}}
    {key: S, label: "Review codebase [S]tructure", action: {|| review structure}}
  ]
}
