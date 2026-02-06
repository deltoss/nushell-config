export def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	^yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != $env.PWD and ($cwd | path exists) {
		cd $cwd
	}
	rm -fp $tmp
}

export def yp [...args] {
  let tmp = (mktemp)
  ^yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp)
	rm -fp $tmp
  if ($cwd | is-empty) and ($cwd | path exists) {
    null
  } else {
    $cwd | path expand
  }
}
