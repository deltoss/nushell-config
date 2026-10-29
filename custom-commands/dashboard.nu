use ./ticket.nu
use ./pr.nu

# Browse tickets and pull requests in separate tabs.
# Press 1/2 or the bracket keys to switch tabs. Each tab keeps its own search and selection.
@example "Open the dashboard" {
  dashboard
}
@example "Limit pull requests to one Bitbucket workspace" {
  dashboard --workspace my-team
}
export def main [
  --workspace: string # Limit pull requests to one workspace
  --all # Bypass saved ticket filters and include closed pull requests
] {
  ticket widget --all=$all
  | pr widget --workspace $workspace --all=$all
  | tui label --titlebar "Dashboard"
  | tui label --status "1/2: tabs  Space: select  y: copy keys  Y: copy URLs  b: browse  /: search  q: quit"
  | tui run
  | ignore
}