#!/bin/bash

# Function to download the core file based on user selection
download_core() {
  local choice=$1
  local output="/root/backhaul"
  
  # URLs for different versions
  local url_old="https://raw.githubusercontent.com/0fariid0/Backhaul-multi/main/backhaul"
  local url_adm="https://raw.githubusercontent.com/0fariid0/Backhaul-multi/main/backhaul-amd"
  local url_arm="https://raw.githubusercontent.com/0fariid0/Backhaul-multi/main/backhaul-arm"
  
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
  tunnel_number=$1
  port_list=$2
  bind_port=$((1000 + tunnel_number)) # Example: bind_addr starts from port 1001

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
  tunnel_number=$1
  ip_ir=$2
  remote_port=$((1000 + tunnel_number)) # Example: remote_addr starts from port 1001

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
  service_name=$1
  toml_file=$2

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
  sudo systemctl enable $service_name.service
  sudo systemctl start $service_name.service
  echo "Service $service_name started."
}

# Function to convert port list to TOML format
convert_ports_to_toml_format() {
  ports=$1
  port_list=""
  
  # Convert each port to the format source_port=destination_port
  IFS=',' read -ra PORTS_ARR <<< "$ports"
  for i in "${!PORTS_ARR[@]}"; do
    port="${PORTS_ARR[$i]}"
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

  return_to_menu=false

  while true; do
    clear
    echo "Tunnel Service Status:"
    echo "---------------------------------------------"
    for i in {1..10}; do
      service_name="backhaul-tu$i"
      status=$(systemctl status $service_name 2>/dev/null | grep "Active:")

      if [[ -n $status ]]; then
        active_since=$(echo $status | sed -n 's/.*since \(.*\);.*/\1/p')
        uptime=$(echo $status | sed -n 's/.*since .*; \(.*\) ago/\1/p')

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
  sudo systemctl stop backhaul-tu$tunnel_number.service
  sudo systemctl disable backhaul-tu$tunnel_number.service
  rm -f /etc/systemd/system/backhaul-tu$tunnel_number.service
  [[ -f "/root/tu$tunnel_number.toml" ]] && rm -f /root/tu$tunnel_number.toml && echo "File tu$tunnel_number.toml removed."
  echo "Service backhaul-tu$tunnel_number removed."

  sudo systemctl daemon-reload
}

# Function to remove all tunnels
remove_all_tunnels() {
  echo "Removing all tunnels..."
  
  # Stop and disable all services
  for i in {1..10}; do
    sudo systemctl stop backhaul-tu$i.service
    sudo systemctl disable backhaul-tu$i.service
    rm -f /etc/systemd/system/backhaul-tu$i.service
    [[ -f "/root/tu$i.toml" ]] && rm -f /root/tu$i.toml && echo "File tu$i.toml removed."
  done

  # Remove the backhaul executable
  [[ -f "/root/backhaul" ]] && rm -f /root/backhaul && echo "Backhaul file removed."

  sudo systemctl daemon-reload
  echo "All files and services removed."
}

# Function to remove the core (backhaul executable and services)
remove_core() {
  echo "Removing backhaul core..."
  
  # Stop and disable all services
  for i in {1..10}; do
    sudo systemctl stop backhaul-tu$i.service
    sudo systemctl disable backhaul-tu$i.service
    rm -f /etc/systemd/system/backhaul-tu$i.service
  done
  
  # Remove the backhaul executable
  [[ -f "/root/backhaul" ]] && rm -f /root/backhaul && echo "Backhaul file removed."

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

  toml_file="/root/tu$tunnel_number.toml"
  service_name="backhaul-tu$tunnel_number.service"

  if [[ ! -f "$toml_file" ]]; then
    echo "TOML file for tunnel $tunnel_number does not exist!"
    return
  fi

  # Edit the TOML file with nano
  nano "$toml_file"

  # Restart the service after editing
  echo "Restarting service $service_name..."
  sudo systemctl restart "$service_name"
  if [[ $? -ne 0 ]]; then
    echo "Error restarting service $service_name!"
  else
    echo "Service $service_name restarted successfully."
  fi
}

# Function to view the logs of a specific tunnel
view_tunnel_logs() {
  echo "Available tunnels for viewing logs:"
  
  # Display available tunnel services
  for i in {1..10}; do
    if [[ -f "/root/tu$i.toml" ]]; then
      echo "Tunnel $i: /root/tu$i.toml"
    fi
  done
  
  # Select tunnel number to view logs
  read -p "Enter the tunnel number to view logs (1-10): " tunnel_number

  # Validate input
  if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
    echo "Invalid tunnel number! Please enter a number between 1 and 10."
    return
  fi

  service_name="backhaul-tu$tunnel_number.service"

  # Set up a trap to catch Ctrl+C and return to menu
  trap 'echo "Returning to the menu..."; return' SIGINT
  
  # View logs using journalctl and handle Ctrl+C to return to menu
  echo "Press Ctrl+C to return to the menu."
  sudo journalctl -u "$service_name" -e -f
}

# Function to reset a single service
reset_single_service() {
  read -p "Enter the tunnel number to reset (1-10): " tunnel_number

  # Validate input
  if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
    echo "Invalid tunnel number! Please enter a number between 1 and 10."
    return
  fi

  service_name="backhaul-tu$tunnel_number.service"
  
  # Restart the service
  echo "Restarting service $service_name..."
  sudo systemctl restart "$service_name"
  if [[ $? -ne 0 ]]; then
    echo "Error restarting service $service_name!"
  else
    echo "Service $service_name restarted successfully."
  fi
}

# Function to reset all services
reset_all_services() {
  echo "Restarting all tunnel services..."
  
  # Restart all services
  for i in {1..10}; do
    service_name="backhaul-tu$i.service"
    echo "Restarting $service_name..."
    sudo systemctl restart "$service_name"
    if [[ $? -ne 0 ]]; then
      echo "Error restarting service $service_name!"
    else
      echo "Service $service_name restarted successfully."
    fi
  done
}

# Main menu function for core installation
menu_core_installation() {
  echo "Please select the core version to download:"
  echo "1) Old version"
  echo "2) AMD version"
  echo "3) ARM version"
  
  read -p "Your choice: " core_choice
  
  # Call the download function with the user's choice
  download_core $core_choice
}

# Main menu function
menu() {
  echo "Please select an option:"
  echo "1) Install Core"
  echo "2) Iran"
  echo "3) Kharej"
  echo "4) Removal"
  echo "5) Monitoring"
  echo "6) Edit Tunnel"
  echo "7) View Logs"
  echo "8) Reset Services"
}

# Main loop
while true; do
  menu
  read -p "Your choice: " choice

  case $choice in
    1)
      echo "Install Core selected."
      menu_core_installation
      ;;
    2)
      echo "Iran selected."
      read -p "Enter the token for tunnels: " TOKEN
      read -p "Enter the tunnel numbers (e.g., 1 5 7): " -a tunnel_numbers

      for tunnel_number in "${tunnel_numbers[@]}"; do
        echo "For tunnel $tunnel_number, please enter the ports (e.g., 8080, 38753):"
        read -p "Ports for tunnel $tunnel_number: " ports
        
        # Convert ports to TOML format
        port_list=$(convert_ports_to_toml_format "$ports")

        # Create the TOML file for this tunnel
        create_toml_file $tunnel_number "$port_list"

        # Create and start the corresponding systemd service
        create_service "backhaul-tu$tunnel_number" "tu$tunnel_number.toml"
      done
      ;;
    3)
      echo "Kharej selected."
      read -p "Enter the token for tunnels: " TOKEN
      read -p "Enter the tunnel number: " tunnel_number
      read -p "Enter the Iran IP: " ip_ir

      # Validate input
      if [[ ! $tunnel_number =~ ^[1-9]$ && $tunnel_number -ne 10 ]]; then
        echo "Invalid tunnel number! Please enter a number between 1 and 10."
        continue
      fi

      if [[ -z $ip_ir ]]; then
        echo "IP address cannot be empty!"
        continue
      fi

      # Create the client TOML file for the tunnel
      create_client_toml_file $tunnel_number $ip_ir

      # Create and start the corresponding systemd service
      create_service "backhaul-tu$tunnel_number" "tu$tunnel_number.toml"
      ;;
    4)
      echo "Removal selected."
      echo "Select removal option:"
      echo "1) Remove single tunnel"
      echo "2) Remove all tunnels"
      echo "3) Remove core"
      read -p "Your choice: " removal_choice

      case $removal_choice in
        1)
          remove_single_tunnel
          ;;
        2)
          remove_all_tunnels
          ;;
        3)
          remove_core
          ;;
        *)
          echo "Invalid choice!"
          ;;
      esac
      ;;
    5)
      echo "Monitoring selected."
      monitor_tunnels
      ;;
    6)
      echo "Edit Tunnel selected."
      edit_tunnel_toml
      ;;
    7)
      echo "View Logs selected."
      view_tunnel_logs
      ;;
    8)
      echo "Reset Services selected."
      echo "Select reset option:"
      echo "1) Reset single service"
      echo "2) Reset all services"
      read -p "Your choice: " reset_choice

      case $reset_choice in
        1)
          reset_single_service
          ;;
        2)
          reset_all_services
          ;;
        *)
          echo "Invalid choice!"
          ;;
      esac
      ;;
    *)
      echo "Invalid choice!"
      ;;
  esac
done
