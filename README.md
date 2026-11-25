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

## Credentials

Install [SecretSpec](https://secretspec.dev/) and configure access to the providers in
[secretspec.toml](./secretspec.toml). The manifest defines the secret names, provider
references, and cache settings. Credential lookup is implemented in
[tools/secretspec.nu](./tools/secretspec.nu).


## Termux

Clone this repository to `~/.config/nushell` as on Linux. Android selects the lightweight profile automatically; no separate fork or environment flag is required. Use `pkg install nushell git neovim yazi zellij starship zoxide fzf ripgrep fd bat eza` for the tools used by the profile. Start a new `nu` session after installation.

The Termux profile leaves SSH agent configuration to Termux and uses the standard zoxide navigation rather than the desktop search fallback. The desktop profile remains the default on other platforms.