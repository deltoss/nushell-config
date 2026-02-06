# Nushell Configurations

## Getting Started

```bash
rm -rf ~/.config/nushell
git clone git@github.com:deltoss/nushell-config.git ~/.config/nushell
```

## Subtrees

This configuration uses [nu_scripts](https://github.com/nushell/nu_scripts) for external command completions.

```bash
# Update subtree with upstream changes:
git subtree pull --prefix=nu_scripts https://github.com/nushell/nu_scripts.git main --squash
```
