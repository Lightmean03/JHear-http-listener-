#!/bin/bash
# server-manager.sh - Management script for the HTTP server service

SERVICE_NAME="http-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONFIG_FILE="/opt/http-server/config.json"
DEFAULT_PORT=8080
DEFAULT_LOG_PATH="/var/log/http_server.log"

# Determine appropriate user for service (should match what install.sh detects)
if id apache >/dev/null 2>&1; then
  SERVICE_USER="apache"
elif id nginx >/dev/null 2>&1; then
  SERVICE_USER="nginx"
elif id www-data >/dev/null 2>&1; then
  SERVICE_USER="www-data"
else
  # Fall back to current user
  SERVICE_USER="$(logname || echo $SUDO_USER || echo $USER)"
fi

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{\"port\": $DEFAULT_PORT, \"log_path\": \"$DEFAULT_LOG_PATH\"}" > "$CONFIG_FILE"
  chown $SERVICE_USER:$(id -gn $SERVICE_USER) "$CONFIG_FILE"
fi

# Update service file based on config
update_service_file() {
  local port=$(jq -r '.port' "$CONFIG_FILE")
  local log_path=$(jq -r '.log_path' "$CONFIG_FILE")
  
  # Update service file
  sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 /opt/http-server/server.py --port $port --log $log_path|g" "$SERVICE_FILE"
  
  echo "Service file updated. Reloading systemd configuration..."
  systemctl daemon-reload
}

# Function to check if port is already in use
is_port_in_use() {
  local port=$1
  if ss -tuln | grep -q ":$port " 2>/dev/null || netstat -tuln | grep -q ":$port " 2>/dev/null; then
    return 0  # Port is in use
  else
    return 1  # Port is free
  fi
}

# Change server port
change_port() {
  local new_port=$1
  
  # Validate port
  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
    echo "Error: Invalid port number. Must be between 1 and 65535."
    return 1
  fi
  
  # Check if port is in use
  if is_port_in_use "$new_port"; then
    echo "Error: Port $new_port is already in use."
    return 1
  fi
  
  # Update config
  local temp=$(mktemp)
  jq ".port = $new_port" "$CONFIG_FILE" > "$temp" && mv "$temp" "$CONFIG_FILE"
  chown $SERVICE_USER:$(id -gn $SERVICE_USER) "$CONFIG_FILE"
  
  update_service_file
  echo "Port changed to $new_port. Restart the service to apply changes."
}

# Open additional port
open_port() {
  local port=$1
  
  # Validate port
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Error: Invalid port number. Must be between 1 and 65535."
    return 1
  fi
  
  # Check if port is in use
  if is_port_in_use "$port"; then
    echo "Error: Port $port is already in use."
    return 1
  fi
  
  # Detect and use available firewall
  if command -v ufw >/dev/null 2>&1; then
    ufw allow "$port/tcp"
    echo "Port $port opened in ufw firewall."
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="$port/tcp"
    firewall-cmd --reload
    echo "Port $port opened in firewalld."
  elif command -v iptables >/dev/null 2>&1; then
    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    echo "Port $port opened in iptables temporarily."
    echo "Note: This rule will be lost on system reboot unless you save iptables rules."
  else
    echo "No supported firewall detected. You may need to open port $port manually."
  fi
}

# List open ports
list_ports() {
  echo "Listening TCP ports:"
  
  # Try different port listing tools based on what's available
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | grep LISTEN | grep -E ':[0-9]+' | sort -n -t: -k2
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | grep LISTEN | sort -n -t: -k2
  elif command -v lsof >/dev/null 2>&1; then
    lsof -i -P -n | grep LISTEN
  else
    echo "No port listing tools found (ss, netstat, lsof). Unable to list ports."
  fi
  
  echo -e "\nFirewall status:"
  if command -v ufw >/dev/null 2>&1; then
    echo "UFW firewall:"
    ufw status
  fi
  
  if command -v firewall-cmd >/dev/null 2>&1; then
    echo "Firewalld:"
    firewall-cmd --list-all
  fi
  
  if command -v iptables >/dev/null 2>&1 && ! command -v ufw >/dev/null 2>&1 && ! command -v firewall-cmd >/dev/null 2>&1; then
    echo "IPTables rules:"
    iptables -L -n | grep -E 'ACCEPT|REJECT|DROP'
  fi
  
  if ! command -v ufw >/dev/null 2>&1 && ! command -v firewall-cmd >/dev/null 2>&1 && ! command -v iptables >/dev/null 2>&1; then
    echo "No supported firewall detected."
  fi
}

# Change log location
change_log_location() {
  local new_log_path=$1
  
  # Create log file if it doesn't exist
  touch "$new_log_path"
  chown $SERVICE_USER:$(id -gn $SERVICE_USER) "$new_log_path"
  
  # Update config
  local temp=$(mktemp)
  jq ".log_path = \"$new_log_path\"" "$CONFIG_FILE" > "$temp" && mv "$temp" "$CONFIG_FILE"
  chown $SERVICE_USER:$(id -gn $SERVICE_USER) "$CONFIG_FILE"
  
  update_service_file
  echo "Log location changed to $new_log_path. Restart the service to apply changes."
}

# View logs
view_logs() {
  local log_path=$(jq -r '.log_path' "$CONFIG_FILE")
  local lines=${1:-50}
  
  if [ -f "$log_path" ]; then
    tail -n "$lines" "$log_path"
  else
    echo "Log file not found at $log_path"
    echo "Checking journal logs instead:"
    journalctl -u "$SERVICE_NAME" -n "$lines"
  fi
}

# Start the server
start_server() {
  systemctl start "$SERVICE_NAME"
  echo "Server started. Status:"
  systemctl status "$SERVICE_NAME" --no-pager
}

# Stop the server
stop_server() {
  systemctl stop "$SERVICE_NAME"
  echo "Server stopped."
}

# Restart the server
restart_server() {
  systemctl restart "$SERVICE_NAME"
  echo "Server restarted. Status:"
  systemctl status "$SERVICE_NAME" --no-pager
}

# Print usage information
print_usage() {
  echo "HTTP Server Manager - Usage:"
  echo "  $0 start          - Start the server"
  echo "  $0 stop           - Stop the server"
  echo "  $0 restart        - Restart the server"
  echo "  $0 status         - Check server status"
  echo "  $0 port <number>  - Change server port"
  echo "  $0 open <number>  - Open additional port in firewall"
  echo "  $0 ports          - List open ports"
  echo "  $0 log-path <path> - Change log file location"
  echo "  $0 logs [lines]   - View logs (default: last 50 lines)"
  echo "  $0 help           - Show this help message"
}

# Main command processing
case "$1" in
  start)
    start_server
    ;;
  stop)
    stop_server
    ;;
  restart)
    restart_server
    ;;
  status)
    systemctl status "$SERVICE_NAME" --no-pager
    ;;
  port)
    if [ -z "$2" ]; then
      echo "Error: Port number required."
      print_usage
      exit 1
    fi
    change_port "$2"
    ;;
  open)
    if [ -z "$2" ]; then
      echo "Error: Port number required."
      print_usage
      exit 1
    fi
    open_port "$2"
    ;;
  ports)
    list_ports
    ;;
  log-path)
    if [ -z "$2" ]; then
      echo "Error: Log path required."
      print_usage
      exit 1
    fi
    change_log_location "$2"
    ;;
  logs)
    view_logs "${2:-50}"
    ;;
  help)
    print_usage
    ;;
  *)
    print_usage
    ;;
esac

exit 0
