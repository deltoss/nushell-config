use ./bitbucket.nu

def layout-path [path: string] {
  $path | str replace --all '\' '/' | to json --raw
}

# Browse up to 20 tickets and 20 authored PRs in side-by-side Zellij panes.
# Opens a new tab inside Zellij, or starts a session outside it.
# Alt+Arrow moves between panes with the current Zellij configuration.
@example "Choose a workspace and open the dashboard" {
  dashboard
}
@example "Open the dashboard for one Bitbucket workspace" {
  dashboard --workspace my-team
}
export def main [
  --workspace: string # Workspace slug; choose interactively when omitted
] {
  if (which zellij | is-empty) {
    error make {msg: "zellij is required to open the dashboard"}
  }
  let workspace = $workspace | default --empty { bitbucket select workspace | get --optional slug }
  if ($workspace | is-empty) { return }

  const commands_dir = path self .
  let ticket_module = $commands_dir | path join ticket.nu | str replace --all '\' '/'
  let pr_module = $commands_dir | path join pr.nu | str replace --all '\' '/'
  let ticket_command = $"use ($ticket_module | to nuon); ticket tui"
  let pr_command = $"use ($pr_module | to nuon); pr tui --workspace ($workspace | to nuon)"
  let executable = layout-path $nu.current-exe
  let cwd = layout-path $env.PWD
  # nu -c skips user startup files unless they are explicitly supplied.
  let env_config = layout-path $nu.env-path
  let config = layout-path $nu.config-path
  let layout = $'layout {
  tab name="Dashboard" cwd=($cwd) {
    pane size=1 borderless=true {
      plugin location="tab-bar"
    }
    pane split_direction="vertical" {
      pane name="Tickets" command=($executable) close_on_exit=false {
        args "--env-config" ($env_config) "--config" ($config) "-c" ($ticket_command | to json --raw)
      }
      pane name="Pull requests" command=($executable) close_on_exit=false {
        args "--env-config" ($env_config) "--config" ($config) "-c" ($pr_command | to json --raw)
      }
    }
    pane size=1 borderless=true {
      plugin location="status-bar"
    }
  }
}'
  ^zellij --layout-string $layout
}