$env.config.menus ++= [{
  name: help_menu
  only_buffer_difference: false # Search is done on the text written before activating the menu
  marker: "? "                 # Indicator that appears with the menu is active
  type: {
    layout: description      # Type of menu
    columns: 4               # Number of columns where the options are displayed
    col_width: 20            # Optional value. If missing all the screen width is used to calculate column width
    col_padding: 2           # Padding between columns
    selection_rows: 4        # Number of rows allowed to display found options
    description_rows: 10     # Number of rows allowed to display command description
  }
  style: {
    text: green                   # Text style
    selected_text: green_reverse  # Text style for selected option
    description_text: yellow      # Text style for description
  }
}]

$env.config.keybindings ++= [{
  name: help_menu
  modifier: control
  keycode: char_p
  mode: [emacs vi_insert vi_normal]
  event: { send: menu name: help_menu }
}
{
  name: ai_menu
  modifier: CONTROL
  keycode: Char_a
  mode: [emacs vi_insert vi_normal]
  event: [
    {
      send: executehostcommand,
      cmd: "print ''; ai menu"
    }
  ]
}
{
  name: git_menu
  modifier: CONTROL
  keycode: Char_g
  mode: [emacs vi_insert vi_normal]
  event: [
    {
      send: executehostcommand,
      cmd: "print ''; git menu"
    }
  ]
}
{
  name: kill__menu
  modifier: CONTROL
  keycode: Char_k
  mode: [emacs vi_insert vi_normal]
  event: [
    {
      send: executehostcommand,
      cmd: "print ''; kill menu"
    }
  ]
}]
