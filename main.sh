#!/bin/bash

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

# Function to download and extract ZIP files
download_and_extract_zip() {
  url=$1
  output=$2
  echo "Downloading $output..."
  wget $url -O $output
  if [[ $? -ne 0 ]]; then
    echo "Error downloading $output."
    exit 1
  fi
  echo "Download of $output completed."

  echo "Extracting $output..."
  unzip $output
  if [[ $? -eq 0 ]]; then
    echo "Extraction of $output completed."
    echo "Removing the ZIP file $output..."
    rm -f $output
    echo "$output removed."
  else
    echo "Error extracting $output."
    exit 1
  fi
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
token = "adfadlkadgkgad"
channel_size = 2048
connection_pool = 16
nodelay = false
ports = [
$port_list
]
EOF
  echo "TOML file tu$tunnel_number.toml created."
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

# Main menu function
menu() {
  echo "Please select an option:"
  echo "1) Install Core"
  echo "2) Iran"
  echo "3) Abroad"
  echo "4) Full removal"
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
        echo "For tunnel $i, please enter the ports (e.g., 8080=8080, 38753=38753):"
        read -p "Ports for tunnel $i: " ports
        port_list=""
        
        # Create port list with proper formatting for TOML
        IFS=',' read -ra PORTS_ARR <<< "$ports"
        for port in "${PORTS_ARR[@]}"; do
          port_list+="\"$port\",\n"
        done
        port_list=${port_list%,}  # Remove trailing comma

        # Create the TOML file for this tunnel
        create_toml_file $i "$port_list"

        # Create and start the corresponding systemd service
        create_service "backhaul-tu$i" "tu$i.toml"
      done
      ;;
    3)
      echo "Abroad selected."
      download_and_extract_zip "https://github.com/0fariid0/bakulme/raw/main/kh.zip" "kh.zip"

      read -p "Enter abroad number (1 to 6): " external_number
      if [[ $external_number =~ ^[1-6]$ ]]; then
        service_name="backhaul-tu$external_number"
        toml_file="tu$external_number.toml"
        create_service $service_name $toml_file
      else
        echo "Invalid number! Please enter a number between 1 and 6."
      fi
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
    *)
      echo "Invalid choice!"
      ;;
  esac
done
