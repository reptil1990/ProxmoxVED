#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: reptil1990
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/adminsyspro/proxcenter-ui

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  ca-certificates \
  curl \
  python3 \
  make \
  g++ \
  build-essential \
  libsqlite3-dev \
  openssl
msg_ok "Installed Dependencies"

msg_info "Installing Node.js 22"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js $(node -v)"

msg_info "Cloning ProxCenter-UI"
git clone --depth 1 https://github.com/adminsyspro/proxcenter-ui.git /opt/proxcenter >/dev/null 2>&1
cd /opt/proxcenter
RELEASE=$(git rev-parse --short HEAD)
echo "${RELEASE}" >/opt/proxcenter_version.txt
msg_ok "Cloned ProxCenter-UI (${RELEASE})"

msg_info "Installing npm Dependencies (this may take a while)"
cd /opt/proxcenter/frontend
$STD npm ci --legacy-peer-deps
$STD npm rebuild better-sqlite3
msg_ok "Installed npm Dependencies"

msg_info "Building Application"
$STD npx prisma generate
export NEXT_TELEMETRY_DISABLED=1
export NODE_ENV=production
mkdir -p /opt/proxcenter/frontend/data
$STD npm run build
msg_ok "Built Application"

msg_info "Configuring ProxCenter"
APP_SECRET=$(openssl rand -base64 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
IP_ADDR=$(hostname -I | awk '{print $1}')

cat <<EOF >/opt/proxcenter/frontend/.env
NODE_ENV=production
PORT=3000
HOSTNAME=0.0.0.0
DATABASE_URL=file:/opt/proxcenter/frontend/data/proxcenter.db
APP_SECRET=${APP_SECRET}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
NEXTAUTH_URL=http://${IP_ADDR}:3000
APP_URL=http://${IP_ADDR}:3000
EOF
chmod 600 /opt/proxcenter/frontend/.env

cd /opt/proxcenter/frontend
set -a
. /opt/proxcenter/frontend/.env
set +a
$STD node db-migrate.js
msg_ok "Configured ProxCenter"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/proxcenter.service
[Unit]
Description=ProxCenter UI
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/proxcenter/frontend
EnvironmentFile=/opt/proxcenter/frontend/.env
ExecStart=/usr/bin/node /opt/proxcenter/frontend/start.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now proxcenter
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
cleanup_lxc
