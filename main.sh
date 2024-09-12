#!/bin/bash

# Function to download a single file
download_file() {
  url=$1
  output=$2
  
  # Remove existing backhaul file
  echo "Removing existing backhaul..."
  rm -f /root/backhaul

  echo "Downloading $output..."
  wget $url -O $output
  if [[ $? -ne 0 ]]; then
    echo "Error downloading $output."
    exit 1
  fi
  echo "Download of $output completed."
  
  # Set executable permissions
  chmod +x /root/backhaul
  if [[ $? -ne 0 ]]; then
    echo "Error setting executable permission on backhaul."
    exit 1
  fi
  echo "Executable permission set for backhaul."
}

# Function to create a TOML file for each tunnel (for Iran)
create_toml_file_iran() {
  tunnel_number=$1
  ports=$2
  bind_port=$3
  
  cat <<EOF > /root/tu$tunnel_number.toml
[server]
bind_addr = "0.0.0.0:$bind_port"
transport = "tcp"
token = "$TOKEN"
channel_size = 2048
connection_pool = 32
nodelay = false
ports = [
$ports
]
EOF
  echo "TOML file tu$tunnel_number.toml created for Iran."
}

# Function to create a client TOML file (for Kharej)
create_toml_file_kharej() {
  tunnel_number=$1
  ip_ir=$2
  remote_port=$3
  
  cat <<EOF > /root/tu$tunnel_number.toml
[client]
remote_addr = "$ip_ir:$remote_port"
transport = "tcp"
token = "$TOKEN"
nodelay = false
EOF
  echo "Client TOML file tu$tunnel_number.toml created for Kharej."
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

# Port list for tunnels (for both Iran and Kharej)
declare -A PORTS=(
  [1]="8880"
  [2]="8080"
  [3]="2095"
  [4]="2052"
  [5]="2082"
  [6]="2086"
)

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
      echo "Choose your architecture:"
      echo "1) AMD"
      echo "2) ARM"
      read -p "Your choice: " arch_choice

      if [[ $arch_choice -eq 1 ]]; then
        download_file "https://github.com/0fariid0/Backhaul-multi/blob/main/backhaul-adm" "/root/backhaul"
      elif [[ $arch_choice -eq 2 ]]; then
        download_file "https://github.com/0fariid0/Backhaul-multi/blob/main/backhaul-arm" "/root/backhaul"
      else
        echo "Invalid choice!"
      fi
      ;;
    2)
      echo "Iran selected."
      read -p "Enter the token for tunnels: " TOKEN

      for tunnel_number in {1..6}; do
        port="${PORTS[$tunnel_number]}"
        create_toml_file_iran $tunnel_number "\"$port=$port\"" $port
        create_service "backhaul-tu$tunnel_number" "tu$tunnel_number.toml"
      done
      ;;
    3)
      echo "Kharej selected."
      read -p "Enter the token for tunnels: " TOKEN
      read -p "Enter the Iran IP: " ip_ir

      for tunnel_number in {1..6}; do
        remote_port="${PORTS[$tunnel_number]}"
        create_toml_file_kharej $tunnel_number $ip_ir $remote_port
        create_service "backhaul-tu$tunnel_number" "tu$tunnel_number.toml"
      done
      ;;
    4)
      echo "Removal selected."
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
