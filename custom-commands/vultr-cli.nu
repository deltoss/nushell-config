# Select an instance interactively
export def "instance menu select" [] {
  (^vultr-cli instance list --output json | from json | get instances
  | insert display { |row| $"($row.id) — OS: ($row.os) — Date Created ($row.date_created)" }
  | input list --fuzzy "Select an instance:" --display display
  | reject display)
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
    ^vultr-cli instance delete ($selection | get id)
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

  ^vultr-cli instance create $'--region=($env.VULTR_DEFAULT_REGION)' $'--plan=($env.VULTR_DEFAULT_PLAN)' $'--snapshot=($snapshot.id)' --auto-backup=false $'--ssh-keys=($ssh_key.id)' $'--firewall-group=($firewall_group.id)'
}

# Select an snapshot interactively
export def "snapshot menu select" [] {
  let data = ^vultr-cli snapshot list --output json | from json | get snapshots
  if (($data | length) == 1) {
    return ($data | first)
  }

  ($data
  | insert display { |row| $"($row.id) — ($row.description) — Date Created: ($row.date_created)" }
  | input list --fuzzy "Select a snapshot:" --display display
  | reject display)
}

# Select an SSH key interactively
export def "ssh-key menu select" [] {
  let data = ^vultr-cli ssh-key list --output json | from json | get ssh_keys
  if (($data | length) == 1) {
    return ($data | first)
  }

  ($data
  | insert display { |row| $"($row.id) — ($row.name) — Date Created: ($row.date_created)" }
  | input list --fuzzy "Select a key:" --display display
  | reject display)
}

# Select an firewall group interactively
export def "firewall group menu select" [] {
  let data = ^vultr-cli firewall group list --output json | from json | get firewall_groups
  if (($data | length) == 1) {
    return ($data | first)
  }

  ($data
  | insert display { |row| $"($row.id) — ($row.description) — Date Created: ($row.date_created)" }
  | input list --fuzzy "Select a firewall rule:" --display display
  | reject display)
}

# Select a block storage interactively
export def "block-storage menu select" [] {
  let data = ^vultr-cli block-storage list --output json | from json | get blocks
  if (($data | length) == 1) {
    return ($data | first)
  }

  ($data
  | insert display { |row| $"($row.id) — Size in GB: ($row.size_gb) — Date Created: ($row.date_created)" }
  | input list --fuzzy "Select a block storage:" --display display
  | reject display)
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
    let result = (^vultr-cli block-storage attach $block_storage.id $'--instance=($instance.id)' | complete)
    if $result.exit_code == 0 {
      print "Block storage attached successfully."
      break
    } else {
      print $"Failed: ($result.stderr). Retrying in 15s..."
      sleep 15sec
    }
  }
}