#!/bin/bash

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "Please run with sudo"
fi

# Get real user information
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

readonly REAL_USER
readonly REAL_HOME

# Function to add GPG keys and repositories
add_repositories() {
    log_info "Adding GPG keys and repositories..."
    
    # Create keyrings directory
    install -m 0755 -d /etc/apt/keyrings
    
    # Add GPG keys
    curl -fsSL 'https://mariadb.org/mariadb_release_signing_key.pgp' -o /etc/apt/keyrings/mariadb-keyring.pgp || log_warn "Failed to add MariaDB key"
    
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg || log_warn "Failed to add Redis key"
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || log_warn "Failed to add Docker key"
    chmod a+r /etc/apt/keyrings/docker.asc
    
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f microsoft.gpg
    
    wget -qO /usr/share/keyrings/dbeaver.gpg.key https://dbeaver.io/debs/dbeaver.gpg.key || log_warn "Failed to add DBeaver key"
    
    curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | gpg --dearmor --output /usr/share/keyrings/beekeeper.gpg || log_warn "Failed to add Beekeeper key"
    chmod go+r /usr/share/keyrings/beekeeper.gpg
    
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || log_warn "Failed to add Brave key"
    
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg || log_warn "Failed to add Antigravity key"
    
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg || log_warn "Failed to add Nginx key"
    
    wget -qO - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/trusted.gpg.d/google-chrome.gpg >/dev/null || log_warn "Failed to add Google Chrome key"
    
    # Add repository sources
    tee /etc/apt/sources.list.d/docker.sources <<EOF >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    tee /etc/apt/sources.list.d/mariadb.sources <<EOF >/dev/null
Types: deb
URIs: https://mirrors.accretive-networks.net/mariadb/repo/11.8/ubuntu
Suites: noble
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

    tee /etc/apt/sources.list.d/vscode.sources <<EOF >/dev/null
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

    echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" | tee /etc/apt/sources.list.d/dbeaver.list >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" | tee /etc/apt/sources.list.d/beekeeper-studio-app.list >/dev/null
    
    curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources || log_warn "Failed to add Brave sources"
    
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null
    
    tee /etc/apt/preferences.d/99nginx <<EOF >/dev/null
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

    # Add PPAs
    add-apt-repository ppa:ondrej/php -y || log_warn "Failed to add PHP PPA"
    add-apt-repository ppa:git-core/ppa -y || log_warn "Failed to add Git PPA"
    add-apt-repository ppa:xtradeb/apps -y || log_warn "Failed to add XtraDEB PPA"
    
    log_info "Repositories added successfully"
}

# Function to remove conflicting packages
remove_conflicting_packages() {
    log_info "Removing conflicting Docker packages..."
    local packages=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg"; then
            apt-get remove -y "$pkg" 2>/dev/null || log_warn "Could not remove $pkg"
        fi
    done
}

# Function to install system packages
install_packages() {
    log_info "Installing system packages..."
    
    local PHP_VERSIONS=(8.1 8.2 8.3 8.4 8.5)
    local PHP_EXTENSIONS=(cli fpm mysql curl gd mbstring xml zip bcmath intl imagick redis memcached common sqlite3 pgsql opcache decimal apcu)
    
    local PHP_PACKAGES=()
    for version in "${PHP_VERSIONS[@]}"; do
        for ext in "${PHP_EXTENSIONS[@]}"; do
            if [[ "$version" == "8.5" ]] && [[ "$ext" == "opcache" ]]; then
                continue
            fi
            PHP_PACKAGES+=("php${version}-${ext}")
        done
    done
    
    local BASE_PACKAGES=(
        # Web servers and databases
        nginx sqlite3 imagemagick redis
        
        # Docker
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Development tools
        git code dbeaver-ce beekeeper-studio build-essential
        
        # Browsers
        brave-browser google-chrome-stable
        
        # Virtualization
        virt-manager
        
        # Package managers
        flatpak gnome-software-plugin-flatpak
        
        # Network tools
        filezilla net-tools nmap
        
        # Media
        webp ffmpeg
        
        # GNOME tools
        gnome-shell-extension-manager gnome-tweaks chrome-gnome-shell
        
        # System utilities
        antigravity libfuse2 libnss3-tools
        
        # CLI utilities
        btop neofetch jq httpie tree ncdu tmux
        ripgrep fd-find bat trash-cli rsync
        unzip p7zip-full
        
        # Security
        ufw fail2ban
    )
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}" "${PHP_PACKAGES[@]}" || error_exit "Package installation failed"
    
    log_info "Packages installed successfully"
}

# Function to configure services
configure_services() {
    log_info "Configuring and enabling services..."
    
    local PHP_VERSIONS=(8.1 8.2 8.3 8.4 8.5)
    
    for version in "${PHP_VERSIONS[@]}"; do
        systemctl enable "php${version}-fpm.service" 2>/dev/null || log_warn "Could not enable php${version}-fpm"
        systemctl start "php${version}-fpm.service" 2>/dev/null || log_warn "Could not start php${version}-fpm"
    done
    
    systemctl enable redis-server || log_warn "Could not enable redis-server"
    systemctl start redis-server || log_warn "Could not start redis-server"
    
    systemctl restart nginx || log_warn "Could not restart nginx"
    
    systemctl start docker || log_warn "Could not start docker"
    
    # Configure Docker group
    groupadd docker 2>/dev/null || true
    usermod -aG docker "$REAL_USER" || log_warn "Could not add user to docker group"
    
    # Add nginx to www-data group
    usermod -aG www-data nginx 2>/dev/null || true
    
    # Enable and configure firewall
    systemctl enable ufw || log_warn "Could not enable ufw"
    ufw --force enable || log_warn "Could not start ufw"
    
    # Enable fail2ban
    systemctl enable fail2ban || log_warn "Could not enable fail2ban"
    systemctl start fail2ban || log_warn "Could not start fail2ban"
    
    log_info "Services configured successfully"
}

# Function to install snap packages
install_snap_packages() {
    log_info "Installing snap packages..."
    
    if command -v snap &>/dev/null; then
        snap install vlc --classic || log_warn "Failed to install VLC"
        snap install postman --classic || log_warn "Failed to install Postman"
        snap install termius-app --classic || log_warn "Failed to install Termius"
        snap install vault || log_warn "Failed to install Vault"
    else
        log_warn "Snap is not installed, skipping snap packages"
    fi
}

# Function to setup Flatpak
setup_flatpak() {
    log_info "Setting up Flatpak..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || log_warn "Failed to add Flathub repository"
}

# Function to install user-level tools
install_user_tools() {
    log_info "Installing user-level tools (Composer, NVM, Bun, mkcert, lazygit, lazydocker)..."
    
    cd "$REAL_HOME" || error_exit "Cannot access user home directory"
    
    # Install Composer
    if ! command -v composer &>/dev/null; then
        sudo -u "$REAL_USER" php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" || log_warn "Failed to download Composer installer"
        sudo -u "$REAL_USER" php composer-setup.php || log_warn "Failed to install Composer"
        sudo -u "$REAL_USER" php -r "unlink('composer-setup.php');"
        [ -f composer.phar ] && mv composer.phar /usr/local/bin/composer
    else
        log_info "Composer already installed"
    fi
    
    # Install NVM
    if [ ! -d "$REAL_HOME/.nvm" ]; then
        sudo -u "$REAL_USER" bash -c 'export NVM_DIR="$HOME/.nvm" && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install --lts' || log_warn "Failed to install NVM"
    else
        log_info "NVM already installed"
    fi
    
    # Install Bun
    if ! sudo -u "$REAL_USER" command -v bun &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -fsSL https://bun.sh/install | bash" || log_warn "Failed to install Bun"
    else
        log_info "Bun already installed"
    fi
    
    # Install mkcert
    if ! command -v mkcert &>/dev/null; then
        curl -fsSL https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64 -o /usr/local/bin/mkcert || log_warn "Failed to download mkcert"
        chmod +x /usr/local/bin/mkcert
        sudo -u "$REAL_USER" mkcert -install || log_warn "Failed to install mkcert CA"
    else
        log_info "mkcert already installed"
    fi
    
    # Install lazygit
    if ! command -v lazygit &>/dev/null; then
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" || log_warn "Failed to download lazygit"
        tar xf lazygit.tar.gz lazygit
        install lazygit /usr/local/bin
        rm -f lazygit lazygit.tar.gz
    else
        log_info "lazygit already installed"
    fi
    
    # Install lazydocker
    if ! command -v lazydocker &>/dev/null; then
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash || log_warn "Failed to install lazydocker"
    else
        log_info "lazydocker already installed"
    fi
    
    # Install GitHub CLI
    if ! command -v gh &>/dev/null; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update
        apt-get install -y gh || log_warn "Failed to install GitHub CLI"
    else
        log_info "GitHub CLI already installed"
    fi
    
    # Install eza (modern ls)
    if ! command -v eza &>/dev/null; then
        mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
        chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        apt-get update
        apt-get install -y eza || log_warn "Failed to install eza"
    else
        log_info "eza already installed"
    fi
    
    # Install zoxide
    if ! command -v zoxide &>/dev/null; then
        sudo -u "$REAL_USER" bash -c "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" || log_warn "Failed to install zoxide"
    else
        log_info "zoxide already installed"
    fi
}

# Function to install MariaDB
install_mariadb() {
    log_info "Installing MariaDB..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server || log_warn "Failed to install MariaDB"
}

# Function to perform system cleanup
system_cleanup() {
    log_info "Performing system cleanup..."
    apt-get update || log_warn "apt update failed"
    apt-get upgrade -y || log_warn "apt upgrade failed"
    apt-get autoremove -y || log_warn "apt autoremove failed"
    apt-get autoclean -y || log_warn "apt autoclean failed"
}

# Main execution
main() {
    log_info "Starting Ubuntu post-installation script..."
    log_info "Real user: $REAL_USER"
    log_info "User home: $REAL_HOME"
    
    log_info "Updating system..."
    apt-get update || error_exit "Initial apt update failed"
    apt-get upgrade -y || log_warn "Initial apt upgrade failed"
    apt-get install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring software-properties-common apt-transport-https gpg wget || error_exit "Failed to install basic dependencies"
    
    add_repositories
    
    log_info "Updating package lists..."
    apt-get update || error_exit "apt update failed after adding repositories"
    
    remove_conflicting_packages
    install_packages
    configure_services
    install_snap_packages
    setup_flatpak
    install_user_tools
    install_mariadb
    system_cleanup
    
    log_info "Installation completed successfully!"
    log_info "Please restart your terminal or run 'source ~/.bashrc' to apply changes"
    log_info "You may need to log out and log back in for group changes to take effect"
}

# Run main function
main