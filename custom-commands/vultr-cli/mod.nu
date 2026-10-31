use ../../tools/secretspec.nu [secret-value]
use ./completions.nu [complete-vultr-cli]
use ../../tools/tui.nu [tui-picker]

def "nu-complete vultr-cli" [token: record, place: record] {
  complete-vultr-cli $token $place {|args| main ...$args}
}

# Run Vultr CLI with credentials from SecretSpec.
#
# Keep the Vultr API key out of the shell's persistent environment.
# Only commands launched through this wrapper receive it.
@complete "nu-complete vultr-cli"
@example "List instances" { vultr-cli instance list }
export def --wrapped main [...args] {
  with-env { VULTR_API_KEY: (secret-value VULTR_API_KEY) } {
    ^vultr-cli ...$args
  }
}

# Choose a Vultr instance and return its record.
@example "Choose an instance" { vultr-cli instance menu select }
export def "instance menu select" [] {
  main instance list --output json | from json | get instances
  | tui-picker "Select an instance" [id os main_ip date_created]
}

# Connect over SSH to a selected Vultr instance.
@example "Choose an instance to connect to" { vultr-cli instance menu ssh }
export def "instance menu ssh" [] {
  let selection = instance menu select
  if ($selection | is-not-empty) {
    ^ssh $"root@($selection.main_ip)"
  }
}

# Delete a selected Vultr instance.
@example "Choose an instance to delete" { vultr-cli instance menu delete }
export def "instance menu delete" [] {
  let selection = instance menu select
  if ($selection | is-not-empty) {
    main instance delete ($selection | get id)
  }
}

# Create a Vultr instance from a selected snapshot.
@example "Choose a snapshot, SSH key and firewall group" { vultr-cli instance menu create-from-snapshot }
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

# Choose a Vultr snapshot and return its record.
@example "Choose a snapshot" { vultr-cli snapshot menu select }
export def "snapshot menu select" [] {
  let data = main snapshot list --output json | from json | get snapshots
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select a snapshot" [id description date_created]
}

# Choose a Vultr SSH key and return its record.
@example "Choose an SSH key" { vultr-cli ssh-key menu select }
export def "ssh-key menu select" [] {
  let data = main ssh-key list --output json | from json | get ssh_keys
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select an SSH key" [id name date_created]
}

# Choose a Vultr firewall group and return its record.
@example "Choose a firewall group" { vultr-cli firewall group menu select }
export def "firewall group menu select" [] {
  let data = main firewall group list --output json | from json | get firewall_groups
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select a firewall group" [id description date_created]
}

# Choose a Vultr block storage volume and return its record.
@example "Choose a storage volume" { vultr-cli block-storage menu select }
export def "block-storage menu select" [] {
  let data = main block-storage list --output json | from json | get blocks
  if (($data | length) == 1) {
    return ($data | first)
  }

  $data | tui-picker "Select block storage" [id size_gb date_created]
}

# Attach a selected Vultr storage volume to a selected instance.
@example "Choose a volume and instance to connect" { vultr-cli block-storage menu attach }
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