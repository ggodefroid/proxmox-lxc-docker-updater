#!/usr/bin/env bash

function header_info() {
  clear
  cat <<"EOF"
    ____             __             __  __          __      __
   / __ \____  _____/ /_____  _____/ / / /___  ____/ /___ _/ /____
  / / / / __ \/ ___/ //_/ _ \/ ___/ / / / __ \/ __  / __ `/ __/ _ \
 / /_/ / /_/ / /__/ ,< /  __/ /  / /_/ / /_/ / /_/ / /_/ / /_/  __/
/_____/\____/\___/_/|_|\___/_/   \____/ .___/\__,_/\__,_/\__/\___/
                                     /_/
EOF
}

set -eEuo pipefail
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
CM='\xE2\x9C\x94\033'

header_info
echo "Loading..."
whiptail --backtitle "Proxmox VE Docker Updater" --title "LXC Docker Compose Updater" --yesno "This script will scan LXCs for RUNNING Docker Compose projects using the native API and update them.\n(Stop -> Pull -> Up -d)\n\nProceed?" 10 68

NODE=$(hostname)
MENU_ITEMS=()
MSG_MAX_LENGTH=0

echo -e "${BL}[Info]${GN} Scanning LXC containers for Docker Compose projects...${CL}"

# 1. Scan LXC Containers
while read -r LXC_ID LXC_STATUS; do
  if [ "$LXC_STATUS" == "running" ]; then
    LXC_NAME=$(pct exec "$LXC_ID" hostname)
    
    if pct exec "$LXC_ID" -- bash -l -c "command -v docker" >/dev/null 2>&1; then
      
      COMPOSE_PROJECTS=$(pct exec "$LXC_ID" -- bash -l -c "docker compose ls | awk 'NR>1 {print \$1 \"|\" \$NF}'" 2>/dev/null || true)
      
      FOUND_COUNT=0
      if [ -n "$COMPOSE_PROJECTS" ]; then
        while IFS='|' read -r PROJ_NAME PROJ_FILE; do
            if [ -n "$PROJ_NAME" ] && [ -n "$PROJ_FILE" ]; then
                PROJ_DIR=$(dirname "$PROJ_FILE")
                TAG="${LXC_ID}:${PROJ_DIR}"
                ITEM="${LXC_NAME} - ${PROJ_NAME}"
                
                OFFSET=2
                ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
                MENU_ITEMS+=("$TAG" "$ITEM " "ON")
                FOUND_COUNT=$((FOUND_COUNT + 1))
            fi
        done <<< "$COMPOSE_PROJECTS"
      fi
      
      if [ "$FOUND_COUNT" -gt 0 ]; then
          echo -e "${BL}[Info]${GN} Found $FOUND_COUNT stacks in ${LXC_NAME} ($LXC_ID).${CL}"
      else
          CONTAINER_COUNT=$(pct exec "$LXC_ID" -- bash -l -c "docker ps -q | wc -l")
          if [ "$CONTAINER_COUNT" -gt 0 ]; then
             echo -e "${YW}[Warn] ${LXC_NAME}: No 'Compose Projects' detected, but $CONTAINER_COUNT containers are running.${CL}"
          fi
      fi
    fi
  fi
done < <(pct list | awk 'NR>1 {print $1, $2}')

if [ ${#MENU_ITEMS[@]} -eq 0 ]; then
    echo -e "${RD}[Error]${CL} No active Docker Compose projects found via 'docker compose ls'."
    echo -e "Tip: If your containers are running but not showing up, try running 'docker compose up -d' manually once inside the LXC to register them."
    exit 1
fi

# 2. User Selection Menu
CHOSEN_PROJECTS=$(whiptail --backtitle "Proxmox VE Docker Updater" --title "Select Services to Update" --checklist "\nUncheck services to SKIP updates:\n" 20 $((MSG_MAX_LENGTH + 15)) 10 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3 | tr -d '"')

if [ -z "$CHOSEN_PROJECTS" ]; then
    echo -e "${YW}[Info]${CL} No services selected. Exiting."
    exit 0
fi

# 3. Update Function
function update_compose_stack() {
    local lxc_id=$1
    local proj_dir=$2
    local lxc_name=$(pct exec "$lxc_id" hostname)
    
    header_info
    echo -e "${BL}[Info]${GN} Updating Stack in LXC ${BL}$lxc_name ($lxc_id)${CL}"
    echo -e "${YW}Path: ${CL}$proj_dir"
    echo ""

    echo -e "${BL}[1/3]${CL} Stopping services..."
    if pct exec "$lxc_id" -- bash -l -c "cd $proj_dir && docker compose stop"; then
        echo -e "${GN}${CM} Stopped.${CL}"
    else
        echo -e "${RD}[Error] Failed to stop services.${CL}"
        return
    fi

    echo -e "${BL}[2/3]${CL} Pulling images..."
    if pct exec "$lxc_id" -- bash -l -c "cd $proj_dir && docker compose pull"; then
         echo -e "${GN}${CM} Pulled.${CL}"
    else
         echo -e "${RD}[Error] Failed to pull images.${CL}"
         pct exec "$lxc_id" -- bash -l -c "cd $proj_dir && docker compose start"
         return
    fi

    echo -e "${BL}[3/3]${CL} Starting services (Up -d)..."
    if pct exec "$lxc_id" -- bash -l -c "cd $proj_dir && docker compose up -d"; then
        echo -e "${GN}${CM} Updated and Started.${CL}"
    else
        echo -e "${RD}[Error] Failed to start services.${CL}"
    fi
    
    sleep 2
}

# 4. Process Selections
for SELECTION in $CHOSEN_PROJECTS; do
    VMID=${SELECTION%%:*}
    PATH_DIR=${SELECTION#*:}
    
    update_compose_stack "$VMID" "$PATH_DIR"
done

header_info
echo -e "${GN}All selected Docker Compose services have been processed.${CL}\n"
