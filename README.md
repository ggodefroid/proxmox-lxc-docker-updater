# **Proxmox LXC Docker Updater**

This interactive Bash script simplifies the maintenance of Docker Compose services hosted in LXC containers on Proxmox VE.  
Instead of manually connecting to each container to update your stacks, this script scans your entire infrastructure, detects active projects, and allows you to bulk update them via a simple graphical interface.

## ** Installation & Quick Usage**

Simply run this command from the shell of your Proxmox host (the "Node", not inside an LXC):  
bash \-c "$(curl \-fsSL \[https://raw.githubusercontent.com/ggodefroid/proxmox-lxc-docker-updater/refs/heads/main/docker-compose-lxc-updater.sh\](https://raw.githubusercontent.com/ggodefroid/proxmox-lxc-docker-updater/refs/heads/main/docker-compose-lxc-updater.sh))"

## ** Features**

* **Automatic Scanning**: Iterates through all running LXC containers on your Proxmox node.  
* **Native Detection**: Uses the native docker compose ls API to accurately identify active stacks (avoiding false positives from file scans).  
* **Interactive Interface**: Displays a clear selection menu (Whiptail) to choose which services to update or skip.  
* **Clean Update Sequence**:  
  1. **Stop**: Cleanly stops services (docker compose stop).  
  2. **Pull**: Downloads the latest images (docker compose pull).  
  3. **Up \-d**: Recreates containers with the new images (docker compose up \-d).  
* **Safety**: Only touches services that are explicitly selected.

## **How it works**

* **Analysis**: The script connects sequentially to each LXC via pct exec.  
* **Verification**: It checks if Docker is installed and queries the list of active Compose projects.  
* **Selection**: A list of all found projects (format LXCName \- ProjectName) is presented. All are checked by default.  
* **Execution**: The script loops through your selection and executes the update commands directly inside the relevant containers.

## **Prerequisites**

* **Proxmox VE**: Tested on versions 7.x and 8.x.  
* **Docker Compose V2**: Your LXC containers must use the modern version of Docker Compose (docker compose, not docker-compose).  
* **Stack Status**: Your Docker stacks must be **active** (running) to be detected by the script.  
* *Tip: If a service doesn't appear, connect to the LXC and run docker compose up \-d manually once to register it.*

## **Contribution**

Contributions are welcome\! Feel free to open an "Issue" or a "Pull Request" if you have ideas for improvement.

1. Fork the project  
2. Create your branch (git checkout \-b feature/AmazingFeature)  
3. Commit your changes (git commit \-m 'Add some AmazingFeature')  
4. Push to the branch (git push origin feature/AmazingFeature)  
5. Open a Pull Request
