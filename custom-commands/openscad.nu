# OpenSCAD preview via WezTerm imgcat

const VIEWS = {
  iso:    "0,0,0,55,0,25,0"
  front:  "0,0,0,90,0,0,0"
  back:   "0,0,0,90,0,180,0"
  right:  "0,0,0,90,0,90,0"
  left:   "0,0,0,90,0,270,0"
  top:    "0,0,0,0,0,0,0"
  bottom: "0,0,0,180,0,0,0"
}

def tmp [name: string] {
  $nu.temp-path | path join $"scad-($name).png"
}

# Render one or more angles, return the image path
export def render [
  file: path
  --views (-v): list<string> = [iso front top]
  --size (-s): int = 700
  --colorscheme (-c): string = "Tomorrow Night"
] {
  for v in $views {
    if not ($v in ($VIEWS | columns)) {
      error make {msg: $"unknown view '($v)', pick from: ($VIEWS | columns | str join ', ')"}
    }
  }

  let shots = $views | enumerate | par-each {|it|
    let out = tmp $it.item
    let r = (^openscad
      -o $out
      --imgsize $"($size),($size)"
      --camera ($VIEWS | get $it.item)
      --colorscheme $colorscheme
      --viewall --autocenter
      $file | complete)
    if $r.exit_code != 0 { error make {msg: $r.stderr} }
    {i: $it.index, path: $out}
  } | sort-by i | get path

  if ($shots | length) == 1 { return ($shots | first) }

  if (which magick | is-empty) { return ($shots | first) }

  let sheet = tmp "sheet"
  ^magick montage ...$shots -tile $"($shots | length)x1" -geometry +2+2 $sheet
  $sheet
}

# Render and show once
export def view [
  file: path
  --views (-v): list<string> = [iso front top]
  --size (-s): int = 700
] {
  ^wezterm imgcat --height 90% (render $file --views $views --size $size)
}

# Re-render on every save
export def watch-file [
  file: path
  --views (-v): list<string> = [iso front top]
  --size (-s): int = 700
] {
  let full = ($file | path expand)
  view $full --views $views --size $size

  watch ($full | path dirname) --glob ($full | path basename) --debounce 150ms {|op path|
    clear
    try {
      ^wezterm imgcat --height 90% (render $full --views $views --size $size)
    } catch {|e|
      print $"(ansi red)($e.msg)(ansi reset)"
    }
  }
}