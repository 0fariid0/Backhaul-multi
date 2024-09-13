#!/bin/bash

# Function to download the core file based on user selection
download_core() {
  local choice=$1
  local output="/root/backhaul"
  
  # URLs for different versions
  local url_old="https://github.com/0fariid0/Backhaul-multi/blob/main/backhaul"
  local url_adm="https://github.com/0fariid0/Backhaul-multi/blob/main/backhaul-amd"
  local url_arm="https://github.com/0fariid0/Backhaul-multi/blob/main/backhaul-arm"
  
  # Remove existing backhaul file
  echo "Removing existing backhaul..."
  rm -f "$output"
  
  # Set the download URL based on the user's choice
  case $choice in
    1)
      url=$url_old
      ;;
    2)
      url=$url_adm
      ;;
    3)
      url=$url_arm
      ;;
    *)
      echo "Invalid choice!"
      return 1
      ;;
  esac
  
  echo "Downloading backhaul from $url..."
  wget "$url" -O "$output"
  if [[ $? -ne 0 ]]; then
    echo "Error downloading backhaul."
    return 1
  fi
  echo "Download completed."
  
  # Set executable permissions
  chmod +x "$output"
  if [[ $? -ne 0 ]]; then
    echo "Error setting executable permission on backhaul."
    return 1
  fi
  echo "Executable permission set for backhaul."
}

# Function to create a TOML file for each tunnel
create_toml_file() {
  local tunnel_number=$1
  local port_list=$2
  local bind_port=$((1000 + tunnel_number)) # Example: bind_addr starts from port 1001

  cat <<EOF > /root/tu$tunnel_number.toml
[server]
bind_addr = "0.0.0.0:$bind_port"
transport = "tcp"
token = "$TOKEN"
channel_size = 2048
connection_pool = 16
nodelay = false
ports = [
$port_list
]
EOF
  echo "TOML file tu$tunnel_number.toml created."
}

# Function to create a client TOML file for each tunnel
create_client_toml_file() {
  local tunnel_number=$1
  local ip_ir=$2
  local remote_port=$((1000 + tunnel_number)) # Example: remote_addr starts from port 1001

  cat <<EOF > /root/tu$tunnel_number.toml
[client]
remote_addr = "$ip_ir:$remote_port"
transport = "tcp"
token = "$TOKEN"
nodelay = false
EOF
  echo "Client TOML file tu$tunnel_number.toml created."
}

# Function to create a systemd service for each tunnel
create_service() {
  local service_name=$1
  local toml_file=$2

  echo "Creating service for $toml_file..."

  cat <<EOF > /etc/systemd/system/$service_name.service
[Unit]
Description=Backhaul Reverse Tunnel Service - $service_name
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul -c /root/$toml_file
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  echo "Service $service_name created."

  sudo systemctl daemon-reload
  sudo systemctl enable "$service_name.service"
  sudo systemctl start "$service_name.service"
  echo "Service $service_name started."
}

# Function to convert port list to TOML format
convert_ports_to_toml_format() {
  local ports=$1
  local port_list=""
  
  # Convert each port to the format source_port=destination_port
  IFS=',' read -ra PORTS_ARR <<< "$ports"
  for i in "${!PORTS_ARR[@]}"; do
    local port="${PORTS_ARR[$i]}"
    port_list+="\"$port=$port\""
    
    # Add comma and newline only if it's not the last port
    if [[ $i -lt $((${#PORTS_ARR[@]} - 1)) ]]; then
      port_list+=",\n"
    fi
  done

  # Print the port list
  echo -e "$port_list"
}

# Function to monitor the status of tunnels
monitor_tunnels() {
  echo "Monitoring tunnel services..."
  
  # Set up a trap to handle Ctrl+C
  trap "echo 'Exiting monitoring...'; return_to_menu=true; break" SIGINT

  local return_to_menu=false

  while true; do
    clear
    echo "Tunnel Service Status:"
    echo "---------------------------------------------"
    for i in {1..10}; do
      local service_name="backhaul-tu$i"
      local status=$(systemctl status "$service_name" 2>/dev/null | grep "Active:")

      if [[ -n $status ]]; then
        local active_since=$(echo $status | sed -n 's/.*since \(.*\);.*/\1/p')
        local uptime=$(echo $status | sed -n 's/.*since .*; \(.*\) ago/\1/p')

        printf "Tunnel %-2d: %-25s %s\n" $i "$status" "$uptime"
        echo "---------------------------------------------"
      fi
    done

    sleep 10
    
    if [[ $return_to_menu == true ]]; then
      break
    fi
  done
}

# Function to remove a single tunnel
remove_single_tunnel() {
  read -p "Enter the tunnel number to remove (1-10): " tunnel_number

  # Validate input
  if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
    echo "Invalid tunnel number! Please enter a number between 1 and 10."
    return
  fi

  # Stop and disable the service for the specified tunnel
  sudo systemctl stop "backhaul-tu$tunnel_number.service"
  sudo systemctl disable "backhaul-tu$tunnel_number.service"
  rm -f "/etc/systemd/system/backhaul-tu$tunnel_number.service"
  [[ -f "/root/tu$tunnel_number.toml" ]] && rm -f "/root/tu$tunnel_number.toml" && echo "File tu$tunnel_number.toml removed."
  echo "Service backhaul-tu$tunnel_number removed."

  sudo systemctl daemon-reload
}

# Function to remove all tunnels
remove_all_tunnels() {
  echo "Removing all tunnels..."
  
  # Stop and disable all services
  for i in {1..10}; do
    sudo systemctl stop "backhaul-tu$i.service"
    sudo systemctl disable "backhaul-tu$i.service"
    rm -f "/etc/systemd/system/backhaul-tu$i.service"
    [[ -f "/root/tu$i.toml" ]] && rm -f "/root/tu$i.toml" && echo "File tu$i.toml removed."
  done

  # Remove the backhaul executable
  [[ -f "/root/backhaul" ]] && rm -f "/root/backhaul" && echo "Backhaul file removed."

  sudo systemctl daemon-reload
  echo "All files and services removed."
}

# Function to remove the core (backhaul executable and services)
remove_core() {
  echo "Removing backhaul core..."
  
  # Stop and disable all services
  for i in {1..10}; do
    sudo systemctl stop "backhaul-tu$i.service"
    sudo systemctl disable "backhaul-tu$i.service"
    rm -f "/etc/systemd/system/backhaul-tu$i.service"
  done
  
  # Remove the backhaul executable
  [[ -f "/root/backhaul" ]] && rm -f "/root/backhaul" && echo "Backhaul file removed."

  sudo systemctl daemon-reload
  echo "Backhaul core removed."
}

# Function to edit a tunnel's TOML file
edit_tunnel_toml() {
  echo "Available tunnels for editing:"
  
  # Display available tunnel TOML files
  for i in {1..10}; do
    if [[ -f "/root/tu$i.toml" ]]; then
      echo "Tunnel $i: /root/tu$i.toml"
    fi
  done
  
  # Select tunnel number to edit
  read -p "Enter the tunnel number to edit (1-10): " tunnel_number

  # Validate input
  if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
    echo "Invalid tunnel number! Please enter a number between 1 and 10."
    return
  fi

  local toml_file="/root/tu$tunnel_number.toml"
  local service_name="backhaul-tu$tunnel_number.service"

  if [[ ! -f "$toml_file" ]]; then
    echo "TOML file for tunnel $tunnel_number does not exist!"
    return
  fi

  # Edit the TOML file with nano
  nano "$toml_file"

  # Restart the service after editing
  echo "Restarting service $service_name..."
  sudo systemctl restart "$service_name"
  echo "Service $service_name restarted."
}

# Function to view tunnel logs
view_tunnel_logs() {
  echo "Available tunnel logs:"
  
  # Display available tunnel logs
  for i in {1..10}; do
    if [[ -f "/var/log/backhaul-tu$i.log" ]]; then
      echo "Tunnel $i: /var/log/backhaul-tu$i.log"
    fi
  done

  # Select tunnel log to view
  read -p "Enter the tunnel number to view log (1-10): " tunnel_number

  # Validate input
  if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
    echo "Invalid tunnel number! Please enter a number between 1 and 10."
    return
  fi

  local log_file="/var/log/backhaul-tu$tunnel_number.log"

  if [[ ! -f "$log_file" ]]; then
    echo "Log file for tunnel $tunnel_number does not exist!"
    return
  fi

  # Display the log file
  cat "$log_file"
}

# Main menu
while true; do
  clear
  echo "Backhaul Service Management"
  echo "1. Download Core"
  echo "2. Create TOML Files"
  echo "3. Create Services"
  echo "4. Monitor Tunnels"
  echo "5. Remove Single Tunnel"
  echo "6. Remove All Tunnels"
  echo "7. Remove Core"
  echo "8. Edit Tunnel TOML File"
  echo "9. View Tunnel Logs"
  echo "0. Exit"
  read -p "Select an option: " option

  case $option in
    1)
      read -p "Enter your choice (1: Old, 2: AMD, 3: ARM): " choice
      download_core "$choice"
      ;;
    2)
      for i in {1..10}; do
        read -p "Enter port list for tunnel $i (comma-separated): " ports
        port_list=$(convert_ports_to_toml_format "$ports")
        create_toml_file "$i" "$port_list"
      done
      ;;
    3)
      for i in {1..10}; do
        read -p "Enter IP address for tunnel $i: " ip_ir
        create_client_toml_file "$i" "$ip_ir"
        create_service "backhaul-tu$i" "tu$i.toml"
      done
      ;;
    4)
      monitor_tunnels
      ;;
    5)
      remove_single_tunnel
      ;;
    6)
      remove_all_tunnels
      ;;
    7)
      remove_core
      ;;
    8)
      edit_tunnel_toml
      ;;
    9)
      view_tunnel_logs
      ;;
    0)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid option!"
      ;;
  esac
done
