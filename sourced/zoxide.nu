def --env z [...args] {
  let query = ($args | str join " ")
  if ($query == "~") {
    cd "~"
    return
  }

  let result = zoxide query ...$args | complete

  if ($result.exit_code != 0) {
    cd ($query | search everything)
  } else {
    cd ($result.stdout | str trim)
  }
}
