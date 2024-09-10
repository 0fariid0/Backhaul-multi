#!/bin/bash

# Define the output file
OUTPUT_FILE="/root/tunnel_bandwidth.log"

# Function to convert ports to TOML format
convert_ports_to_toml_format() {
  local ports_str="$1"
  local formatted_ports=""
  IFS=',' read -r -a ports <<< "$ports_str"
  for port in "${ports[@]}"; do
    formatted_ports+="$port=$port\",\n"
  done
  echo "[\"${formatted_ports%,}]"
}

# Function to create a TOML file for a given tunnel
create_toml_file() {
  local tunnel_number=$1
  local ports=$2

  cat <<EOF > /root/tu$tunnel_number.toml
[server]
bind_addr = "0.0.0.0:100$tunnel_number"
transport = "tcp"
token = "adfadlkadgkgad"
channel_size = 2048
connection_pool = 16
nodelay = false
ports = $ports
EOF
}

# Function to create a client TOML file for a given tunnel
create_client_toml_file() {
  local tunnel_number=$1
  local ip_ir=$2

  cat <<EOF > /root/tu$tunnel_number.toml
[client]
remote_addr = "$ip_ir:100$tunnel_number"
transport = "tcp"
token = "Farid@1380"
nodelay = false
EOF
}

# Function to create and start a systemd service for a given TOML file
create_service() {
  local service_name=$1
  local toml_file=$2

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

  sudo systemctl daemon-reload
  sudo systemctl enable $service_name.service
  sudo systemctl start $service_name.service
  echo "Service $service_name started."
}

# Function to monitor bandwidth
monitor_bandwidth() {
  echo "Monitoring bandwidth..."
  while true; do
    clear
    echo "Tunnel Service Status:"
    echo "---------------------------------------------"
    
    for i in {1..6}; do
      service_name="backhaul-tu$i"
      
      # Check if the service is active
      status=$(systemctl is-active $service_name)
      if [[ $status == "active" ]]; then
        echo -n "Tunnel $i: "
        
        # Define the ports for this tunnel (you need to update these as necessary)
        case $i in
          1) ports="8080,38753" ;;
          2) ports="9090,47753" ;;
          3) ports="10080,56753" ;;
          4) ports="20080,67753" ;;
          5) ports="30080,78753" ;;
          6) ports="40080,89753" ;;
        esac
        
        # Get the bandwidth usage for the specified ports
        total_rx=$(tcpdump -i any -nn -tttt -c 1000 | grep -Eo "(\d+\.\d+\.\d+\.\d+:[0-9]+)" | grep -E -o ":[0-9]+" | awk -F: '{print $2}' | grep -E "^($ports)$" | awk '{s+=$1} END {print s}')
        
        # Convert to megabits per second (1 byte = 8 bits)
        total_rx_mbps=$(echo "scale=2; $total_rx / 1024 / 1024 * 8" | bc)
        
        echo "Bandwidth: ${total_rx_mbps} Mbps"
        echo "---------------------------------------------"
      else
        echo "Tunnel $i: Service not running"
        echo "---------------------------------------------"
      fi
    done

    sleep 1
  done
}

# Main menu function
menu() {
  echo "Please select an option:"
  echo "1) Install Core"
  echo "2) Iran"
  echo "3) Kharej"
  echo "4) Full removal"
  echo "5) Monitoring"
}

# Main loop
while true; do
  menu
  read -p "Your choice: " choice

  case $choice in
    1)
      echo "Install Core selected."
      if [[ ! -f "/root/backhaul" ]]; then
        download_file "https://github.com/0fariid0/bakulme/raw/main/backhaul" "/root/backhaul"
      else
        echo "Backhaul file already downloaded."
      fi
      ;;
    2)
      echo "Iran selected."
      read -p "How many tunnels do you want to create? " tunnel_count

      for i in $(seq 1 $tunnel_count); do
        echo "For tunnel $i, please enter the ports (e.g., 8080, 38753):"
        read -p "Ports for tunnel $i: " ports
        
        # Convert ports to TOML format
        port_list=$(convert_ports_to_toml_format "$ports")

        # Create the TOML file for this tunnel
        create_toml_file $i "$port_list"

        # Create and start the corresponding systemd service
        create_service "backhaul-tu$i" "tu$i.toml"
      done
      ;;
    3)
      echo "Kharej selected."
      read -p "Enter the tunnel number: " tunnel_number
      read -p "Enter the Iran IP: " ip_ir

      # Validate input
      if [[ ! $tunnel_number =~ ^[1-6]$ ]]; then
        echo "Invalid tunnel number! Please enter a number between 1 and 6."
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
      echo "Full removal selected."
      echo "Removing files and services..."

      # Remove the backhaul executable
      [[ -f "/root/backhaul" ]] && rm -f /root/backhaul && echo "Backhaul file removed."

      # Remove services and TOML files for each tunnel
      for i in {1..6}; do
        sudo systemctl stop backhaul-tu$i.service
        sudo systemctl disable backhaul-tu$i.service
        rm -f /etc/systemd/system/backhaul-tu$i.service
        [[ -f "/root/tu$i.toml" ]] && rm -f /root/tu$i.toml && echo "File tu$i.toml removed."
        echo "Service backhaul-tu$i removed."
      done

      sudo systemctl daemon-reload
      echo "All files and services removed."
      ;;
    5)
      monitor_bandwidth
      ;;
    *)
      echo "Invalid choice!"
      ;;
  esac
done
