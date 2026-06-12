# Empty completer to disable file completion on args
def "nu-complete none" [] { [] }

# Browse a URL with the Carbonyl terminal browser (runs in podman)
@example "Browse YouTube" { web https://youtube.com }
export def --wrapped url [url: string@"nu-complete none", ...rest: string@"nu-complete none"]: nothing -> nothing {
  ^podman run --rm -ti fathyb/carbonyl ...$rest $url
}

# Search in the Carbonyl terminal browser
@example "Search for nushell" { web search nushell custom commands }
export def --wrapped main [...rest: string@"nu-complete none"]: nothing -> nothing {
  let flags = $rest | where {|it| $it | str starts-with '-' }
  let query = $rest | where {|it| not ($it | str starts-with '-') }
  let encoded = $query | str join ' ' | url encode
  url $"https://www.startpage.com/sp/search?query=($encoded)" ...$flags
}