# Static enum completers

def "nu-complete serena log-level" [] {
  [DEBUG, INFO, WARNING, ERROR, CRITICAL]
}

def "nu-complete serena language-backend" [] {
  [LSP, JetBrains]
}

def "nu-complete serena transport" [] {
  [stdio, sse, streamable-http]
}

def "nu-complete serena setup-client" [] {
  [claude-code, codex]
}


# Dynamic completers

def "nu-complete serena contexts" [] {
  ^serena context list
    | lines
    | where $it != ''
    | each {|line| $line | parse --regex '^\s*(?P<value>\S+)\s+\((?P<description>[^)]+)\)' }
    | flatten
}

def "nu-complete serena modes" [] {
  ^serena mode list
    | lines
    | where $it != ''
    | each {|line| $line | parse --regex '^\s*(?P<value>\S+)\s+\((?P<description>[^)]+)\)' }
    | flatten
}

def "nu-complete serena tools" [] {
  ^serena tools list -q | lines | where $it != '' | each {|it| $it | str trim }
}

def "nu-complete serena prompt-names" [] {
  ^serena prompts list
    | lines
    | where $it =~ "^ \\* '"
    | parse --regex "^ \\* '(?P<value>[^']+)'"
    | get value
}

def "nu-complete serena prompt-yaml-files" [] {
  ^serena prompts list
    | lines
    | where $it =~ "^ \\* "
    | where $it !~ "\\("
    | parse --regex "^ \\* (?P<value>\\S+)"
    | get value
}

def "nu-complete serena prompt-overrides" [] {
  ^serena prompts list-overrides
    | lines
    | where $it != ''
    | each {|it| $it | str trim }
}

# Empty completer to suppress path fallback on parent commands
def "nu-complete none" [] { [] }


# Main serena CLI commands
export extern "serena" [
  _?: string@"nu-complete none"
  --version (-V)                                                              #Show the version and exit
  --help                                                                      #Show this message and exit
]


# Manage Serena configuration
export extern "serena config" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Edit serena_config.yml in your default editor
export extern "serena config edit" [
  --help                                                                      #Show this message and exit
]


# Manage Serena contexts
export extern "serena context" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Create a new context or copy an internal one
export extern "serena context create" [
  --name (-n): string                                                         #Name for the new context
  --from-internal: string@"nu-complete serena contexts"                       #Copy from an internal context
  --help                                                                      #Show this message and exit
]

# Delete a custom context file
export extern "serena context delete" [
  context_name: string@"nu-complete serena contexts"                          #Context to delete
  --help                                                                      #Show this message and exit
]

# Edit a custom context YAML file
export extern "serena context edit" [
  context_name: string@"nu-complete serena contexts"                          #Context to edit
  --help                                                                      #Show this message and exit
]

# List available contexts
export extern "serena context list" [
  --help                                                                      #Show this message and exit
]


# Manage Serena modes
export extern "serena mode" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Create a new mode or copy an internal one
export extern "serena mode create" [
  --name (-n): string                                                         #Name for the new mode
  --from-internal: string@"nu-complete serena modes"                          #Copy from an internal mode
  --help                                                                      #Show this message and exit
]

# Delete a custom mode file
export extern "serena mode delete" [
  mode_name: string@"nu-complete serena modes"                                #Mode to delete
  --help                                                                      #Show this message and exit
]

# Edit a custom mode YAML file
export extern "serena mode edit" [
  mode_name: string@"nu-complete serena modes"                                #Mode to edit
  --help                                                                      #Show this message and exit
]

# List available modes
export extern "serena mode list" [
  --help                                                                      #Show this message and exit
]


# Manage Serena projects
export extern "serena project" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Create a new Serena project configuration
export extern "serena project create" [
  project_path?: path                                                         #Path to the project
  --name: string                                                              #Project name
  --language: string                                                          #Programming language(s)
  --index                                                                     #Index the project after creation
  --log-level: string@"nu-complete serena log-level"                          #Log level for indexing
  --timeout: float                                                            #Timeout for indexing a single file
  --help                                                                      #Show this message and exit
]

# Perform a comprehensive health check of the project's tools and language server
export extern "serena project health-check" [
  project?: string                                                            #Project name or path
  --help                                                                      #Show this message and exit
]

# Index a project by saving symbols to the LSP cache
export extern "serena project index" [
  project?: string                                                            #Project name or path
  --name: string                                                              #Project name (for auto-creating)
  --language: string                                                          #Programming language(s)
  --log-level: string@"nu-complete serena log-level"                          #Log level for indexing
  --timeout: float                                                            #Timeout for indexing a single file
  --help                                                                      #Show this message and exit
]

# Index a single file by saving its symbols to the LSP cache
export extern "serena project index-file" [
  file: path                                                                  #File to index
  project?: string                                                            #Project name or path
  --verbose (-v)                                                              #Print detailed symbol info
  --help                                                                      #Show this message and exit
]

# Check if a path is ignored by the project configuration
export extern "serena project is_ignored_path" [
  path: path                                                                  #Path to check
  project?: string                                                            #Project name or path
  --help                                                                      #Show this message and exit
]


# Commands related to Serena's prompts
export extern "serena prompts" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Create an override of an internal prompts yaml
export extern "serena prompts create-override" [
  prompt_yaml_name: string@"nu-complete serena prompt-yaml-files"             #Prompt YAML file to override
  --help                                                                      #Show this message and exit
]

# Delete a prompt override file
export extern "serena prompts delete-override" [
  prompt_yaml_name: string@"nu-complete serena prompt-overrides"              #Prompt override to delete
  --help                                                                      #Show this message and exit
]

# Edit an existing prompt override file
export extern "serena prompts edit-override" [
  prompt_yaml_name: string@"nu-complete serena prompt-overrides"              #Prompt override to edit
  --help                                                                      #Show this message and exit
]

# Lists prompt names and YAML files that can be overridden
export extern "serena prompts list" [
  --help                                                                      #Show this message and exit
]

# List existing prompt override files
export extern "serena prompts list-overrides" [
  --help                                                                      #Show this message and exit
]

# Print the Claude Code system prompt override
export extern "serena prompts print-cc-system-prompt-override" [
  --help                                                                      #Show this message and exit
]

# Print the (unrendered) template for the given prompt name
export extern "serena prompts print-prompt-template" [
  prompt_name: string@"nu-complete serena prompt-names"                       #Prompt name to print
  --help                                                                      #Show this message and exit
]


# Commands related to Serena's tools
export extern "serena tools" [
  _?: string@"nu-complete none"
  --help                                                                      #Show this message and exit
]

# Print the description of a tool
export extern "serena tools description" [
  tool_name: string@"nu-complete serena tools"                                #Tool to describe
  --context: string@"nu-complete serena contexts"                             #Context name or path
  --help                                                                      #Show this message and exit
]

# Print an overview of tools active by default
export extern "serena tools list" [
  --quiet (-q)                                                                #Quiet output
  --all (-a)                                                                  #List all tools
  --only-optional                                                             #List only optional tools
  --help                                                                      #Show this message and exit
]


# Initialize Serena by creating a global config file
export extern "serena init" [
  --language-backend (-b): string@"nu-complete serena language-backend"       #Default code intelligence backend
  --help                                                                      #Show this message and exit
]

# Set up Serena for use with a specific client
export extern "serena setup" [
  client: string@"nu-complete serena setup-client"                            #Client to set up for
  --help                                                                      #Show this message and exit
]

# Starts the Serena MCP server
export extern "serena start-mcp-server" [
  --project: string                                                           #Project name or path to activate
  --project-file: string                                                      #[DEPRECATED] Use --project instead
  --context: string@"nu-complete serena contexts"                             #Context name or path
  --mode: string@"nu-complete serena modes"                                   #Mode name(s) or path(s) to custom YAML
  --language-backend: string@"nu-complete serena language-backend"            #Override language backend
  --transport: string@"nu-complete serena transport"                          #Transport protocol
  --host: string                                                              #Listen address
  --port: int                                                                 #Listen port
  --enable-web-dashboard                                                      #Enable the web dashboard
  --enable-gui-log-window                                                     #Enable the GUI log window
  --open-web-dashboard                                                        #Open dashboard in browser on startup
  --log-level: string@"nu-complete serena log-level"                          #Override log level
  --trace-lsp-communication                                                   #Trace LSP communication
  --tool-timeout: float                                                       #Override tool execution timeout
  --project-from-cwd                                                          #Auto-detect project from CWD
  --help                                                                      #Show this message and exit
]

# Starts the Serena project server
export extern "serena start-project-server" [
  --host: string                                                              #Listen address
  --port: int                                                                 #Listen port
  --log-level: string@"nu-complete serena log-level"                          #Override log level
  --help                                                                      #Show this message and exit
]

# Open the Serena dashboard viewer for a given URL
export extern "serena dashboard-viewer" [
  url: string                                                                 #Dashboard URL to open
  --width: int                                                                #Window width
  --height: int                                                               #Window height
  --help                                                                      #Show this message and exit
]

# Print the system prompt for a project
export extern "serena print-system-prompt" [
  project?: string                                                            #Project name or path
  --log-level: string@"nu-complete serena log-level"                          #Log level for prompt generation
  --only-instructions                                                         #Print only initial instructions
  --context: string@"nu-complete serena contexts"                             #Context name or path
  --mode: string@"nu-complete serena modes"                                   #Mode name(s) or path(s)
  --help                                                                      #Show this message and exit
]
