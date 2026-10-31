use ../tools/tui.nu [tui-picker]

# Create a .NET project from an interactively selected template.
@example "Choose a project template and location" { dotnet new }
export def --wrapped new [...rest] {
  new menu ...$rest
}

# Choose a .NET project template and create the project.
@example "Open the template picker" { dotnet new menu }
export def --wrapped "new menu" [
  ...rest
] {
  if "--help" in $rest {
    ^dotnet new ...$rest
    return
  }

  let result = (^dotnet new list --type project | complete)

  if $result.exit_code != 0 {
    print $"(ansi red)Failed to get template list(ansi reset)"
    return
  }

  let templates_list = (
    $result.stdout
    | lines
    | skip until { |line| $line =~ '^-{3,}' }
    | skip 1
    | where { |line| $line | str trim | is-not-empty }
    | parse -r '(?P<name>.+?)\s{2,}(?P<short>\S+)\s{2,}(?P<lang>.+?)\s{2,}(?P<tags>.+?)\s*$'
    | par-each { |row|
      {
        name: ($row.name | str trim)
        short_name: ($row.short | str trim)
        language: ($row.lang | str trim)
        tags: ($row.tags | str trim)
      }
    }
  )

  if ($templates_list | is-empty) {
    print $"(ansi yellow)No project templates found(ansi reset)"
    return
  }

  let selected = $templates_list | tui-picker "Select project template" [name short_name language tags]
  if ($selected | is-empty) { return }

  let selected_name = $selected.short_name | split row "," | first

  let project_name = (input "Project name: " | str trim)
  if ($project_name | is-empty) { return }

  let directory = (input "Directory (leave empty for current): " | str trim)

  if ($directory | is-empty) {
    ^dotnet new ($selected_name) --name $project_name ...$rest
  } else {
    ^dotnet new ($selected_name) --name $project_name --output $directory ...$rest
  }
}