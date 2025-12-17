#!/bin/bash
# ZIVPN Enterprise Management Services Restart Script
# Author: Gemini
set -euo pipefail

# ===== Pretty Colors =====
B="\e[1;34m"; G="\e[1;32m"; Y="\e[1;33m"; R="\e[1;31m"; C="\e[1;36m"; M="\e[1;35m"; Z="\e[0m"
LINE="${B}────────────────────────────────────────────────────────${Z}"
say(){ echo -e "$1"; }

echo -e "\n$LINE"
echo -e "${G}🔄 ZIVPN Enterprise Services Restarting...${Z}"
echo -e "$LINE"

# ===== Function to Restart and Check Status =====
restart_service() {
    SERVICE_NAME=$1
    say "${C}* Restarting ${SERVICE_NAME}...${Z}"

    # Stop the service first
    if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
        sudo systemctl stop "${SERVICE_NAME}"
    fi

    # Start/Restart the service
    if sudo systemctl restart "${SERVICE_NAME}"; then
        # Wait a moment for the service to actually start up
        sleep 2
        
        if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
            say "${G}  ✅ ${SERVICE_NAME} restarted and running.${Z}"
        else
            say "${R}  ❌ ERROR: ${SERVICE_NAME} failed to start. Checking logs...${Z}"
            sudo journalctl -u "${SERVICE_NAME}" --since "30 seconds ago" | tail -n 10
            # Continue to next service even if one fails, but show error.
        fi
    else
        say "${R}  ❌ ERROR: Could not execute restart command for ${SERVICE_NAME}.${Z}"
    fi
}

# ===== Execution Order =====

# 1. Restart core VPN service (zivpn.service)
#    - Must be done first as it handles traffic.
restart_service zivpn.service

# 2. Restart management components (API, Web)
#    - They rely on the database and core logic.
restart_service zivpn-api.service
restart_service zivpn-web.service

# 3. Trigger and ensure management timers/jobs are running
#    - These are usually 'timers' but restarting the oneshot service ensures configuration is up-to-date.
say "${Y}* Re-enabling and triggering periodic timers...${Z}"
sudo systemctl enable --now zivpn-backup.timer 2>/dev/null || true
sudo systemctl enable --now zivpn-maintenance.timer 2>/dev/null || true
say "${G}  ✅ Timers enabled/checked.${Z}"

echo -e "\n$LINE"
echo -e "${G}✨ All ZIVPN Enterprise Services restart sequence completed!${Z}"
echo -e "$LINE"
