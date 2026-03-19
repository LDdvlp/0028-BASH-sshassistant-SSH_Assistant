# SSH Assistant 🔐

![CI](https://github.com/LDdvlp/0028-BASH-sshassistant-SSH_Assistant/actions/workflows/ci.yml/badge.svg)

SSH Assistant est un outil Bash interactif permettant de gérer facilement :
- la génération de clés SSH
- la configuration des hôtes (~/.ssh/config)
- les tests de connexion SSH
- la sauvegarde et restauration du dossier .ssh

---

## 🚀 Installation

git clone https://github.com/LDdvlp/0028-BASH-sshassistant-SSH_Assistant.git
cd 0028-BASH-sshassistant-SSH_Assistant
chmod +x bin/ssha

---

## ▶️ Utilisation

./bin/ssha

---

## 🧰 Fonctionnalités

### 🔑 Création de clés SSH
- Génération manuelle
- Génération automatique via providers.conf
- Support ed25519 / rsa / ecdsa

### 🌐 Configuration SSH
- Ajout automatique dans ~/.ssh/config
- Suppression / mise à jour des hôtes

### 🔍 Tests de connexion
- Test SAFE (ssh -G)
- Test réel (publickey)
- Support GitHub / GitLab / Bitbucket

### 📁 Gestion du dossier SSH
- Affichage du contenu
- Sauvegarde
- Suppression sécurisée (avec confirmation)

---

## 🧪 Tests & Qualité

### Vérification syntaxe
make syntax

### Lint (ShellCheck)
make lint

### Tests (Bats)
make test

### CI complète
make ci

---

## ⚙️ Structure du projet

```
.
├── bin/
│   └── ssha
├── lib/
│   ├── ssha_core.sh
│   └── ssha_colors.sh
├── tests/
├── assets/
├── Makefile
└── README.md
```

---

## 🧠 Philosophie

- Interface utilisateur simple (CLI interactive)
- Robustesse (gestion erreurs + confirmations)
- Code Bash structuré et maintenable
- Compatible Linux / Git Bash

---

## 🔐 Sécurité

- Aucune clé privée n’est envoyée ou stockée ailleurs que localement
- Sauvegarde automatique avant suppression
- Mode DRY-RUN disponible

---

## 📌 Roadmap

- [ ] Amélioration UX
- [ ] Ajout nouveaux providers
- [ ] Packaging install global
- [ ] Tests avancés SSH (mock)

---

## 👤 Auteur

Loïc Drouet

---

## 📄 Licence

MIT
