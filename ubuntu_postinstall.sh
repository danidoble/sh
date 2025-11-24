#!/bin/bash

# HOME -> user home directory

# Install dependencies
echo "Installing dependencies..."
# add ppa for php
sudo apt update
sudo apt upgrade -y
sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring software-properties-common apt-transport-https gpg wget -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
sudo curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
sudo rm -f microsoft.gpg
sudo  wget -O /usr/share/keyrings/dbeaver.gpg.key https://dbeaver.io/debs/dbeaver.gpg.key
curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | sudo gpg --dearmor --output /usr/share/keyrings/beekeeper.gpg \
  && sudo chmod go+r /usr/share/keyrings/beekeeper.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" \
  | sudo tee /etc/apt/sources.list.d/beekeeper-studio-app.list > /dev/null
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
  sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo tee /etc/apt/sources.list.d/mariadb.sources <<EOF
Types: deb
URIs: https://mirrors.accretive-networks.net/mariadb/repo/11.8/ubuntu
Suites: noble
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

sudo tee /etc/apt/sources.list.d/vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/google-chrome.gpg >/dev/null


sudo add-apt-repository ppa:ondrej/php -y
sudo add-apt-repository ppa:git-core/ppa -y
sudo add-apt-repository ppa:xtradeb/apps -y

sudo apt update
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx
sudo apt update

sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

sudo apt install -y nginx sqlite3 imagemagick php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip php8.1-bcmath php8.1-intl php8.1-imagick php8.1-redis php8.1-memcached php8.1-zip php8.1-xml php8.1-common php8.1-sqlite3 php8.1-pgsql php8.1-opcache php8.1-decimal php8.1-apcu php8.2-cli php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-intl php8.2-imagick php8.2-redis php8.2-memcached php8.2-zip php8.2-xml php8.2-common php8.2-sqlite3 php8.2-pgsql php8.2-opcache php8.2-decimal php8.2-apcu php8.3-cli php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-bcmath php8.3-intl php8.3-imagick php8.3-redis php8.3-memcached php8.3-zip php8.3-xml php8.3-common php8.3-sqlite3 php8.3-pgsql php8.3-opcache php8.3-decimal php8.3-apcu php8.4-cli php8.4-fpm php8.4-mysql php8.4-curl php8.4-gd php8.4-mbstring php8.4-xml php8.4-zip php8.4-bcmath php8.4-intl php8.4-imagick php8.4-redis php8.4-memcached php8.4-zip php8.4-xml php8.4-common php8.4-sqlite3 php8.4-pgsql php8.4-opcache php8.4-decimal php8.4-apcu php8.5-cli php8.5-fpm php8.5-mysql php8.5-curl php8.5-gd php8.5-mbstring php8.5-xml php8.5-zip php8.5-bcmath php8.5-intl php8.5-redis php8.5-zip php8.5-xml php8.5-common php8.5-sqlite3 redis docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git code dbeaver-ce beekeeper-studio brave-browser virt-manager flatpak gnome-software-plugin-flatpak filezilla webp ffmpeg gnome-shell-extension-manager gnome-tweaks chrome-gnome-shell google-chrome-stable build-essential antigravity libfuse2 libnss3-tools 

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo snap install vlc --classic
sudo snap install postman --classic
sudo snap install termius-app --classic
sudo snap install vault

sudo usermod -aG www-data nginx

sudo systemctl start php8.1-fpm.service
sudo systemctl enable php8.1-fpm.service

sudo systemctl start php8.2-fpm.service
sudo systemctl enable php8.2-fpm.service

sudo systemctl start php8.3-fpm.service
sudo systemctl enable php8.3-fpm.service

sudo systemctl start php8.4-fpm.service
sudo systemctl enable php8.4-fpm.service

sudo systemctl start php8.5-fpm.service
sudo systemctl enable php8.5-fpm.service

sudo systemctl enable redis-server
sudo systemctl start redis-server

sudo systemctl restart nginx

sudo systemctl start docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo newgrp docker


cd $HOME
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer

# Install nvm and bun as the original user (not as root)
# Get the original user if script is run with sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$USER
fi

# Install nvm as the real user
sudo -u $REAL_USER bash -c 'export NVM_DIR="$HOME/.nvm" && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install --lts'

# Install bun as the real user
sudo -u $REAL_USER bash -c 'curl -fsSL https://bun.sh/install | bash'

# If you want to install MariaDB, uncomment the next line:
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean -y


echo "Installation completed. Please restart your terminal or run 'source ~/.bashrc' to apply nvm."

#node -v
#npm -v
#php -v
#docker --version
