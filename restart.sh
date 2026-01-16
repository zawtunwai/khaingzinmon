#!/bin/bash
# ZIVPN Enterprise Management Services Restart Script - PRESERVE PASSWORDS VERSION
# Author: Gemini
set -euo pipefail

# ===== Pretty Colors =====
B="\e[1;34m"; G="\e[1;32m"; Y="\e[1;33m"; R="\e[1;31m"; C="\e[1;36m"; M="\e[1;35m"; Z="\e[0m"
LINE="${B}────────────────────────────────────────────────────────${Z}"
say(){ echo -e "$1"; }

echo -e "\n$LINE"
echo -e "${G}🔄 ZIVPN Enterprise Services Restarting...${Z}"
echo -e "$LINE"

# ===== Config Backup Function =====
backup_config() {
    CONFIG_FILE="/etc/zivpn/config.json"
    BACKUP_DIR="/etc/zivpn/backups"
    
    if [ -f "$CONFIG_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/config.backup.$TIMESTAMP.json"
        
        # Backup config
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        
        # Count passwords in current config
        if command -v jq >/dev/null 2>&1; then
            PASSWORD_COUNT=$(jq -r '.auth.config | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
        else
            PASSWORD_COUNT="Unknown (jq not installed)"
        fi
        
        say "${G}  📋 Config backed up: $BACKUP_FILE${Z}"
        say "${G}  📊 Current VPN passwords: $PASSWORD_COUNT${Z}"
        
        echo "$BACKUP_FILE"
    else
        say "${Y}  ⚠️ Config file not found: $CONFIG_FILE${Z}"
        echo ""
    fi
}

# ===== Config Restore Function =====
restore_config_if_corrupted() {
    CONFIG_FILE="/etc/zivpn/config.json"
    BACKUP_FILE="$1"
    
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        return 1
    fi
    
    # Check if config is corrupted or empty
    if [ ! -s "$CONFIG_FILE" ] || ! jq -e . "$CONFIG_FILE" >/dev/null 2>&1; then
        say "${Y}  🔄 Config corrupted, restoring from backup...${Z}"
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        return 0
    fi
    
    return 1
}

# ===== Function to Restart and Check Status =====
restart_service() {
    SERVICE_NAME=$1
    CONFIG_BACKUP="${2:-}"
    
    say "${C}* Restarting ${SERVICE_NAME}...${Z}"

    # Special handling for zivpn.service
    if [ "$SERVICE_NAME" = "zivpn.service" ]; then
        # Create temporary backup if not provided
        if [ -z "$CONFIG_BACKUP" ] && [ -f "/etc/zivpn/config.json" ]; then
            TEMP_BACKUP="/tmp/zivpn.config.temp.$(date +%s).json"
            cp /etc/zivpn/config.json "$TEMP_BACKUP"
            CONFIG_BACKUP="$TEMP_BACKUP"
        fi
    fi
    
    # Stop the service first (gracefully)
    if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
        say "${Y}  ⏳ Stopping ${SERVICE_NAME}...${Z}"
        sudo systemctl stop "${SERVICE_NAME}"
        sleep 2
    fi

    # Start/Restart the service
    if sudo systemctl restart "${SERVICE_NAME}"; then
        # Wait for service to start
        sleep 3
        
        # Check if service started successfully
        if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
            say "${G}  ✅ ${SERVICE_NAME} restarted and running.${Z}"
            
            # Special handling for zivpn.service
            if [ "$SERVICE_NAME" = "zivpn.service" ]; then
                # Verify config after restart
                if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
                    restore_config_if_corrupted "$CONFIG_BACKUP"
                    
                    # If config was restored, restart again
                    if [ $? -eq 0 ]; then
                        say "${Y}  🔄 Restarting with restored config...${Z}"
                        sudo systemctl restart zivpn.service
                        sleep 2
                    fi
                    
                    # Clean up temp backup
                    rm -f "$CONFIG_BACKUP" 2>/dev/null || true
                fi
                
                # Show final password count
                if [ -f "/etc/zivpn/config.json" ] && command -v jq >/dev/null 2>&1; then
                    FINAL_COUNT=$(jq -r '.auth.config | length' /etc/zivpn/config.json 2>/dev/null || echo "0")
                    say "${G}  📊 Final VPN passwords: $FINAL_COUNT${Z}"
                fi
            fi
            
        else
            say "${R}  ❌ ERROR: ${SERVICE_NAME} failed to start.${Z}"
            
            # Try config restore for zivpn if it failed
            if [ "$SERVICE_NAME" = "zivpn.service" ] && [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
                say "${Y}  🔧 Attempting emergency config restore...${Z}"
                cp "$CONFIG_BACKUP" /etc/zivpn/config.json
                sudo systemctl restart zivpn.service
                sleep 2
                
                if sudo systemctl is-active --quiet zivpn.service; then
                    say "${G}  ✅ Service recovered after config restore${Z}"
                fi
            fi
            
            # Show logs for debugging
            say "${Y}  📋 Checking logs...${Z}"
            sudo journalctl -u "${SERVICE_NAME}" --since "1 minute ago" --no-pager | tail -n 20
        fi
        
    else
        say "${R}  ❌ ERROR: Could not execute restart command for ${SERVICE_NAME}.${Z}"
    fi
}

# ===== Database Sync Check =====
check_database_sync() {
    say "${Y}* Checking database and config sync...${Z}"
    
    # Check if cleanup.py exists and can sync
    if [ -f "/etc/zivpn/cleanup.py" ]; then
        say "${Y}  🔄 Running password sync check...${Z}"
        
        # Get password counts
        if [ -f "/etc/zivpn/config.json" ] && command -v jq >/dev/null 2>&1; then
            CONFIG_COUNT=$(jq -r '.auth.config | length' /etc/zivpn/config.json 2>/dev/null || echo "0")
            
            if [ -f "/etc/zivpn/zivpn.db" ] && command -v sqlite3 >/dev/null 2>&1; then
                DB_COUNT=$(sqlite3 /etc/zivpn/zivpn.db "SELECT COUNT(DISTINCT password) FROM users WHERE password IS NOT NULL AND password != ''" 2>/dev/null || echo "0")
                
                say "${G}  📊 Database passwords: $DB_COUNT | Config passwords: $CONFIG_COUNT${Z}"
                
                if [ "$CONFIG_COUNT" -eq 0 ] && [ "$DB_COUNT" -gt 0 ]; then
                    say "${Y}  ⚠️  Config missing passwords! Running sync...${Z}"
                    python3 /etc/zivpn/cleanup.py 2>/dev/null || true
                fi
            fi
        fi
    fi
}

# ===== Main Execution =====

# Step 0: Backup config and check sync
CONFIG_BACKUP=$(backup_config)
check_database_sync

# Step 1: Restart core VPN service (zivpn.service)
# Must be done first as it handles traffic.
restart_service zivpn.service "$CONFIG_BACKUP"

# Step 2: Restart management components (API, Web)
# They rely on the database and core logic.
restart_service zivpn-api.service
restart_service zivpn-web.service

# Step 3: Restart Telegram bot
restart_service zivpn-bot.service

# Step 4: Restart connection manager
restart_service zivpn-connection.service

# Step 5: Trigger and ensure management timers/jobs are running
say "${Y}* Re-enabling and triggering periodic timers...${Z}"
sudo systemctl enable --now zivpn-backup.timer 2>/dev/null || true
sudo systemctl enable --now zivpn-maintenance.timer 2>/dev/null || true
say "${G}  ✅ Timers enabled/checked.${Z}"

# Step 6: Final status check
say "${Y}* Final service status check...${Z}"
ALL_SERVICES=("zivpn" "zivpn-api" "zivpn-web" "zivpn-bot" "zivpn-connection")
ALL_RUNNING=true

for service in "${ALL_SERVICES[@]}"; do
    if sudo systemctl is-active --quiet "${service}.service"; then
        say "${G}  ✅ ${service}.service: RUNNING${Z}"
    else
        say "${R}  ❌ ${service}.service: NOT RUNNING${Z}"
        ALL_RUNNING=false
    fi
done

# Final config verification
if [ -f "/etc/zivpn/config.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        FINAL_PASSWORD_COUNT=$(jq -r '.auth.config | length' /etc/zivpn/config.json 2>/dev/null || echo "0")
        
        echo -e "\n$LINE"
        echo -e "${G}✨ All ZIVPN Enterprise Services restart completed!${Z}"
        
        if [ "$FINAL_PASSWORD_COUNT" -eq 0 ]; then
            echo -e "${R}⚠️  WARNING: No VPN passwords in config!${Z}"
            echo -e "${Y}💡 Run: sudo python3 /etc/zivpn/cleanup.py${Z}"
            echo -e "${Y}💡 Or: sudo python3 /etc/zivpn/bot.py (if exists)${Z}"
        else
            echo -e "${G}✅ VPN Passwords preserved: $FINAL_PASSWORD_COUNT${Z}"
        fi
    else
        echo -e "\n$LINE"
        echo -e "${G}✨ All ZIVPN Enterprise Services restart completed!${Z}"
        echo -e "${Y}📋 Config preserved (jq not available for verification)${Z}"
    fi
else
    echo -e "\n$LINE"
    echo -e "${G}✨ All ZIVPN Enterprise Services restart completed!${Z}"
    echo -e "${R}⚠️  WARNING: Config file not found at /etc/zivpn/config.json${Z}"
fi

echo -e "$LINE"

# Final note
if [ "$ALL_RUNNING" = true ]; then
    echo -e "${G}✅ All services running successfully!${Z}"
else
    echo -e "${Y}⚠️  Some services may need manual intervention.${Z}"
fi
