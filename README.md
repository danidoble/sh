# Ubuntu Post-Installation Script

Automated post-installation script for Ubuntu that sets up a complete development environment with web servers, databases, containerization tools, and essential utilities.

## 🚀 Quick Start

```bash
sudo apt install curl
curl -fsSL https://raw.githubusercontent.com/danidoble/sh/refs/heads/main/ubuntu_postinstall.sh | sudo bash
```

## 📋 What Gets Installed

### Web Development
- **PHP**: Multiple versions (8.1, 8.2, 8.3, 8.4, 8.5) with essential extensions
  - Extensions: cli, fpm, mysql, curl, gd, mbstring, xml, zip, bcmath, intl, imagick, redis, memcached, sqlite3, pgsql, opcache, decimal, apcu
- **Nginx**: Latest stable version
- **MariaDB**: Latest stable version
- **Redis**: Latest version from official repository

### Docker & Containerization
- Docker Engine (docker-ce)
- Docker CLI
- Docker Compose Plugin
- Docker Buildx Plugin
- containerd

### Development Tools
- **Composer**: PHP dependency manager
- **NVM**: Node Version Manager with LTS Node.js
- **Bun**: Fast JavaScript runtime
- **Git**: Latest version from official PPA
- **GitHub CLI**: Official GitHub command-line tool

### IDEs & Database Tools
- Visual Studio Code
- DBeaver Community Edition
- Beekeeper Studio
- Postman (via Snap)

### System Utilities
- **Terminal Tools**: btop, neofetch, tmux, lazygit, lazydocker
- **Modern CLI Tools**: eza (modern ls), zoxide, ripgrep, fd-find, bat, trash-cli
- **File Management**: rsync, unzip, p7zip-full, ncdu, tree
- **Network Tools**: nmap, net-tools, httpie, jq, filezilla
- **Media**: ffmpeg, webp, imagemagick
- **Security**: ufw, fail2ban, mkcert

### Desktop Applications
- Brave Browser
- Google Chrome
- VLC Media Player (Snap)
- Termius (Snap)
- Vault (Snap)
- virt-manager

### GNOME Extensions
- GNOME Shell Extension Manager
- GNOME Tweaks
- Chrome GNOME Shell

## ⚙️ Prerequisites

- Ubuntu 20.04 or later (tested on Ubuntu Noble)
- Sudo privileges
- Internet connection
- Minimum 10GB free disk space

## 🔧 Features

- **Error Handling**: Robust error handling with colored output
- **Safe Execution**: Checks for root privileges and preserves user context
- **Service Management**: Automatically enables and starts all services
- **GPG Key Management**: Securely adds all necessary repository keys
- **Conflict Resolution**: Removes conflicting packages before installation
- **User Tools**: Installs user-level tools with proper permissions

## 📦 Services Configured

The script automatically enables and starts:
- PHP-FPM (all installed versions)
- Redis Server
- Nginx
- Docker
- UFW (Firewall)
- Fail2ban

## 👥 User Groups

Your user is automatically added to:
- `docker`: To run Docker commands without sudo
- `www-data`: For web development (nginx user)

**Note**: You'll need to log out and back in for group changes to take effect.

## ⚠️ Important Notes

- The script must be run with `sudo`
- Some PHP extensions (opcache) are not available for PHP 8.5
- Firewall (UFW) is automatically enabled
- Docker daemon starts automatically
- PHP-FPM services run on their respective sockets

## 🔍 Verification

After installation, verify key components:

```bash
# Check PHP versions
php8.3 -v
php8.4 -v
php8.5 -v

# Check services
systemctl status nginx
systemctl status redis-server
systemctl status docker

# Check Docker
docker --version
docker compose version

# Check Node.js (in new terminal)
node --version
npm --version

# Check other tools
composer --version
gh --version
lazygit --version
```

## 🛠️ Troubleshooting

### Docker permission denied
```bash
# Logout and login again, or run:
newgrp docker
```

### NVM not found
```bash
# Restart your terminal or run:
source ~/.bashrc
```

### Service not starting
```bash
# Check service status
sudo systemctl status <service-name>

# View logs
sudo journalctl -u <service-name> -b
```

## 🔐 Security

- UFW firewall is enabled by default
- Fail2ban is configured and running
- mkcert is installed for local SSL certificates
- Regular security updates are applied

## 📝 Customization

To customize the installation, download the script and modify it:

```bash
curl -fsSL https://raw.githubusercontent.com/danidoble/sh/refs/heads/main/ubuntu_postinstall.sh -o ubuntu_postinstall.sh
chmod +x ubuntu_postinstall.sh
# Edit the script as needed
sudo ./ubuntu_postinstall.sh
```

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new packages
- Improve documentation
- Submit pull requests

## 📄 License

This script is provided as-is for personal and educational use.

## ⚡ Post-Installation

After running the script:

1. **Restart your terminal** or run `source ~/.bashrc`
2. **Log out and log back in** for group changes to take effect
3. **Configure PHP versions** in your web server as needed
4. **Set up MariaDB** with `sudo mysql_secure_installation`
5. **Configure firewall rules** with `sudo ufw allow <port>`

---

Made with ❤️ for the Ubuntu community
