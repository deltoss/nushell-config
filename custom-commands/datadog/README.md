# Datadog

Nushell workflows for browsing monitors and logs, with repository-based service selection.
Authenticate with `pup auth login`. Use command `--help` for usage and TUI keys.

| Module | Purpose |
| --- | --- |
| `mod.nu` | Public commands, help and defaults |
| `client.nu` | Shared Pup execution |
| `logs.nu` | Log TUI and state |
| `monitors.nu` | Monitor TUI and paging |
| `projects.nu` | Service rules, matching and persistence |
| `hints.nu` | Hint-management TUI |
| `pi.nu` | Pi investigation and stacked-pane handoff |

- **Local state** ⟶ Service hints live in `$nu.data-dir/datadog/project-services.json`,
  keyed by Git origin so worktrees and clones share them.
- **Pi privacy** ⟶ Investigations send unredacted logs to your configured model provider.
  Deleting temporary files does not remove records from saved sessions or provider storage.
- **No read-only guarantee** ⟶ Pi is asked not to make changes, but its normal tools remain enabled.