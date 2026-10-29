# Nushell Configurations

## Getting Started

### Bash

```bash
rm -rf ~/.config/nushell
git clone git@github.com:deltoss/nushell-config.git ~/.config/nushell
```

### Powershell

```powershell
rm -Recurse ~/.config/nushell
git clone git@github.com:deltoss/nushell-config.git $env:USERPROFILE/.config/nushell
```

## Subtrees

This configuration uses [nu_scripts](https://github.com/nushell/nu_scripts) for external command completions.

```bash
# Update subtree with upstream changes:
git subtree pull --prefix=nu_scripts https://github.com/nushell/nu_scripts.git main --squash
```

## Atlassian credentials

Jira and Bitbucket commands use [SecretSpec](https://secretspec.dev/) 0.19+ and `secretspec.toml`.
1Password remains the source of truth. SecretSpec caches each field in the operating-system keyring for 30 days, shared across Nushell sessions. On Linux, this needs an unlocked Secret Service keyring (such as GNOME Keyring); Windows uses Credential Manager. The dotfiles repo already installs these dependencies.

The first `ticket pick` may prompt for 1Password authentication. Later shells use the local cache. To prime all four credentials without printing them:

```nu
let spec = $nu.default-config-dir | path join "secretspec.toml"
for key in [JIRAAPIKEY JIRABASEURL ATLASSIANUSERNAME BITBUCKETAPIKEY] {
  secretspec --file $spec get $key | ignore
}
```

To force a fresh read after a token rotation:

```nu
secretspec --file ($nu.default-config-dir | path join "secretspec.toml") cache clear JIRAAPIKEY
```

Existing environment overrides (`JIRAAPIKEY`, `JIRABASEURL`, `ATLASSIANUSERNAME`, and `BITBUCKETAPIKEY`) still take priority. The cache stores real secret values in the OS keyring, not Git.

## Ticket UI

Run `ticket ui` to browse and copy tickets. It uses the projects and active statuses
saved by `jira setup`; add `--all` to bypass them.

Space toggles tickets. Actions use checked tickets, or the highlighted ticket if none are checked:

| Key | Action |
| --- | --- |
| `y` | Copy ticket keys, one per line |
| `Y` | Copy full URLs, one per line |
| `b` | Open tickets in the browser |
| `/` | Search |
| `q` / `Esc` | Quit |

Copying uses Nushell's OSC 52 clipboard support and leaves the interface open.
`ticket list` returns records for pipelines; `ticket pick --multi` returns selected records and closes.

`ticket widget` returns the Tickets tab with the same shortcuts, without calling `tui run`.
Keep it in the outer pipeline when composing it with other tabs:

```nu
ticket widget | tui run
```

## Vultr CLI

Vultr commands use `VULTR_API_KEY` from the 1Password `Personal/Vultr/API Key` field, cached in the OS keyring by SecretSpec for 30 days. The key is not loaded by `env.nu`, stored in `.env.json`, or passed as a command-line argument.

The Nushell `vultr-cli` command wraps the external binary and injects the API key only for that invocation. The existing `instance menu`, `snapshot menu`, `ssh-key menu`, `firewall group menu` and `block-storage menu` commands use this wrapper. Use `vultr-cli instance list` in Nushell for direct commands; `^vultr-cli` bypasses the wrapper and won't inject the key.

To populate the cache without displaying the key:

```nu
let spec = $nu.default-config-dir | path join "secretspec.toml"
secretspec --file $spec get VULTR_API_KEY | ignore
vultr-cli instance list
```
