#!/bin/bash

# Function to update and upgrade the system
update_system() {
  echo "Updating and upgrading the system..."
  apt update && apt upgrade -y
}

# Function to download a single file
download_file() {
  url=$1
  output=$2
  echo "Downloading $output..."
  wget $url -O $output
  if [[ $? -ne 0 ]]; then
    echo "Error downloading $output."
    exit 1
  fi
  echo "Download of $output completed."
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
connection_pool = 32
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
  for port in "${PORTS_ARR[@]}"; do
    port_list+="\"$port=$port\",\n"
  done

  # Remove trailing comma and newline
  port_list=$(echo -e "$port_list" | sed '$ s/,$//')

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

    sleep 1
    
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

# Main menu function
menu() {
  echo "Please select an option:"
  echo "1) Install Core"
  echo "2) Iran"
  echo "3) Kharej"
  echo "4) Removal"
  echo "5) Monitoring"
}

# Main loop
while true; do
  menu
  read -p "Your choice: " choice

  case $choice in
    1)
      echo "Install Core selected."
      update_system
      if [[ ! -f "/root/backhaul" ]]; then
        download_file "https://github.com/0fariid0/bakulme/raw/main/backhaul" "/root/backhaul"
      else
        echo "Backhaul file already downloaded."
      fi
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
      read -p "Your choice: " removal_choice

      case $removal_choice in
        1)
          remove_single_tunnel
          ;;
        2)
          remove_all_tunnels
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
    *)
      echo "Invalid choice!"
      ;;
  esac
done
