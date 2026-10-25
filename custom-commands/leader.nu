use ./search.nu
use ./ai.nu
use ./git.nu
use ./kill.nu
use ./zellij.nu
use ./worktree.nu
use ./quick-launch.nu
use ./pr.nu
use ../tools/leader-tree.nu [run-menu]

export def menu-items [] {
  let git_items = (git menu-items | each {|item|
    match $item.key {
      w => ($item | upsert children (worktree menu-items))
      p => ($item | merge {action: {|| pr}})
      _ => $item
    }
  })
  [
    {key: s, label: "[S]earch", children: (search menu-items)}
    {key: a, label: "[A]I", children: (ai menu-items)}
    {key: g, label: "[G]it", children: $git_items}
    {key: k, label: "[K]ill", action: {|| kill menu}}
    {key: l, label: "Quick [L]aunch", children: (quick-launch menu-items)}
    {key: z, label: "[Z]ellij", children: (zellij menu-items)}
  ]
}

export def --env menu [] { run-menu (menu-items) }
