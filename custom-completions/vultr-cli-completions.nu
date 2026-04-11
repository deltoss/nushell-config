#Output format [ text | json | yaml ] (default "text")
def "nu-complete vultr-cli output" [] {
    [text, json, yaml]
}

def "nu-complete vultr-cli instance-id" [] {
  ^vultr-cli instance list --output json | from json | get instances | each {|it| {description: $"($it.main_ip) - ($it.os)" value: $it.id} }
}

def "nu-complete vultr-cli snapshot-id" [] {
  ^vultr-cli snapshot list --output json | from json | get snapshots | each {|it| {description: $"($it.description) - ($it.date_created)" value: $it.id} }
}


def "nu-complete vultr-cli subcommands" [] {
  ^vultr-cli --help | lines | where $it =~ '^ {2}[A-Za-z]' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# A command line interface for the Vultr API
export extern "vultr-cli" [
  command?: string@"nu-complete vultr-cli subcommands"                  #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli block-storage subcommands" [] {
  ^vultr-cli block-storage --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to manage block storage
export extern "vultr-cli block-storage" [
  command?: string@"nu-complete vultr-cli block-storage subcommands"    #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli instance subcommands" [] {
  ^vultr-cli instance --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to interact with an instance
export extern "vultr-cli instance" [
  command?: string@"nu-complete vultr-cli instance subcommands"         #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]

export extern "vultr-cli instance delete" [
  id: string@"nu-complete vultr-cli instance-id"                        #Id of the instance
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]

export extern "vultr-cli instance destroy" [
  id: string@"nu-complete vultr-cli instance-id"                        #Id of the instance
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli regions subcommands" [] {
  ^vultr-cli regions --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Displays region information
export extern "vultr-cli regions" [
  command?: string@"nu-complete vultr-cli regions subcommands"          #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli plans subcommands" [] {
  ^vultr-cli plans --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Displays available plan information
export extern "vultr-cli plans" [
  command?: string@"nu-complete vultr-cli plans subcommands"            #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli os subcommands" [] {
  ^vultr-cli os --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Displays available operating systems
export extern "vultr-cli os" [
  command?: string@"nu-complete vultr-cli os subcommands"               #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli firewall subcommands" [] {
  ^vultr-cli firewall --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to manage firewalls
export extern "vultr-cli firewall" [
  command?: string@"nu-complete vultr-cli firewall subcommands"         #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli firewall group subcommands" [] {
  ^vultr-cli firewall group --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to access firewall group functions
export extern "vultr-cli firewall group" [
  command?: string@"nu-complete vultr-cli firewall group subcommands"   #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli firewall rule subcommands" [] {
  ^vultr-cli firewall rule --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to access firewall rules
export extern "vultr-cli firewall rule" [
  command?: string@"nu-complete vultr-cli firewall rule subcommands"    #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli snapshot subcommands" [] {
  ^vultr-cli snapshot --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to interact with snapshots
export extern "vultr-cli snapshot" [
  command?: string@"nu-complete vultr-cli snapshot subcommands"         #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


def "nu-complete vultr-cli ssh-key subcommands" [] {
  ^vultr-cli ssh-key --help | lines | where $it =~ '^ {2}[A-Za-z]+[A-Za-z\-]+\s' | parse --regex '^ {2}(?P<value>[^\s*]+)\*?\s+(?P<description>.+)$' | where value != 'vultr-cli'
}

# Commands to manage SSH keys
export extern "vultr-cli ssh-key" [
  command?: string@"nu-complete vultr-cli ssh-key subcommands"          #Subcommands
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]


export extern "vultr-cli snapshot create" [
  --id (-i): string@"nu-complete vultr-cli instance-id"                 #Id of the instance
  --description (-d): string                                            #Description of the snapshot
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]

export extern "vultr-cli snapshot get" [
  id: string@"nu-complete vultr-cli snapshot-id"                        #Id of the snapshot
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]

export extern "vultr-cli snapshot delete" [
  id: string@"nu-complete vultr-cli snapshot-id"                        #Id of the snapshot
  --config: string                                                      #Path to config file (default "~/.vultr-cli.yaml")
  --help (-h)                                                           #Help for vultr-cli
  --output: string@"nu-complete vultr-cli output"                       #Output format [ text | json | yaml ] (default "text")
]