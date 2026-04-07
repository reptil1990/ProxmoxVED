#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: reptil1990
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/adminsyspro/proxcenter-ui

APP="ProxCenter-UI"
var_tags="${var_tags:-monitoring;proxmox}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/proxcenter ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping Service"
  systemctl stop proxcenter
  msg_ok "Stopped Service"

  msg_info "Updating ${APP}"
  cd /opt/proxcenter
  git fetch --all --tags >/dev/null 2>&1
  git reset --hard origin/main >/dev/null 2>&1
  cd /opt/proxcenter/frontend
  npm ci --legacy-peer-deps >/dev/null 2>&1
  npm rebuild better-sqlite3 >/dev/null 2>&1
  npx prisma generate >/dev/null 2>&1
  npm run build >/dev/null 2>&1
  node db-migrate.js >/dev/null 2>&1 || true
  msg_ok "Updated ${APP}"

  msg_info "Starting Service"
  systemctl start proxcenter
  msg_ok "Started Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
