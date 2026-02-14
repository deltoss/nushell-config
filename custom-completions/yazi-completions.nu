# Obtained from the zips in: https://github.com/sxyazi/yazi/releases
module completions {

  export extern yazi [
    --cwd-file: path          # Write the cwd on exit to this file
    --chooser-file: path      # Write the selected files to this file on open fired
    --clear-cache             # Clear the cache directory
    --client-id: string       # Use the specified client ID, must be a globally unique number
    --local-events: string    # Report the specified local events to stdout
    --remote-events: string   # Report the specified remote events to stdout
    --debug                   # Print debug information
    --version(-V)             # Print version
    --help(-h)                # Print help
    ...entries: string        # Set the current working entry
  ]

}

export use completions *
