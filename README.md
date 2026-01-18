# SSH Assistant (v0.1.0-dev)

Petit assistant Bash pour générer des clés SSH et maintenir `~/.ssh/config`.

## Lancer
```bash
# Ubuntu/Debian
sudo apt-get install -y bats shellcheck
shellcheck -x bin/ssha lib/*.sh
bats -r tests
```

---

## Prochaine étape (option 2)

On ajoutera **2) Agent: status/start/ensure** (comme ton mini-projet précédent) + tests (stubs `ssh-agent`, `ssh-add`) + CI pareil.

Si tu me montres ton **menu final cible** (même brouillon), je l’intègre dans `ssha::menu()` et on versionne en **v0.1.1-dev**.