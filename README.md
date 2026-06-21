# Ubuntu Post-Installation Script

Automated post-installation script for Ubuntu that sets up a complete development environment with web servers, databases, containerization tools, security hardening, and essential utilities.

## 🚀 Quick Start

```bash
sudo apt install curl
curl -fsSL https://raw.githubusercontent.com/danidoble/sh/refs/heads/main/postinstall.sh | sudo bash
```

Or download and run locally:

```bash
curl -fsSL https://raw.githubusercontent.com/danidoble/sh/refs/heads/main/postinstall.sh -o postinstall.sh
chmod +x postinstall.sh
sudo ./postinstall.sh
```

## 🗑️ Uninstall

A companion rollback script is provided to reverse the changes made by `postinstall.sh`:

```bash
sudo bash uninstall.sh
# or
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/danidoble/sh/main/uninstall.sh)"
```

The uninstall script removes (with interactive confirmation per section):
- APT packages, snap packages, and Flatpak apps
- User-level binaries (`/usr/local/bin`: composer, mkcert, lazygit, lazydocker, kubectl, k9s, ctop, gitleaks)
- User-level tools (`~/.nvm`, `~/.oh-my-zsh`, `~/.local/bin/mise`, `~/.bun`, `~/.cargo/bin/atuin`, `~/.local/bin/zoxide`, `~/.local/bin/uv`, Codex, Claude, opencode, Antigravity, Cursor)
- Local development DNS configuration for `.test` and `.local`
- `postinstall.sh` additions from `.zshrc` and `.bashrc`, plus `~/.shell_aliases` (restores default shell to bash)
- APT repositories and GPG keys
- Security configurations (SSH backup restore, sysctl hardening, fail2ban jail, modprobe rules)
- Samba config (restored from backup) and optional share directory removal
- UFW rules added by the script

## 📋 What Gets Installed

### Web Development
- **PHP**: Multiple versions (8.1, 8.2, 8.3, 8.4, 8.5) with essential extensions
  - Extensions: `cli`, `fpm`, `mysql`, `curl`, `gd`, `mbstring`, `xml`, `zip`, `bcmath`, `intl`, `imagick`, `redis`, `memcached`, `common`, `sqlite3`, `pgsql`, `opcache`, `decimal`, `apcu`
  - Note: `opcache` is bundled in PHP 8.5+ and skipped automatically
- **Nginx**: Latest stable from nginx.org (pinned over distro package)
- **MariaDB 11.8**: Latest stable from official repository
- **Redis**: Latest from official repository
- **SQLite3** and **ImageMagick**

### Docker & Containerization
- Docker Engine (`docker-ce`)
- Docker CLI (`docker-ce-cli`)
- Docker Compose Plugin
- Docker Buildx Plugin
- `containerd.io`

### Development Tools
- **Composer**: PHP dependency manager (signature-verified install)
- **NVM** + Node.js LTS
- **pnpm** enabled through Corepack (`corepack enable pnpm`)
- **Bun**: Fast JavaScript runtime
- **Git**: Latest from `ppa:git-core/ppa`
- **GitHub CLI** (`gh`)
- **mise**: Universal version manager
- **uv**: Fast Python package manager
- **C/C++ build dependencies**: `build-essential`, `gcc`, `g++`, `make`, `cmake`, `pkg-config`, `gdb`, `valgrind`
- **Python development helpers**: `python3-venv`, `python3-pip`, `python3-dev`
- **AI coding CLIs**: Codex, Claude, opencode, Antigravity
- **Visual Studio Code**
- **DBeaver Community Edition**
- **Beekeeper Studio**
- **mkcert**: Local SSL certificate authority

### CLI & Terminal Tools
- **Shell**: Zsh + Oh My Zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting`
- **Prompt**: Starship (pre-configured)
- **Terminal multiplexer**: tmux
- **Modern replacements**: `eza` (ls), `bat` (cat), `ripgrep` (grep), `fd-find` (find), `zoxide` (cd)
- **TUI tools**: `btop` (top), `lazygit`, `lazydocker`, `k9s` (Kubernetes), `ctop` (Docker), `dive` (Docker images)
- **History**: `atuin` (AI disabled, sync off by default)
- **Other**: `fzf`, `git-delta`, `direnv`, `neofetch`, `jq`, `httpie`, `ncdu`, `tree`, `tmux`, `trash-cli`, `rsync`, `unzip`, `p7zip-full`

### Security Tools
- **ufw**: Firewall (enabled, rules: SSH, 80/tcp, 443/tcp, Samba)
- **fail2ban**: Brute-force protection (SSH jail: 3 retries, 1h ban)
- **ClamAV** + `clamav-daemon` + freshclam
- **Lynis**: Security auditing (runs in background → `/var/log/lynis-postinstall.log`)
- **rkhunter**: Rootkit hunter
- **auditd** + `audispd-plugins`: Kernel audit daemon
- **gitleaks**: Secret scanner
- **libpam-pwquality**: Password quality enforcement
- Kernel hardening via `/etc/sysctl.d/99-hardening.conf`
- Disabled unused filesystems via `/etc/modprobe.d/disable-unused-fs.conf`
- SSH hardened: root login disabled, MaxAuthTries 3, X11Forwarding off, idle timeout

### Networking & VPN
- **Tailscale**: Mesh VPN (daemon started; run `sudo tailscale up` to authenticate)
- **WireGuard** + `wireguard-tools`
- **dnsmasq + systemd-resolved**: wildcard local development DNS for `*.test` and `*.local`
- **Samba**: File sharing with a pre-configured `/srv/samba/shared` share
- `nmap`, `net-tools`, `dnsutils`, `filezilla`

### Desktop Applications
- Brave Browser
- Google Chrome
- Cursor
- **Snap**: VLC, Postman, Termius, Vault
- **Flatpak (Flathub)**: Obsidian, Bruno
- **GNOME**: Extension Manager, Tweaks, Chrome GNOME Shell, Flameshot, CopyQ, dconf-editor
- virt-manager (KVM/QEMU)
- Antigravity

## ⚙️ Prerequisites

- Ubuntu 20.04 or later (tested on Ubuntu Noble)
- Sudo privileges
- Internet connection
- Minimum 10 GB free disk space

## 🔧 How It Works

The script runs 10 sequential steps:

| Step | Description |
|------|-------------|
| 1 | Add GPG keys and APT repositories |
| 2 | Remove conflicting packages (old Docker, podman, etc.) |
| 3 | Install system packages |
| 4 | Install and start MariaDB |
| 5 | Configure services (PHP-FPM, Redis, Nginx, Docker, UFW, fail2ban, ClamAV, auditd, Tailscale) |
| 6 | Configure Samba share |
| 7 | Apply security hardening |
| 8 | Install snap packages |
| 9 | Set up Flatpak + Flathub apps |
| 10 | Install user-level tools and configure shell dotfiles |

## 📦 Services Configured

The script automatically enables and starts:
- PHP-FPM (all installed versions: 8.1 – 8.5)
- Redis Server
- Nginx
- Docker
- dnsmasq
- systemd-resolved
- Tailscale (`tailscaled`)
- Samba (`smbd`, `nmbd`)
- UFW (Firewall)
- fail2ban
- ClamAV freshclam + daemon
- auditd

## 👥 User Groups

Your user is automatically added to:
- `docker`: Run Docker commands without sudo
- `sambashare`: Access the Samba share

**Note**: Log out and back in for group changes to take effect.

## 🐚 Shell Configuration

The script configures Zsh (set as default shell) and Bash with shared aliases and shell integrations.

### Aliases

Aliases are written to `~/.shell_aliases` and sourced from both `~/.zshrc` and `~/.bashrc`, so the same shortcuts work in either shell.

Included alias groups:
- Modern CLI replacements: `ls`, `ll`, `lt`, `cat`, `find`, `grep`, `cd`, `top`
- Docker and TUI helpers: `dk`, `dkc`, `lg`, `ld`
- JavaScript build helpers: `nrb`, `pnrb`, `brb`, `pnpmr`, `bunr`
- System update helper: `aptup`
- Laravel Artisan shortcuts: `art`, `artisan`, `pa`, `pam`, `pamf`, `pamfs`, `pamr`, `pas`, `pat`, `pac`, `parl`, `pamk`, `optimize`, `optimizeclear`, `tinker`
- Composer shortcuts: `cda`, `ci`, `cu`, `cr`
- Laravel Sail shortcuts: `sail`, `sailup`, `saildown`, `sailart`
- Git shortcuts: `wip`, `nah`, `gl`

### Integrations (Zsh)
- `starship` prompt
- `zoxide` smart directory jumping
- `mise` version manager activation
- `atuin` shell history
- `direnv` environment switching
- `fzf` fuzzy finder

## 🌐 Local Development DNS

The script configures `dnsmasq` together with Ubuntu's `systemd-resolved` so development domains do not need entries in `/etc/hosts`.

- `dnsmasq` answers any depth of `.test` and `.local` with `127.0.0.1`
- `systemd-resolved` routes only `~test` and `~local` to local dnsmasq
- Supported examples: `app.test`, `api.app.test`, `foo.sub.domain.test`, `app.local`, `foo.sub.domain.local`
- Config files:
  - `/etc/dnsmasq.d/local-dev-domains.conf`
  - `/etc/systemd/resolved.conf.d/local-dev-domains.conf`

This keeps Ubuntu's normal DNS flow through `systemd-resolved` while adding wildcard local domains for development.

## ⚠️ Important Notes

- The script must be run with `sudo`
- Re-login is required for group changes (`docker`, `sambashare`) to take effect
- `opcache` extension is skipped for PHP 8.5 (bundled)
- UFW is enabled immediately; ensure SSH access is not blocked
- Lynis audit runs in the background; check `/var/log/lynis-postinstall.log`
- Samba requires a separate password: `sudo smbpasswd -a <user>`
- Tailscale requires authentication after install: `sudo tailscale up`

## 🔍 Verification

```bash
# PHP versions
php8.3 -v && php8.4 -v && php8.5 -v

# Core services
systemctl status nginx
systemctl status redis-server
systemctl status docker
systemctl status mariadb
systemctl status tailscaled

# Docker
docker --version
docker compose version

# Node.js (new terminal or after sourcing .zshrc)
node --version && npm --version
pnpm --version

# Local development DNS
resolvectl query app.test
resolvectl query foo.sub.domain.test
resolvectl query app.local

# Developer tools
composer --version
gh --version
codex --version
claude --version
opencode --version
antigravity --version
cursor --version
lazygit --version
lazydocker --version
k9s version
kubectl version --client
mise --version
atuin --version
gitleaks version

# Security
sudo ufw status verbose
sudo fail2ban-client status sshd
```

## 🛠️ Troubleshooting

### Docker permission denied
```bash
newgrp docker   # or log out and back in
```

### NVM / Node not found
```bash
source ~/.zshrc   # or restart terminal
```

### `.test` / `.local` domains not resolving
```bash
sudo systemctl status dnsmasq systemd-resolved
resolvectl domain
resolvectl query foo.sub.domain.test
```

### Service not starting
```bash
sudo systemctl status <service-name>
sudo journalctl -u <service-name> -b
```

### Samba share not accessible
```bash
sudo smbpasswd -a $USER   # set Samba password
sudo systemctl status smbd
testparm /etc/samba/smb.conf
```

## 📝 Customization

Download the script and edit before running:

```bash
curl -fsSL https://raw.githubusercontent.com/danidoble/sh/refs/heads/main/postinstall.sh -o postinstall.sh
# Edit PHP_VERSIONS, PHP_EXTENSIONS, BASE_PACKAGES, etc.
sudo bash postinstall.sh
```

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new packages
- Improve documentation
- Submit pull requests

## 📄 License

This script is provided as-is for personal and educational use.

## ⚡ Post-Installation Steps

1. **Restart your terminal** or run `source ~/.zshrc` / `source ~/.bashrc`
2. **Log out and back in** for group changes (`docker`, `sambashare`) to take effect
3. **Authenticate Tailscale**: `sudo tailscale up`
4. **Set Samba password**: `sudo smbpasswd -a $USER`
5. **Secure MariaDB**: `sudo mysql_secure_installation`
6. **Review Lynis report**: `cat /var/log/lynis-postinstall.log`
7. **Add firewall rules** as needed: `sudo ufw allow <port>`

---

Made with ❤️ for the Ubuntu community
