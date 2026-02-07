export def main --wrapped [...rest] {
    let filtered_args = if ('--port' in $rest) {
        $rest
    } else {
        $rest | append ['--port', $env.OPENCODE_PORT]
    }

    ^opencode.exe ...$filtered_args
}
