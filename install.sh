#!/bin/bash
# install.sh - Main installation script for Jarvis Ears HTTP server
#
# This script installs the core components and dependencies for the Jarvis Ears HTTP server.
# After running this script, run setup-user.sh to create the lil-duck user and configure the service.

# Make sure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

echo "===== Jarvis Ears HTTP Server Installation Script ====="
echo "This will install the Jarvis Ears HTTP server components."

# Setup variables
INSTALL_DIR="/opt/jarvis-ears"
SERVICE_NAME="jarvis-ears"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
MANAGER_SCRIPT="/usr/local/bin/jarvis-manager"
DEFAULT_PORT=8080
DEFAULT_LOG_PATH="/var/log/jarvis-ears.log"
SERVICE_USER="lil-duck"

# Step 1: Check for dependencies
echo -e "\n[1/6] Checking dependencies..."

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for Python3
if ! command_exists python3; then
  echo "Python3 is not installed. We'll try to install it."
  INSTALL_PYTHON=true
else
  echo "✓ Python3 is installed"
  INSTALL_PYTHON=false
fi

# Check for jq
if ! command_exists jq; then
  echo "jq is not installed. We'll try to install it."
  INSTALL_JQ=true
else
  echo "✓ jq is installed"
  INSTALL_JQ=false
fi

# Detect package manager
if command_exists apt-get; then
  PKG_MANAGER="apt"
  INSTALL_CMD="apt-get install -y"
elif command_exists dnf; then
  PKG_MANAGER="dnf"
  INSTALL_CMD="dnf install -y"
elif command_exists yum; then
  PKG_MANAGER="yum"
  INSTALL_CMD="yum install -y"
elif command_exists pacman; then
  PKG_MANAGER="pacman"
  INSTALL_CMD="pacman -S --noconfirm"
elif command_exists zypper; then
  PKG_MANAGER="zypper"
  INSTALL_CMD="zypper install -y"
elif command_exists apk; then
  PKG_MANAGER="apk"
  INSTALL_CMD="apk add"
else
  echo "Warning: No supported package manager found. You may need to install dependencies manually."
  PKG_MANAGER="none"
fi

# Install required packages if needed
if [ "$PKG_MANAGER" != "none" ]; then
  echo "Detected package manager: $PKG_MANAGER"
  
  # Update package lists if using apt
  if [ "$PKG_MANAGER" = "apt" ]; then
    apt-get update
  fi
  
  # Install Python3 if needed
  if [ "$INSTALL_PYTHON" = true ]; then
    echo "Installing Python3..."
    case $PKG_MANAGER in
      apt) $INSTALL_CMD python3 python3-pip ;;
      dnf|yum) $INSTALL_CMD python3 python3-pip ;;
      pacman) $INSTALL_CMD python python-pip ;;
      zypper) $INSTALL_CMD python3 python3-pip ;;
      apk) $INSTALL_CMD python3 py3-pip ;;
    esac
  fi
  
  # Install jq if needed
  if [ "$INSTALL_JQ" = true ]; then
    echo "Installing jq..."
    $INSTALL_CMD jq
  fi
else
  echo "Warning: Please ensure Python3 and jq are installed manually."
fi

# Step 2: Create the service user
echo -e "\n[2/6] Creating service user '$SERVICE_USER'..."
if id -u "$SERVICE_USER" >/dev/null 2>&1; then
  echo "User $SERVICE_USER already exists. Skipping user creation."
else
  # Determine the right command to use based on the system
  if command -v useradd >/dev/null 2>&1; then
    # Create system user without home directory
    useradd -r -s /sbin/nologin "$SERVICE_USER"
  elif command -v adduser >/dev/null 2>&1; then
    # For Debian-based systems
    adduser --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
  else
    echo "Error: Cannot create user - no useradd or adduser command found"
    exit 1
  fi
  echo "User $SERVICE_USER created successfully."
fi

# Step 3: Create directories and files
echo -e "\n[3/6] Creating directories and files..."
mkdir -p "$INSTALL_DIR"

# Create server.py
cat > "$INSTALL_DIR/server.py" << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import logging
import argparse
from datetime import datetime

# Parse command line arguments
parser = argparse.ArgumentParser(description='Jarvis Ears HTTP Server')
parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
parser.add_argument('--log', type=str, default='/var/log/jarvis-ears.log', help='Log file path')
args = parser.parse_args()

# Set up logging
logging.basicConfig(
    filename=args.log,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class RequestHandler(BaseHTTPRequestHandler):
    def _set_response(self, status_code=200):
        self.send_response(status_code)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
    def do_GET(self):
        logging.info(f"GET request received at {self.path} from {self.client_address[0]}")
        self._set_response()
        response = {'message': 'Jarvis Ears is listening', 'time': str(datetime.now())}
        self.wfile.write(json.dumps(response).encode('utf-8'))
        
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        logging.info(f"POST request received at {self.path} from {self.client_address[0]}")
        
        # Process the POST data
        try:
            data = json.loads(post_data.decode('utf-8'))
            logging.info(f"POST data: {json.dumps(data)}")
            response = {'status': 'success', 'message': 'Data received successfully'}
            status_code = 200
        except json.JSONDecodeError:
            logging.error(f"Invalid JSON received: {post_data.decode('utf-8')}")
            response = {'status': 'error', 'message': 'Invalid JSON data'}
            status_code = 400
        
        self._set_response(status_code)
        self.wfile.write(json.dumps(response).encode('utf-8'))

def run(server_class=HTTPServer, handler_class=RequestHandler, port=8080):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    logging.info(f'Starting Jarvis Ears HTTP server on port {port}...')
    print(f'Server started on port {port}. Press Ctrl+C to stop.')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info('Jarvis Ears HTTP server stopped')

if __name__ == '__main__':
    run(port=args.port)
EOF
chmod +x "$INSTALL_DIR/server.py"
echo "Created server.py"

# Create config file
echo "{\"port\": $DEFAULT_PORT, \"log_path\": \"$DEFAULT_LOG_PATH\"}" > "$INSTALL_DIR/config.json"
echo "Created config.json"

# Create log file
touch "$DEFAULT_LOG_PATH"
echo "Created log file"

# Step 4: Create service file
echo -e "\n[4/6] Creating service file..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Jarvis Ears HTTP Server for POST Requests
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/server.py --port $DEFAULT_PORT --log $DEFAULT_LOG_PATH
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

# Security settings
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
echo "Created service file at $SERVICE_FILE"

# Step 5: Create manager script
echo -e "\n[5/6] Creating manager script..."
cat > "$MANAGER_SCRIPT" << 'EOF'
#!/bin/bash
# jarvis-manager.sh - Management script for the Jarvis Ears HTTP server service

SERVICE_NAME="jarvis-ears"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONFIG_FILE="/opt/jarvis-ears/config.json"
DEFAULT_PORT=8080
DEFAULT_LOG_PATH="/var/log/jarvis-ears.log"
SERVICE_USER="lil-duck"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{\"port\": $DEFAULT_PORT, \"log_path\": \"$DEFAULT_LOG_PATH\"}" > "$CONFIG_FILE"
  chown $SERVICE_USER:$SERVICE_USER "$CONFIG_FILE"
fi

# Update service file based on config
update_service_file() {
  local port=$(jq -r '.port' "$CONFIG_FILE")
  local log_path=$(jq -r '.log_path' "$CONFIG_FILE")
  
  # Update service file
  sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 /opt/jarvis-ears/server.py --port $port --log $log_path|g" "$SERVICE_FILE"
  
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
  chown $SERVICE_USER:$SERVICE_USER "$CONFIG_FILE"
  
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
  chown $SERVICE_USER:$SERVICE_USER "$new_log_path"
  
  # Update config
  local temp=$(mktemp)
  jq ".log_path = \"$new_log_path\"" "$CONFIG_FILE" > "$temp" && mv "$temp" "$CONFIG_FILE"
  chown $SERVICE_USER:$SERVICE_USER "$CONFIG_FILE"
  
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
  echo "Jarvis Ears Manager - Usage:"
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
EOF
chmod +x "$MANAGER_SCRIPT"
echo "Created manager script at $MANAGER_SCRIPT"

# Step 6: Set permissions and configure firewall
echo -e "\n[6/6] Setting permissions and configuring firewall..."
# Set permissions
chmod +x "$INSTALL_DIR/server.py"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"
chown "$SERVICE_USER":"$SERVICE_USER" "$DEFAULT_LOG_PATH"

# Configure firewall
if command_exists ufw; then
  ufw allow "$DEFAULT_PORT/tcp"
  echo "Opened port $DEFAULT_PORT in ufw firewall"
elif command_exists firewall-cmd; then
  firewall-cmd --permanent --add-port="$DEFAULT_PORT/tcp"
  firewall-cmd --reload
  echo "Opened port $DEFAULT_PORT in firewalld"
elif command_exists iptables; then
  iptables -A INPUT -p tcp --dport "$DEFAULT_PORT" -j ACCEPT
  echo "Opened port $DEFAULT_PORT in iptables"
  echo "Note: This iptables rule might not persist after reboot. Consider saving iptables rules."
else
  echo "No supported firewall detected. You may need to open port $DEFAULT_PORT manually."
fi

# Enable and start the service
echo "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Verify installation
sleep 2 # Give systemd a moment to start
SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
if [ "$SERVICE_STATUS" = "active" ]; then
  echo -e "\n✅ Installation successful!"
  echo "Jarvis Ears HTTP server is running on port $DEFAULT_PORT as user $SERVICE_USER"
else
  echo -e "\n❌ Service installation completed but service is not running."
  echo "Check the status with: systemctl status $SERVICE_NAME"
  echo "Check logs with: journalctl -u $SERVICE_NAME"
fi

# Final instructions
echo -e "\nYou can manage Jarvis Ears using the following commands:"
echo "- sudo jarvis-manager start    # Start the server"
echo "- sudo jarvis-manager stop     # Stop the server"
echo "- sudo jarvis-manager port 9090 # Change port to 9090"
echo "- sudo jarvis-manager logs     # View logs"
echo "- sudo jarvis-manager help     # Show all commands"

echo -e "\nTest the server with:"
echo "curl http://localhost:$DEFAULT_PORT"
echo "curl -X POST -H \"Content-Type: application/json\" -d '{\"test\":\"data\"}' http://localhost:$DEFAULT_PORT"

exit 0
