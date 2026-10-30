use ./bitbucket.nu

# Browse tickets and authored pull requests in side-by-side Zellij panes.
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
  --all # Bypass saved ticket filters and include closed pull requests
] {
  if (which zellij | is-empty) {
    error make {msg: "zellij is required to open the dashboard"}
  }
  let workspace = $workspace | default --empty { bitbucket select workspace | get --optional slug }
  if ($workspace | is-empty) { return }

  let ticket_module = $nu.default-config-dir | path join custom-commands ticket.nu | str replace --all '\' '/'
  let pr_module = $nu.default-config-dir | path join custom-commands pr.nu | str replace --all '\' '/'
  let ticket_command = $"use ($ticket_module | to nuon); ticket tui --all=($all)"
  let pr_command = $"use ($pr_module | to nuon); pr tui --workspace ($workspace | to nuon) --all=($all)"
  let executable = $nu.current-exe | str replace --all '\' '/' | to json --raw
  let cwd = $env.PWD | str replace --all '\' '/' | to json --raw
  # nu -c skips user startup files unless they are explicitly supplied.
  let env_config = $nu.env-path | str replace --all '\' '/' | to json --raw
  let config = $nu.config-path | str replace --all '\' '/' | to json --raw
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