def instance-ids [run: closure] {
  do $run [instance list --output json] | from json | get instances
    | each {|it| {value: $it.id, description: $"($it.main_ip) - ($it.os)"} }
}

def snapshot-ids [run: closure] {
  do $run [snapshot list --output json] | from json | get snapshots
    | each {|it| {value: $it.id, description: $"($it.description) - ($it.date_created)"} }
}

# The caller supplies its authenticated wrapper, avoiding a circular module import.
export def complete-vultr-cli [token: record, place: record, run: closure] {
  let value_flags = [--config --output --id -i --description -d]
  mut path = []
  mut flag = ''
  for word in ($place.command | skip 1 | drop) {
    if $flag != '' {
      $flag = ''
    } else if $word in $value_flags {
      $flag = $word
    } else if not ($word | str starts-with '-') {
      $path = ($path | append $word)
    }
  }

  let inline_flag = $token.text | parse --regex '^(?P<flag>--[^=]+|-[id])=' | get --optional flag.0
  if $inline_flag != null { $flag = $inline_flag }

  let choices = if $flag != '' {
    match $flag {
      --output => [text json yaml]
      --id | -i if $path == [snapshot create] => (instance-ids $run)
      _ => { return null }
    }
  } else if ($token.text | str starts-with '-') {
    [
      {value: --config, description: 'Path to config file'}
      {value: --help, description: 'Show help'}
      {value: -h, description: 'Show help'}
      {value: --output, description: 'Output format: text, json, yaml'}
      ...(if $path == [snapshot create] {
        [
          {value: --id, description: 'ID of the instance'}
          {value: -i, description: 'ID of the instance'}
          {value: --description, description: 'Description of the snapshot'}
          {value: -d, description: 'Description of the snapshot'}
        ]
      } else { [] })
    ]
  } else {
    match $path {
      [instance delete] | [instance destroy] => (instance-ids $run)
      [snapshot get] | [snapshot delete] => (snapshot-ids $run)
      _ => {
        do $run [...$path --help] | lines
          | parse --regex '^ {2}(?P<value>[\w-]+)\*?\s+(?P<description>.+)$'
          | where value != vultr-cli
      }
    }
  }

  let completions = $choices | each {|choice|
    let suggestion = if ($choice | describe) == string { {value: $choice} } else { $choice }
    if $inline_flag != null {
      $suggestion | update value {|it| $"($inline_flag)=($it.value)"}
    } else {
      $suggestion
    }
  }

  # Nu 0.116 gives @complete an empty matching prefix. Use its external matcher
  # with the actual token. This buffer is completed, never executed.
  $env.config.completions.external = {
    enable: true
    max_results: ($completions | length)
    completer: {|place| {completions: $completions, options: {filter: true}}}
  }
  $"__nu_vultr_complete__ ($token.text)"
    | commandline complete --detailed
    | update span $token.span
}