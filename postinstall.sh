#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Ubuntu Post-Install Script
# Usage:
#   sudo bash postinstall.sh
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/danidoble/sh/main/postinstall.sh)"
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Constants ───────────────────────────────────────────────────────────────

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly PHP_VERSIONS=(8.1 8.2 8.3 8.4 8.5)
readonly PHP_EXTENSIONS=(cli fpm mysql curl gd mbstring xml zip bcmath intl imagick redis memcached common sqlite3 pgsql opcache decimal apcu)

# ─── Logging ─────────────────────────────────────────────────────────────────

log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}
error_exit()  { log_error "$1"; exit 1; }

# ─── Preflight checks ────────────────────────────────────────────────────────

[ "$EUID" -ne 0 ] && error_exit "Please run with sudo"

if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

readonly REAL_USER REAL_HOME
readonly ARCH=$(dpkg --print-architecture)
readonly UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}")

# ─── 1. Repositories ─────────────────────────────────────────────────────────

add_repositories() {
    log_section "1/10 · Adding GPG keys and repositories"

    install -m 0755 -d /etc/apt/keyrings

    # ── GPG keys ──────────────────────────────────────────────────────────────
    _add_key() {
        local name="$1" url="$2" dest="$3" dearmor="${4:-false}"
        if [[ "$dearmor" == "true" ]]; then
            curl -fsSL "$url" | gpg --batch --yes --dearmor -o "$dest" || log_warn "Failed to add $name key"
        else
            curl -fsSL "$url" -o "$dest" || log_warn "Failed to add $name key"
        fi
    }

    _add_key "MariaDB"        'https://mariadb.org/mariadb_release_signing_key.pgp'                                        /etc/apt/keyrings/mariadb-keyring.asc
    _add_key "Redis"          https://packages.redis.io/gpg                                                                /usr/share/keyrings/redis-archive-keyring.gpg true
    _add_key "Docker"         https://download.docker.com/linux/ubuntu/gpg                                                 /etc/apt/keyrings/docker.asc
    _add_key "DBeaver"        https://dbeaver.io/debs/dbeaver.gpg.key                                                      /usr/share/keyrings/dbeaver.gpg.key true
    _add_key "Beekeeper"      https://deb.beekeeperstudio.io/beekeeper.key                                                 /usr/share/keyrings/beekeeper.gpg true
    _add_key "Brave"          https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg             /usr/share/keyrings/brave-browser-archive-keyring.gpg
    _add_key "Antigravity"    https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg                                     /etc/apt/keyrings/antigravity-repo-key.gpg true
    _add_key "Nginx"          https://nginx.org/keys/nginx_signing.key                                                     /usr/share/keyrings/nginx-archive-keyring.gpg true
    _add_key "GitHub CLI"     https://cli.github.com/packages/githubcli-archive-keyring.gpg                                /usr/share/keyrings/githubcli-archive-keyring.gpg
    _add_key "eza"            https://raw.githubusercontent.com/eza-community/eza/main/deb.asc                             /etc/apt/keyrings/gierens.gpg true
    _add_key "Tailscale"      "https://pkgs.tailscale.com/stable/ubuntu/${UBUNTU_CODENAME}.noarmor.gpg"                   /usr/share/keyrings/tailscale-archive-keyring.gpg

    # Microsoft (VSCode) — needs intermediate file
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --batch --yes --dearmor > /tmp/microsoft.gpg
    install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f /tmp/microsoft.gpg

    # Google Chrome
    wget -qO - https://dl.google.com/linux/linux_signing_key.pub | gpg --batch --yes --dearmor \
        | tee /etc/apt/trusted.gpg.d/google-chrome.gpg >/dev/null || log_warn "Failed to add Chrome key"

    chmod a+r  /etc/apt/keyrings/docker.asc
    chmod 644  /etc/apt/keyrings/mariadb-keyring.asc \
               /usr/share/keyrings/redis-archive-keyring.gpg \
               /usr/share/keyrings/dbeaver.gpg.key \
               /usr/share/keyrings/beekeeper.gpg \
               /usr/share/keyrings/githubcli-archive-keyring.gpg \
               /etc/apt/keyrings/gierens.gpg
    chmod go+r /usr/share/keyrings/beekeeper.gpg \
               /usr/share/keyrings/githubcli-archive-keyring.gpg

    # ── Sources ───────────────────────────────────────────────────────────────
    tee /etc/apt/sources.list.d/docker.sources <<EOF >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    tee /etc/apt/sources.list.d/mariadb.sources <<EOF >/dev/null
# MariaDB 12.3 repository list - created by postinstall.sh
X-Repolib-Name: MariaDB
Types: deb
URIs: https://mirrors.accretive-networks.net/mariadb/repo/12.3/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.asc
EOF

    tee /etc/apt/sources.list.d/vscode.sources <<EOF >/dev/null
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

    echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /"                        | tee /etc/apt/sources.list.d/dbeaver.list >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main"                     | tee /etc/apt/sources.list.d/beekeeper-studio-app.list >/dev/null
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main"                                              | tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main"                                  | tee /etc/apt/sources.list.d/gierens.list >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu ${UBUNTU_CODENAME} main" | tee /etc/apt/sources.list.d/tailscale.list >/dev/null

    curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
        https://brave-browser-apt-release.s3.brave.com/brave-browser.sources || log_warn "Failed to add Brave sources"

    tee /etc/apt/preferences.d/99nginx <<EOF >/dev/null
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

    # PPAs
    add-apt-repository ppa:ondrej/php   -y || log_warn "Failed to add PHP PPA"
    add-apt-repository ppa:git-core/ppa -y || log_warn "Failed to add Git PPA"
    add-apt-repository ppa:xtradeb/apps -y || log_warn "Failed to add XtraDEB PPA"

    if apt --help 2>&1 | grep -q "modernize-sources"; then
        DEBIAN_FRONTEND=noninteractive apt -y modernize-sources || log_warn "apt modernize-sources failed"
    else
        log_info "apt modernize-sources not available on this apt version — skipping"
    fi

    log_info "Repositories added"
}

# ─── 2. Remove conflicting packages ──────────────────────────────────────────

remove_conflicting_packages() {
    log_section "2/10 · Removing conflicting packages"
    local packages=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
    for pkg in "${packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            apt-get remove -y "$pkg" 2>/dev/null || log_warn "Could not remove $pkg"
        fi
    done
}

# ─── 3. Install system packages ──────────────────────────────────────────────

install_packages() {
    log_section "3/10 · Installing system packages"

    local PHP_PACKAGES=()
    for version in "${PHP_VERSIONS[@]}"; do
        for ext in "${PHP_EXTENSIONS[@]}"; do
            # opcache is bundled in PHP 8.5+
            [[ "$version" == "8.5" && "$ext" == "opcache" ]] && continue
            PHP_PACKAGES+=("php${version}-${ext}")
        done
    done

    local BASE_PACKAGES=(
        # Web servers
        nginx

        # Databases
        sqlite3 imagemagick redis

        # Docker
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Development tools
        git gh code dbeaver-ce beekeeper-studio build-essential
        gcc g++ make cmake pkg-config gdb valgrind python3-venv python3-pip python3-dev eza

        # Browsers
        brave-browser google-chrome-stable

        # Virtualization
        virt-manager

        # Package managers
        flatpak gnome-software-plugin-flatpak

        # Network tools
        filezilla net-tools nmap dnsutils dnsmasq samba samba-common-bin

        # VPN
        tailscale wireguard wireguard-tools

        # Media
        webp ffmpeg

        # GNOME tools
        gnome-shell-extension-manager gnome-tweaks chrome-gnome-shell
        flameshot copyq dconf-editor

        # System utilities
        libfuse2 libnss3-tools

        # CLI utilities
        btop neofetch jq httpie tree ncdu tmux
        ripgrep fd-find bat trash-cli rsync
        unzip p7zip-full fzf zsh git-delta direnv

        # Security
        ufw fail2ban clamav clamav-daemon
        lynis rkhunter auditd audispd-plugins
        libpam-pwquality
    )

    DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}" "${PHP_PACKAGES[@]}" \
        || error_exit "Package installation failed"

    log_info "Packages installed"
}

# ─── 4. MariaDB ──────────────────────────────────────────────────────────────

install_mariadb() {
    log_section "4/10 · Installing MariaDB"
    DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server || log_warn "Failed to install MariaDB"
    if command -v mariadb &>/dev/null; then
        systemctl enable --now mariadb || log_warn "Could not enable mariadb"
        log_info "MariaDB installed and started"
    fi
}

# ─── 5. Configure services ───────────────────────────────────────────────────

configure_services() {
    log_section "5/10 · Configuring services"

    # PHP-FPM
    for version in "${PHP_VERSIONS[@]}"; do
        systemctl enable --now "php${version}-fpm.service" 2>/dev/null || log_warn "Could not enable php${version}-fpm"
    done

    # Core services
    systemctl enable --now redis-server  || log_warn "redis-server"
    systemctl restart nginx              || log_warn "nginx"
    systemctl enable --now docker        || log_warn "docker"

    # Docker group
    groupadd docker 2>/dev/null || true
    usermod -aG docker "$REAL_USER" || log_warn "Could not add $REAL_USER to docker group"
    usermod -aG www-data nginx 2>/dev/null || true

    # Tailscale
    systemctl enable --now tailscaled || log_warn "Could not enable tailscaled"
    log_info "Tailscale daemon started — run 'sudo tailscale up' to authenticate"

    # Firewall
    systemctl enable ufw || log_warn "ufw"
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow Samba   # opens 137,138/udp + 139,445/tcp
    log_info "UFW configured (SSH, HTTP, HTTPS, Samba)"

    # Security daemons
    systemctl enable --now fail2ban        || log_warn "fail2ban"
    systemctl enable    clamav-freshclam   || log_warn "clamav-freshclam enable"
    systemctl start     clamav-freshclam   || log_warn "clamav-freshclam start"
    systemctl enable    clamav-daemon      || log_warn "clamav-daemon"
    systemctl enable --now auditd          || log_warn "auditd"

    log_info "Services configured"
}

configure_local_dev_dns() {
    log_section "Configuring local development DNS"

    install -d -m 0755 /etc/dnsmasq.d /etc/systemd/resolved.conf.d

    tee /etc/dnsmasq.d/local-dev-domains.conf <<'EOF' >/dev/null
# Added by postinstall.sh
# Resolve any depth of .test and .local names to localhost:
# app.test, api.app.test, foo.sub.domain.test, app.local, etc.
listen-address=127.0.0.1
bind-interfaces
port=53
domain-needed
bogus-priv
address=/.test/127.0.0.1
address=/.local/127.0.0.1
EOF

    tee /etc/systemd/resolved.conf.d/local-dev-domains.conf <<'EOF' >/dev/null
# Added by postinstall.sh
# Route only these development domains to local dnsmasq.
[Resolve]
DNS=127.0.0.1
Domains=~test ~local
DNSSEC=no
Cache=yes
EOF

    if [ -e /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
        cp /etc/resolv.conf "/etc/resolv.conf.bak.postinstall.$(date +%Y%m%d%H%M%S)"
    fi

    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

    systemctl enable --now systemd-resolved || log_warn "Could not enable systemd-resolved"
    systemctl restart systemd-resolved      || log_warn "Could not restart systemd-resolved"
    systemctl enable --now dnsmasq          || log_warn "Could not enable dnsmasq"
    systemctl restart dnsmasq               || log_warn "Could not restart dnsmasq"

    log_info "Local DNS configured: *.test and *.local resolve to 127.0.0.1"
}

# ─── 6. Samba ────────────────────────────────────────────────────────────────

configure_samba() {
    log_section "6/10 · Configuring Samba"

    local SAMBA_SHARE_DIR="/srv/samba/shared"
    install -d -m 0775 -o root -g sambashare "$SAMBA_SHARE_DIR" 2>/dev/null || {
        mkdir -p "$SAMBA_SHARE_DIR"
        chmod 0775 "$SAMBA_SHARE_DIR"
    }

    # Add real user to sambashare group
    getent group sambashare &>/dev/null || groupadd sambashare
    usermod -aG sambashare "$REAL_USER" || log_warn "Could not add $REAL_USER to sambashare"

    local SMB_CONF="/etc/samba/smb.conf"
    cp "$SMB_CONF" "${SMB_CONF}.bak.$(date +%Y%m%d%H%M%S)"

    # Inject share definition only if not already present
    if ! grep -q "\[Shared\]" "$SMB_CONF"; then
        tee -a "$SMB_CONF" <<'EOF' >/dev/null

# ── Shared folder (added by postinstall.sh) ──────────────────
[Shared]
   comment     = Shared Folder
   path        = /srv/samba/shared
   browsable   = yes
   read only   = no
   guest ok    = no
   valid users = @sambashare
   create mask     = 0664
   directory mask  = 0775
   force group     = sambashare
EOF
    fi

    # Harden global section (idempotent sed)
    sed -i '/^\[global\]/,/^\[/{
        s/^.*server min protocol.*/   server min protocol = SMB2/
    }' "$SMB_CONF"
    grep -q "server min protocol" "$SMB_CONF" || \
        sed -i '/^\[global\]/a\   server min protocol = SMB2' "$SMB_CONF"

    testparm -s "$SMB_CONF" &>/dev/null || log_warn "Samba config test failed — check $SMB_CONF"

    systemctl enable --now smbd nmbd || log_warn "Could not enable smbd/nmbd"
    systemctl restart smbd nmbd      || log_warn "Could not restart smbd/nmbd"

    log_info "Samba configured — share: $SAMBA_SHARE_DIR"
    log_info "Set a Samba password with: sudo smbpasswd -a $REAL_USER"
}

# ─── 7. Security hardening ───────────────────────────────────────────────────

configure_security() {
    log_section "7/10 · Applying security hardening"

    # SSH hardening
    local sshd_config="/etc/ssh/sshd_config"
    if [ -f "$sshd_config" ]; then
        cp "$sshd_config" "${sshd_config}.bak"
        sed -i \
            -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
            -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
            -e 's/^#\?X11Forwarding.*/X11Forwarding no/' \
            -e 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' \
            -e 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' \
            -e 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' \
            "$sshd_config"
        systemctl restart sshd 2>/dev/null || log_warn "Could not restart sshd"
        log_info "SSH hardened"
    fi

    # Kernel hardening
    tee /etc/sysctl.d/99-hardening.conf <<'EOF' >/dev/null
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
EOF
    sysctl -p /etc/sysctl.d/99-hardening.conf >/dev/null 2>&1 || log_warn "Could not apply sysctl settings"
    log_info "Kernel hardening applied"

    # fail2ban — SSH jail
    tee /etc/fail2ban/jail.d/ssh-custom.conf <<'EOF' >/dev/null
[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 3600
findtime = 600
EOF
    systemctl restart fail2ban 2>/dev/null || log_warn "Could not restart fail2ban"

    # Disable unused filesystems
    tee /etc/modprobe.d/disable-unused-fs.conf <<'EOF' >/dev/null
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF

    # Password quality
    if [ -f /etc/security/pwquality.conf ]; then
        sed -i \
            -e 's/^# minlen.*/minlen = 12/' \
            -e 's/^# dcredit.*/dcredit = -1/' \
            -e 's/^# ucredit.*/ucredit = -1/' \
            -e 's/^# lcredit.*/lcredit = -1/' \
            -e 's/^# ocredit.*/ocredit = -1/' \
            /etc/security/pwquality.conf
        log_info "Password policy configured"
    fi

    # Lynis — non-blocking background audit
    if command -v lynis &>/dev/null; then
        lynis audit system --quiet --no-colors > /var/log/lynis-postinstall.log 2>&1 &
        log_info "Lynis audit running → /var/log/lynis-postinstall.log"
    fi

    log_info "Security hardening done"
}

# ─── 8. Snap packages ────────────────────────────────────────────────────────

install_snap_packages() {
    log_section "8/10 · Installing snap packages"
    if command -v snap &>/dev/null; then
        snap install vlc          --classic || log_warn "VLC"
        snap install postman      --classic || log_warn "Postman"
        snap install termius-app  --classic || log_warn "Termius"
        snap install vault                  || log_warn "Vault"
    else
        log_warn "Snap not available — skipping"
    fi
}

# ─── 9. Flatpak ──────────────────────────────────────────────────────────────

setup_flatpak() {
    log_section "9/10 · Setting up Flatpak"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || log_warn "Flathub"
    sudo -u "$REAL_USER" flatpak install -y flathub md.obsidian.Obsidian  2>/dev/null || log_warn "Obsidian"
    sudo -u "$REAL_USER" flatpak install -y flathub com.usebruno.Bruno    2>/dev/null || log_warn "Bruno"
}

# ─── 10. User-level tools ────────────────────────────────────────────────────

install_user_tools() {
    log_section "10/10 · Installing user-level tools"

    cd "$REAL_HOME" || error_exit "Cannot access $REAL_HOME"

    # Composer (run as root so it can write to /usr/local/bin)
    if ! command -v composer &>/dev/null; then
        local installer_sig actual_sig
        installer_sig=$(curl -fsSL https://composer.github.io/installer.sig)
        php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
        actual_sig=$(php -r "echo hash_file('sha384','/tmp/composer-setup.php');")
        if [ "$installer_sig" = "$actual_sig" ]; then
            php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
                || log_warn "Composer install failed"
        else
            log_warn "Composer installer signature mismatch — skipping"
        fi
        rm -f /tmp/composer-setup.php
    else
        log_info "Composer already installed"
    fi

    # NVM + Node LTS
    if [ ! -d "$REAL_HOME/.nvm" ]; then
        sudo -u "$REAL_USER" bash -c '
            export NVM_DIR="$HOME/.nvm"
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        ' || log_warn "NVM install failed"
    else
        log_info "NVM already installed"
    fi

    sudo -u "$REAL_USER" bash -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install --lts && nvm alias default lts/*
    ' || log_warn "Node.js LTS install failed"

    # pnpm via Corepack
    sudo -u "$REAL_USER" bash -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        command -v corepack >/dev/null 2>&1 && corepack enable pnpm
    ' || log_warn "Could not enable pnpm with Corepack"

    # AI coding CLIs
    if ! sudo -u "$REAL_USER" bash -c 'command -v codex' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://chatgpt.com/codex/install.sh | sh" || log_warn "Codex CLI"
    else
        log_info "Codex CLI already installed"
    fi

    if ! sudo -u "$REAL_USER" bash -c 'command -v claude' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://claude.ai/install.sh | bash" || log_warn "Claude CLI"
    else
        log_info "Claude CLI already installed"
    fi

    if ! sudo -u "$REAL_USER" bash -c 'command -v opencode' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://opencode.ai/install | bash" || log_warn "opencode CLI"
    else
        log_info "opencode CLI already installed"
    fi

    if ! sudo -u "$REAL_USER" bash -c 'command -v antigravity' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" || log_warn "Antigravity CLI"
    else
        log_info "Antigravity CLI already installed"
    fi

    if ! sudo -u "$REAL_USER" bash -c 'command -v cursor' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl https://cursor.com/install -fsS | bash" || log_warn "Cursor"
    else
        log_info "Cursor already installed"
    fi

    # Bun
    if ! sudo -u "$REAL_USER" bash -c 'command -v bun' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://bun.sh/install | bash" || log_warn "Bun"
    else
        log_info "Bun already installed"
    fi

    # mkcert
    if ! command -v mkcert &>/dev/null; then
        local mkcert_ver
        mkcert_ver=$(curl -s "https://api.github.com/repos/FiloSottile/mkcert/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
        curl -fsSL "https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-${mkcert_ver}-linux-amd64" \
            -o /usr/local/bin/mkcert && chmod +x /usr/local/bin/mkcert || log_warn "mkcert download failed"
        sudo -u "$REAL_USER" mkcert -install || log_warn "mkcert CA install failed"
    else
        log_info "mkcert already installed"
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        local lg_ver
        lg_ver=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -fsSL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lg_ver}_Linux_x86_64.tar.gz" \
            | tar xz -C /tmp lazygit
        install /tmp/lazygit /usr/local/bin/lazygit
        rm -f /tmp/lazygit
        log_info "lazygit installed"
    else
        log_info "lazygit already installed"
    fi

    # lazydocker
    if ! command -v lazydocker &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash \
            || log_warn "lazydocker"
    else
        log_info "lazydocker already installed"
    fi

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" \
            || log_warn "zoxide"
    else
        log_info "zoxide already installed"
    fi

    # Starship
    if ! command -v starship &>/dev/null; then
        curl -sS https://starship.rs/install.sh | sh -s -- --yes || log_warn "Starship"
    else
        log_info "Starship already installed"
    fi

    # mise (universal version manager — install as real user)
    if ! sudo -u "$REAL_USER" bash -c 'command -v mise' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://mise.run | sh" || log_warn "mise install failed"
        local mise_bin="$REAL_HOME/.local/bin/mise"
        if [ -f "$mise_bin" ]; then
            ln -sf "$mise_bin" /usr/local/bin/mise
            log_info "mise installed → $mise_bin"
        else
            log_warn "mise binary not found at $mise_bin after install"
        fi
    else
        log_info "mise already installed"
    fi

    # uv (fast Python package manager)
    if ! command -v uv &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh" || log_warn "uv"
    else
        log_info "uv already installed"
    fi

    # gitleaks (secret scanner)
    if ! command -v gitleaks &>/dev/null; then
        local gl_ver
        gl_ver=$(curl -s "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -fsSL "https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_${gl_ver}_linux_x64.tar.gz" \
            | tar xz -C /tmp gitleaks
        install /tmp/gitleaks /usr/local/bin/gitleaks
        rm -f /tmp/gitleaks
        log_info "gitleaks installed"
    else
        log_info "gitleaks already installed"
    fi

    # kubectl
    if ! command -v kubectl &>/dev/null; then
        local kubectl_ver
        kubectl_ver=$(curl -s https://dl.k8s.io/release/stable.txt)
        curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${kubectl_ver}/bin/linux/amd64/kubectl" \
            && chmod +x /usr/local/bin/kubectl || log_warn "kubectl"
        log_info "kubectl installed"
    else
        log_info "kubectl already installed"
    fi

    # k9s (Kubernetes TUI)
    if ! command -v k9s &>/dev/null; then
        curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
            | tar xz -C /tmp k9s
        install /tmp/k9s /usr/local/bin/k9s
        rm -f /tmp/k9s
        log_info "k9s installed"
    else
        log_info "k9s already installed"
    fi

    # ctop (Docker containers top)
    if ! command -v ctop &>/dev/null; then
        local ctop_ver
        ctop_ver=$(curl -s "https://api.github.com/repos/bcicen/ctop/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -fsSLo /usr/local/bin/ctop \
            "https://github.com/bcicen/ctop/releases/download/v${ctop_ver}/ctop-${ctop_ver}-linux-amd64" \
            && chmod +x /usr/local/bin/ctop || log_warn "ctop"
        log_info "ctop installed"
    else
        log_info "ctop already installed"
    fi

    # dive (Docker image explorer)
    if ! command -v dive &>/dev/null; then
        local dive_ver
        dive_ver=$(curl -s "https://api.github.com/repos/wagoodman/dive/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -fsSL "https://github.com/wagoodman/dive/releases/latest/download/dive_${dive_ver}_linux_amd64.deb" \
            -o /tmp/dive.deb
        dpkg -i /tmp/dive.deb 2>/dev/null || apt-get install -f -y
        rm -f /tmp/dive.deb
        log_info "dive installed"
    else
        log_info "dive already installed"
    fi

    # atuin (shell history — non-interactive, AI disabled)
    if ! sudo -u "$REAL_USER" bash -c 'command -v atuin' &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh" </dev/null \
            || log_warn "atuin install failed"
        # Pre-configure: disable AI feature and skip first-run prompts
        local atuin_cfg_dir="$REAL_HOME/.config/atuin"
        mkdir -p "$atuin_cfg_dir"
        if [ ! -f "$atuin_cfg_dir/config.toml" ]; then
            tee "$atuin_cfg_dir/config.toml" <<'ATUIN_EOF' >/dev/null
## atuin config — generated by postinstall.sh
auto_sync = false
update_check = false

[ai]
enabled = false
ATUIN_EOF
        fi
        chown -R "$REAL_USER:$REAL_USER" "$atuin_cfg_dir"
        log_info "atuin installed (AI disabled, sync off)"
    else
        log_info "atuin already installed"
    fi

    # Oh My Zsh + plugins
    if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
        sudo -u "$REAL_USER" bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' \
            || log_warn "Oh My Zsh install failed"
        local ZSH_CUSTOM="$REAL_HOME/.oh-my-zsh/custom/plugins"
        sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions    "$ZSH_CUSTOM/zsh-autosuggestions"    2>/dev/null || log_warn "zsh-autosuggestions"
        sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting" 2>/dev/null || log_warn "zsh-syntax-highlighting"
        log_info "Oh My Zsh + plugins installed"
    else
        log_info "Oh My Zsh already installed"
    fi

    chsh -s "$(command -v zsh)" "$REAL_USER" || log_warn "Could not set zsh as default shell"
}

# ─── Dotfiles ─────────────────────────────────────────────────────────────────

configure_dotfiles() {
    log_section "Configuring shell dotfiles"

    local ZSHRC="$REAL_HOME/.zshrc"
    local BASHRC="$REAL_HOME/.bashrc"
    local ALIASES_FILE="$REAL_HOME/.shell_aliases"

    [ -f "$ZSHRC" ] || install -o "$REAL_USER" -g "$REAL_USER" -m 0644 /dev/null "$ZSHRC"
    [ -f "$BASHRC" ] || install -o "$REAL_USER" -g "$REAL_USER" -m 0644 /dev/null "$BASHRC"

    tee "$ALIASES_FILE" <<'ALIASEOF' >/dev/null
# ── postinstall.sh shared aliases ───────────────────────────
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias lt="eza --tree --icons"
alias cat="bat --style=plain"
alias find="fd"
alias grep="rg"
alias cd="z"
alias top="btop"
alias lg="lazygit"
alias ld="lazydocker"
alias dk="docker"
alias dkc="docker compose"

alias nrb='npm run build'
alias pnrb='pnpm run build'
alias brb='bun run build'
alias pnpmr='pnpm run'
alias bunr='bun run'
alias aptup='sudo apt update && sudo apt upgrade -y && sudo apt-get update && sudo apt-get upgrade -y && sudo apt update && sudo apt upgrade -y && sudo snap refresh && sudo flatpak update -y && sudo apt autoremove -y && sudo apt autoclean -y'

# Laravel Artisan
alias art="php artisan"
alias artisan="php artisan"
alias pa='php artisan'
alias pam='php artisan migrate'
alias pamf='php artisan migrate:fresh'
alias pamfs='php artisan migrate:fresh --seed'
alias pamr='php artisan migrate:rollback'
alias pas='php artisan serve'
alias pat='php artisan test'
alias pac='php artisan cache:clear'
alias parl='php artisan route:list'
alias pamk='php artisan make:model'
alias optimize='php artisan optimize'
alias optimizeclear='php artisan optimize:clear'
alias tinker='php artisan tinker'

# Composer
alias cda='composer dump-autoload -o'
alias ci='composer install'
alias cu='composer update'
alias cr='composer require'

# Laravel Sail
alias sail='./vendor/bin/sail'
alias sailup='sail up -d'
alias saildown='sail down'
alias sailart='sail artisan'

alias wip="git add . && git commit -m 'wip'"
alias nah="git reset --hard && git clean -df"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# ─────────────────────────────────────────────────────────────
ALIASEOF
    chown "$REAL_USER:$REAL_USER" "$ALIASES_FILE"
    log_info "Shared aliases written to $ALIASES_FILE"

    # Zsh config block
    local ZSH_BLOCK
    ZSH_BLOCK=$(cat <<'ZSHEOF'

# ── postinstall.sh additions ──────────────────────────────────
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$($HOME/.local/bin/mise activate zsh)"
eval "$(atuin init zsh)"
eval "$(direnv hook zsh)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

[ -f "$HOME/.shell_aliases" ] && source "$HOME/.shell_aliases"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
# plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf direnv)
# ─────────────────────────────────────────────────────────────
ZSHEOF
)

    # Bash config block
    local BASH_BLOCK
    BASH_BLOCK=$(cat <<'BASHEOF'

# ── postinstall.sh additions ──────────────────────────────────
eval "$(starship init bash)"
eval "$(zoxide init bash)"
eval "$($HOME/.local/bin/mise activate bash)"
eval "$(direnv hook bash)"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

[ -f "$HOME/.shell_aliases" ] && source "$HOME/.shell_aliases"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
# ─────────────────────────────────────────────────────────────
BASHEOF
)

    if [ -f "$ZSHRC" ] && ! grep -q "postinstall.sh additions" "$ZSHRC"; then
        echo "$ZSH_BLOCK" >> "$ZSHRC"
        chown "$REAL_USER:$REAL_USER" "$ZSHRC"
        log_info ".zshrc updated"
    else
        log_info ".zshrc already configured"
    fi

    if [ -f "$BASHRC" ] && ! grep -q "postinstall.sh additions" "$BASHRC"; then
        echo "$BASH_BLOCK" >> "$BASHRC"
        chown "$REAL_USER:$REAL_USER" "$BASHRC"
        log_info ".bashrc updated"
    fi

    # Starship config
    local STARSHIP_DIR="$REAL_HOME/.config"
    mkdir -p "$STARSHIP_DIR"
    if [ ! -f "$STARSHIP_DIR/starship.toml" ]; then
        sudo -u "$REAL_USER" tee "$STARSHIP_DIR/starship.toml" <<'EOF' >/dev/null
"$schema" = 'https://starship.rs/config-schema.json'

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[git_branch]
symbol = " "

[nodejs]
symbol = " "

[php]
symbol = " "

[docker_context]
symbol = " "

[python]
symbol = " "
EOF
        chown -R "$REAL_USER:$REAL_USER" "$STARSHIP_DIR"
        log_info "Starship config created"
    fi

    log_info "Dotfiles configured"
}

# ─── Final cleanup ────────────────────────────────────────────────────────────

system_cleanup() {
    log_section "Final cleanup"
    apt-get upgrade -y    || log_warn "apt upgrade failed"
    apt-get autoremove -y || log_warn "autoremove failed"
    apt-get autoclean -y  || log_warn "autoclean failed"
    freshclam 2>/dev/null || log_warn "ClamAV DB update failed"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    log_section "Ubuntu Post-Install Script"
    log_info "User:         $REAL_USER"
    log_info "Home:         $REAL_HOME"
    log_info "Architecture: $ARCH"
    log_info "Ubuntu:       $UBUNTU_CODENAME"

    # Bootstrap dependencies
    log_info "Bootstrapping base dependencies..."
    apt-get update -qq || error_exit "Initial apt update failed"
    apt-get upgrade -y -qq || log_warn "Initial apt upgrade had warnings"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl gnupg2 ca-certificates lsb-release ubuntu-keyring \
        software-properties-common apt-transport-https gpg wget \
        || error_exit "Failed to install basic dependencies"

    add_repositories

    log_info "Updating package lists..."
    apt-get update -qq || error_exit "apt update failed after adding repositories"

    remove_conflicting_packages
    install_packages
    install_mariadb
    configure_services
    configure_local_dev_dns
    configure_samba
    configure_security
    install_snap_packages
    setup_flatpak
    install_user_tools
    configure_dotfiles
    system_cleanup

    echo ""
    log_section "Installation complete!"
    log_info "Default shell changed to zsh"
    log_info "Tailscale: run 'sudo tailscale up' to connect"
    log_info "Samba:     run 'sudo smbpasswd -a ${REAL_USER}' to set a password"
    log_info "Lynis audit: /var/log/lynis-postinstall.log"
    log_info "Re-login for group changes (docker, sambashare) to take effect"
    log_info "Run 'source ~/.zshrc' or restart your terminal"
    echo ""
}

main "$@"
