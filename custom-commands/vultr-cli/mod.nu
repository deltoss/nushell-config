use ../../tools/secretspec.nu [secret-value]
use ./completions.nu [complete-vultr-cli]
use ../../tools/tui.nu [tui-picker]

def "nu-complete vultr-cli" [token: record, place: record] {
  complete-vultr-cli $token $place {|args| main ...$args}
}

# Keep the Vultr API key out of the shell's persistent environment.
# Only commands launched through this wrapper receive it.
@complete "nu-complete vultr-cli"
export def --wrapped main [...args] {
  with-env { VULTR_API_KEY: (secret-value VULTR_API_KEY) } {
    ^vultr-cli ...$args
  }
}

# Select an instance interactively
export def "instance menu select" [] {
  main instance list --output json | from json | get instances
  | tui-picker "Select an instance" [id os main_ip date_created]
}

# SSH into an instance interactively
export def "instance menu ssh" [] {
  let selection = instance menu select
  if ($selection | is-not-empty) {
    ^ssh $"root@($selection.main_ip)"
  }
}

# Destroys an instance interactively
export def "instance menu delete" [] {
  let selection = instance menu select
  if ($selection | is-not-empty) {
    main instance delete ($selection | get id)
  }
}

# Create an instance from snapshot interactively
export def "instance menu create-from-snapshot" [] {
  let snapshot = snapshot menu select
  if ($snapshot | is-empty) {
    return
  }

  let ssh_key = ssh-key menu select
  if ($ssh_key | is-empty) {
    return
  }

  let firewall_group = firewall group menu select
  if ($firewall_group | is-empty) {
    return
  }

  main instance create $'--region=($env.VULTR_DEFAULT_REGION)' $'--plan=($env.VULTR_DEFAULT_PLAN)' $'--snapshot=($snapshot.id)' --auto-backup=false $'--ssh-keys=($ssh_key.id)' $'--firewall-group=($firewall_group.id)'
}

# Select an snapshot interactively
export def "snapshot menu select" [] {
  let data = main snapshot list --output json | from json | get snapshots
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select a snapshot" [id description date_created]
}

# Select an SSH key interactively
export def "ssh-key menu select" [] {
  let data = main ssh-key list --output json | from json | get ssh_keys
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select an SSH key" [id name date_created]
}

# Select an firewall group interactively
export def "firewall group menu select" [] {
  let data = main firewall group list --output json | from json | get firewall_groups
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select a firewall group" [id description date_created]
}

# Select a block storage interactively
export def "block-storage menu select" [] {
  let data = main block-storage list --output json | from json | get blocks
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select block storage" [id size_gb date_created]
}

# Attach a block storage interactively
export def "block-storage menu attach" [] {
  let block_storage = block-storage menu select
  if ($block_storage | is-empty) {
    return
  }

  let instance = instance menu select
  if ($instance | is-empty) {
    return
  }

  loop {
    print $"Attempting to attach block storage to ($instance.id)..."
    let result = (main block-storage attach $block_storage.id $'--instance=($instance.id)' | complete)
    if $result.exit_code == 0 {
      print "Block storage attached successfully."
      break
    } else {
      print $"Failed: ($result.stderr). Retrying in 15s..."
      sleep 15sec
    }
  }
}

def "nu-complete instance menu subcommands" [] {
  [select, ssh, delete, create-from-snapshot]
}

# Completion stub only — real commands defined above
export extern "instance menu" [
  command?: string@"nu-complete instance menu subcommands"              #Subcommands
]

def "nu-complete snapshot menu subcommands" [] {
  [select]
}

# Completion stub only — real commands defined above
export extern "snapshot menu" [
  command?: string@"nu-complete snapshot menu subcommands"              #Subcommands
]

def "nu-complete ssh-key menu subcommands" [] {
  [select]
}

# Completion stub only — real commands defined above
export extern "ssh-key menu" [
  command?: string@"nu-complete ssh-key menu subcommands"               #Subcommands
]

def "nu-complete firewall group menu subcommands" [] {
  [select]
}

# Completion stub only — real commands defined above
export extern "firewall group menu" [
  command?: string@"nu-complete firewall group menu subcommands"        #Subcommands
]

def "nu-complete block-storage menu subcommands" [] {
  [select, attach]
}

# Completion stub only — real commands defined above
export extern "block-storage menu" [
  command?: string@"nu-complete block-storage menu subcommands"         #Subcommands
]