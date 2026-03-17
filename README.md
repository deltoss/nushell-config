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