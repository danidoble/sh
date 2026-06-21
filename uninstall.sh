#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Ubuntu Post-Install Rollback / Uninstall Script
# Reverses changes made by postinstall.sh
# Usage: sudo bash uninstall.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}
error_exit() { log_error "$1"; exit 1; }

confirm() {
    local prompt="$1"
    echo -en "${YELLOW}[?]${NC} $prompt [y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

[ "$EUID" -ne 0 ] && error_exit "Please run with sudo"

if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

readonly REAL_USER REAL_HOME

# ─────────────────────────────────────────────────────────────────────────────

log_section "Ubuntu Post-Install Rollback"
echo -e "${RED}WARNING: This will remove software and configurations added by postinstall.sh.${NC}"
echo -e "User: ${CYAN}$REAL_USER${NC} | Home: ${CYAN}$REAL_HOME${NC}\n"
confirm "Continue with rollback?" || { log_info "Aborted."; exit 0; }

# ─── 1. APT packages ─────────────────────────────────────────────────────────

if confirm "Remove APT packages added by postinstall.sh?"; then
    log_section "Removing APT packages"

    APT_PACKAGES=(
        # Docker
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        # Dev tools
        gh code dbeaver-ce beekeeper-studio eza
        # Browsers
        brave-browser google-chrome-stable
        # Samba
        samba samba-common-bin
        # VPN
        tailscale
        # GNOME extras
        gnome-shell-extension-manager flameshot copyq dconf-editor
        # System
        dnsmasq
        # Security
        fail2ban clamav clamav-daemon lynis rkhunter auditd audispd-plugins libpam-pwquality
        # CLI
        btop git-delta direnv fzf ripgrep fd-find bat trash-cli ncdu tmux httpie jq
        # C/Python development dependencies
        gcc g++ make cmake pkg-config gdb valgrind python3-venv python3-pip python3-dev
        # MariaDB
        mariadb-server mariadb-client
        # Redis
        redis
        # Nginx
        nginx
        # PHP (all versions/extensions)
        $(dpkg -l 'php*' 2>/dev/null | awk '/^ii/{print $2}' | tr '\n' ' ')
    )

    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "${APT_PACKAGES[@]}" 2>/dev/null \
        || log_warn "Some packages may not have been installed — continuing"
    apt-get autoremove -y || true
    log_info "APT packages removed"
fi

# ─── 2. Snap packages ────────────────────────────────────────────────────────

if confirm "Remove snap packages (vlc, postman, termius-app, vault)?"; then
    log_section "Removing snap packages"
    for pkg in vlc postman termius-app vault; do
        snap remove "$pkg" 2>/dev/null || log_warn "$pkg not installed via snap"
    done
fi

# ─── 3. Flatpak apps ─────────────────────────────────────────────────────────

if confirm "Remove Flatpak apps (Obsidian, Bruno)?"; then
    log_section "Removing Flatpak apps"
    sudo -u "$REAL_USER" flatpak uninstall -y md.obsidian.Obsidian 2>/dev/null || log_warn "Obsidian not found"
    sudo -u "$REAL_USER" flatpak uninstall -y com.usebruno.Bruno   2>/dev/null || log_warn "Bruno not found"
fi

# ─── 4. User-installed binaries ──────────────────────────────────────────────

if confirm "Remove user-installed binaries from /usr/local/bin?"; then
    log_section "Removing binaries from /usr/local/bin"
    for bin in composer mkcert lazygit lazydocker kubectl k9s ctop gitleaks codex claude opencode antigravity cursor; do
        rm -f "/usr/local/bin/$bin" && log_info "Removed $bin" || true
    done
fi

# ─── 5. User-level tools (home directory) ────────────────────────────────────

if confirm "Remove user-level tools (~/.nvm, ~/.oh-my-zsh, ~/.local/bin/mise, ~/.bun, ~/.cargo/bin/atuin, ~/.local/bin/zoxide, ~/.local/bin/uv, AI coding CLIs)?"; then
    log_section "Removing user-level tools"
    rm -rf \
        "$REAL_HOME/.nvm" \
        "$REAL_HOME/.oh-my-zsh" \
        "$REAL_HOME/.local/bin/mise" \
        "$REAL_HOME/.local/bin/zoxide" \
        "$REAL_HOME/.local/bin/uv" \
        "$REAL_HOME/.local/bin/codex" \
        "$REAL_HOME/.local/bin/claude" \
        "$REAL_HOME/.local/bin/opencode" \
        "$REAL_HOME/.local/bin/antigravity" \
        "$REAL_HOME/.local/bin/cursor" \
        "$REAL_HOME/.codex" \
        "$REAL_HOME/.claude" \
        "$REAL_HOME/.opencode" \
        "$REAL_HOME/.antigravity" \
        "$REAL_HOME/.cursor" \
        "$REAL_HOME/.bun" \
        "$REAL_HOME/.cargo/bin/atuin" \
        "$REAL_HOME/.config/atuin" \
        "$REAL_HOME/.config/starship.toml" \
        2>/dev/null || true

    rm -f /usr/local/bin/mise /usr/local/bin/starship
    log_info "User-level tools removed"
fi

# ─── 6. Local development DNS ────────────────────────────────────────────────

if confirm "Remove local development DNS config for .test and .local?"; then
    log_section "Removing local development DNS configuration"

    rm -f /etc/dnsmasq.d/local-dev-domains.conf
    rm -f /etc/systemd/resolved.conf.d/local-dev-domains.conf

    latest_resolv_bak=$(ls -t /etc/resolv.conf.bak.postinstall.* 2>/dev/null | head -1)
    if [ -n "$latest_resolv_bak" ]; then
        cp "$latest_resolv_bak" /etc/resolv.conf
        log_info "Restored /etc/resolv.conf from $latest_resolv_bak"
    else
        log_warn "No postinstall resolv.conf backup found"
    fi

    systemctl restart systemd-resolved 2>/dev/null || true
    systemctl restart dnsmasq 2>/dev/null || true
    log_info "Local development DNS config removed"
fi

# ─── 7. Dotfile additions ────────────────────────────────────────────────────

if confirm "Remove postinstall.sh additions from .zshrc and .bashrc?"; then
    log_section "Cleaning dotfiles"
    rm -f "$REAL_HOME/.shell_aliases"
    log_info "Removed $REAL_HOME/.shell_aliases"

    for rcfile in "$REAL_HOME/.zshrc" "$REAL_HOME/.bashrc"; do
        if [ -f "$rcfile" ] && grep -q "postinstall.sh additions" "$rcfile"; then
            # Remove the block between the marker and the closing marker
            sed -i '/# ── postinstall\.sh additions/,/# ────.*─────/{d}' "$rcfile"
            chown "$REAL_USER:$REAL_USER" "$rcfile"
            log_info "Cleaned $rcfile"
        fi
    done

    # Restore default shell to bash
    chsh -s "$(command -v bash)" "$REAL_USER" || log_warn "Could not restore default shell"
    log_info "Default shell restored to bash"
fi

# ─── 8. APT repositories and GPG keys ────────────────────────────────────────

if confirm "Remove APT repositories and GPG keys added by postinstall.sh?"; then
    log_section "Removing APT sources and keys"

    SOURCES=(
        docker.sources mariadb.sources vscode.sources
        dbeaver.list redis.list beekeeper-studio-app.list
        google-chrome.list nginx.list github-cli.list gierens.list
        antigravity.list tailscale.list brave-browser-release.sources
    )
    for src in "${SOURCES[@]}"; do
        rm -f "/etc/apt/sources.list.d/$src" && log_info "Removed $src" || true
    done

    KEYS=(
        /etc/apt/keyrings/mariadb-keyring.pgp
        /usr/share/keyrings/redis-archive-keyring.gpg
        /etc/apt/keyrings/docker.asc
        /usr/share/keyrings/microsoft.gpg
        /usr/share/keyrings/dbeaver.gpg.key
        /usr/share/keyrings/beekeeper.gpg
        /usr/share/keyrings/brave-browser-archive-keyring.gpg
        /etc/apt/keyrings/antigravity-repo-key.gpg
        /usr/share/keyrings/nginx-archive-keyring.gpg
        /etc/apt/trusted.gpg.d/google-chrome.gpg
        /usr/share/keyrings/githubcli-archive-keyring.gpg
        /etc/apt/keyrings/gierens.gpg
        /usr/share/keyrings/tailscale-archive-keyring.gpg
    )
    for key in "${KEYS[@]}"; do
        rm -f "$key" && log_info "Removed $key" || true
    done

    rm -f /etc/apt/preferences.d/99nginx

    # Remove PPAs
    add-apt-repository --remove ppa:ondrej/php   -y 2>/dev/null || true
    add-apt-repository --remove ppa:git-core/ppa -y 2>/dev/null || true
    add-apt-repository --remove ppa:xtradeb/apps -y 2>/dev/null || true

    apt-get update -qq || true
    log_info "Repositories cleaned"
fi

# ─── 9. Security configurations ──────────────────────────────────────────────

if confirm "Restore security configurations (SSH, sysctl, fail2ban, modprobe, pwquality)?"; then
    log_section "Restoring security configurations"

    # SSH — restore from backup
    local_sshd_bak="/etc/ssh/sshd_config.bak"
    if [ -f "$local_sshd_bak" ]; then
        cp "$local_sshd_bak" /etc/ssh/sshd_config
        systemctl restart sshd 2>/dev/null || true
        log_info "SSH config restored from backup"
    else
        log_warn "No SSH backup found at $local_sshd_bak"
    fi

    rm -f /etc/sysctl.d/99-hardening.conf
    sysctl --system >/dev/null 2>&1 || true
    log_info "sysctl hardening removed"

    rm -f /etc/fail2ban/jail.d/ssh-custom.conf
    systemctl restart fail2ban 2>/dev/null || true
    log_info "fail2ban SSH jail removed"

    rm -f /etc/modprobe.d/disable-unused-fs.conf
    log_info "Filesystem disable rules removed"
fi

# ─── 10. Samba ───────────────────────────────────────────────────────────────

if confirm "Restore Samba config from backup?"; then
    log_section "Restoring Samba configuration"
    latest_bak=$(ls -t /etc/samba/smb.conf.bak.* 2>/dev/null | head -1)
    if [ -n "$latest_bak" ]; then
        cp "$latest_bak" /etc/samba/smb.conf
        systemctl restart smbd nmbd 2>/dev/null || true
        log_info "smb.conf restored from $latest_bak"
    else
        log_warn "No Samba backup found"
    fi
fi

if confirm "Remove Samba share directory (/srv/samba/shared)? THIS DELETES DATA."; then
    rm -rf /srv/samba/shared
    log_info "/srv/samba/shared removed"
fi

# ─── 11. UFW rules ───────────────────────────────────────────────────────────

if confirm "Remove UFW rules added by postinstall.sh (Samba, 80, 443)?"; then
    log_section "Removing UFW rules"
    ufw delete allow Samba   2>/dev/null || true
    ufw delete allow 80/tcp  2>/dev/null || true
    ufw delete allow 443/tcp 2>/dev/null || true
    log_info "UFW rules removed"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
log_section "Rollback complete"
log_info "Review /etc/ssh/sshd_config and /etc/samba/smb.conf if needed"
log_info "Reboot recommended to fully apply changes"
echo ""
