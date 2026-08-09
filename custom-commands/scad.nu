# OpenSCAD preview via WezTerm imgcat.
#
# `watch` below shadows the builtin inside this module, so grab a handle
# to it first. Must stay above the definition: aliases resolve at their
# textual position, unlike `def`.
alias fs-watch = watch

const VIEWS = {
  iso:    "0,0,0,55,0,25,0"
  front:  "0,0,0,90,0,0,0"
  back:   "0,0,0,90,0,180,0"
  right:  "0,0,0,90,0,90,0"
  left:   "0,0,0,90,0,270,0"
  top:    "0,0,0,0,0,0,0"
  bottom: "0,0,0,180,0,0,0"
}

def "nu-complete views" []: nothing -> list<string> { $VIEWS | columns }

def shot [name: string]: nothing -> path {
  $nu.temp-dir | path join $"scad-($name).png"
}

# Render a .scad file to PNG and return the image path.
#
# With multiple views, stitches them into one contact sheet if
# ImageMagick is installed, otherwise returns the first view.
@example "Default three-up sheet" { scad render part.scad }
@example "Single angle, high res" { scad render part.scad -v [iso] -s 1400 }
@example "Every side, for a print check" {
  scad render part.scad -v [front back left right top bottom]
}
@example "Pipe straight into imgcat" {
  scad render part.scad | wezterm imgcat --height 90% $in
}
@search-terms openscad render png contact-sheet
export def render [
  file: path                                                        # .scad file to render
  --views (-v): list<string>@"nu-complete views" = [iso front top]  # angles to render
  --size (-s): int = 700                                            # pixel size per view
  --colorscheme (-c): string = "Tomorrow Night"                     # OpenSCAD colorscheme
]: nothing -> path {
  let bad = $views | where {|v| $v not-in ($VIEWS | columns)}
  if not ($bad | is-empty) {
    error make {msg: $"unknown views: ($bad | str join ', '). try: ($VIEWS | columns | str join ', ')"}
  }

  $views | par-each {|v|
    let r = (^openscad
      -o (shot $v)
      --imgsize $"($size),($size)"
      --camera ($VIEWS | get $v)
      --colorscheme $colorscheme
      --viewall --autocenter
      ($file | path expand) | complete)
    if $r.exit_code != 0 { error make {msg: $r.stderr} }
  }

  let shots = $views | each {|v| shot $v}
  if ($shots | length) == 1 or (which magick | is-empty) {
    return ($shots | first)
  }

  let sheet = shot "sheet"
  ^magick montage ...$shots -tile $"($shots | length)x1" -geometry +2+2 $sheet
  $sheet
}

# Render a .scad file and print it in the terminal once.
@example "Quick look" { scad view part.scad }
@example "Just the isometric, bigger" { scad view part.scad -v [iso] -s 1200 }
@example "Check the underside" { scad view part.scad -v [bottom] }
@search-terms openscad preview imgcat show
export def view [
  file: path
  --views (-v): list<string>@"nu-complete views" = [iso front top]
  --size (-s): int = 700
]: nothing -> nothing {
  ^wezterm imgcat --height 90% (render $file --views $views --size $size)
}

# Re-render a .scad file on every save. Runs until Ctrl-C.
#
# Syntax errors print in red and leave the last good image up.
@example "Park this in a pane next to your terminal editor" { scad watch part.scad }
@example "One big view while dialing in a fillet" {
  scad watch part.scad -v [iso] -s 1400
}
@search-terms openscad watch live reload auto
export def watch [
  file: path
  --views (-v): list<string>@"nu-complete views" = [iso front top]
  --size (-s): int = 700
]: nothing -> nothing {
  let full = $file | path expand
  let show = {||
    clear
    try { view $full --views $views --size $size } catch {|e|
      print $"(ansi red)($e.msg)(ansi reset)"
    }
  }

  do $show
  for _ in (fs-watch ($full | path dirname) --glob ($full | path basename) --debounce 150ms --quiet) { do $show }
}