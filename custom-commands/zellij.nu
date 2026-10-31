use ../tools/leader-tree.nu [run-menu]
# Open the Zellij pane and tab menu.
@example "Choose a Zellij action" { zellij menu }
export def menu [] { run-menu (menu-items) }

def "new pane" [] {
  ^zellij action new-pane --cwd $env.PWD --direction right --name '' -- nu | ignore
}

def "new float" [] {
  ^zellij action new-pane --cwd $env.PWD --floating --pinned true --name '' -- nu | ignore
}

def "new stack" [] {
  ^zellij action new-pane --cwd $env.PWD --stacked --name '' -- nu | ignore
}

def "new tab" [] {
  ^zellij action new-tab --cwd $env.PWD | ignore
}

# Return Zellij menu entries for composition.
@example "Inspect the menu labels" { zellij menu-items | get label }
export def menu-items [] {
  [
    {key: n, label: "[N]ew Pane", action: {|| new pane}}
    {key: p, label: "New [P]ane", action: {|| new pane}}
    {key: s, label: "New [S]tack", action: {|| new stack}}
    {key: f, label: "New [F]loat", action: {|| new float}}
    {key: t, label: "New [T]ab", action: {|| new tab}}
  ]
}