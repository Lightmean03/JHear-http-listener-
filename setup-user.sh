#!/bin/bash
# setup-user.sh - Creates lil-duck user and updates service configuration

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

echo "===== Creating Service User and Updating Configuration ====="

# Service and user configuration
NEW_USER="lil-duck"
NEW_SERVICE_NAME="jarvis-ears"
OLD_SERVICE_NAME="http-server"
SERVICE_FILE="/etc/systemd/system/${NEW_SERVICE_NAME}.service"
OLD_SERVICE_FILE="/etc/systemd/system/${OLD_SERVICE_NAME}.service"
INSTALL_DIR="/opt/jarvis-ears"
OLD_INSTALL_DIR="/opt/http-server"
MANAGER_SCRIPT="/usr/local/bin/jarvis-manager"
OLD_MANAGER_SCRIPT="/usr/local/bin/server-manager"
DEFAULT_LOG_PATH="/var/log/jarvis-ears.log"

# Step 1: Create the new user
echo -e "\n[1/5] Creating user $NEW_USER..."
if id -u "$NEW_USER" >/dev/null 2>&1; then
  echo "User $NEW_USER already exists. Skipping user creation."
else
  # Determine the right command to use based on the system
  if command -v useradd >/dev/null 2>&1; then
    # Create system user without home directory
    useradd -r -s /sbin/nologin "$NEW_USER"
  elif command -v adduser >/dev/null 2>&1; then
    # For Debian-based systems
    adduser --system --no-create-home --shell /usr/sbin/nologin "$NEW_USER"
  else
    echo "Error: Cannot create user - no useradd or adduser command found"
    exit 1
  fi
  echo "User $NEW_USER created successfully."
fi

# Step 2: Create new directory structure
echo -e "\n[2/5] Setting up directory structure..."
mkdir -p "$INSTALL_DIR"

# Check if old directory exists and copy files
if [ -d "$OLD_INSTALL_DIR" ]; then
  cp -r "${OLD_INSTALL_DIR}/"* "$INSTALL_DIR/"
  echo "Copied files from $OLD_INSTALL_DIR to $INSTALL_DIR"
elif [ -f "./server.py" ]; then
  cp ./server.py "$INSTALL_DIR/"
  echo "Copied server.py from current directory"
else
  echo "Error: Could not find server files. Please make sure server.py exists in the current directory or $OLD_INSTALL_DIR exists."
  exit 1
fi

# Create or update config file
echo "{\"port\": 8080, \"log_path\": \"$DEFAULT_LOG_PATH\"}" > "$INSTALL_DIR/config.json"
touch "$DEFAULT_LOG_PATH"

# Step 3: Update service file
echo -e "\n[3/5] Creating service file..."
if [ -f "$OLD_SERVICE_FILE" ]; then
  # Copy and modify the old service file
  cp "$OLD_SERVICE_FILE" "$SERVICE_FILE"
  # Update user and paths
  sed -i "s/User=.*/User=$NEW_USER/g" "$SERVICE_FILE"
  sed -i "s/Group=.*/Group=$NEW_USER/g" "$SERVICE_FILE"
  sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|g" "$SERVICE_FILE"
  sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 $INSTALL_DIR/server.py --port 8080 --log $DEFAULT_LOG_PATH|g" "$SERVICE_FILE"
  sed -i "s/Description=.*/Description=Jarvis Ears HTTP Server for POST Requests/g" "$SERVICE_FILE"
  echo "Updated service file created at $SERVICE_FILE"
elif [ -f "./http-server.service" ]; then
  # Use service file from current directory
  cp ./http-server.service "$SERVICE_FILE"
  # Update user and paths
  sed -i "s/User=.*/User=$NEW_USER/g" "$SERVICE_FILE"
  sed -i "s/Group=.*/Group=$NEW_USER/g" "$SERVICE_FILE"
  sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|g" "$SERVICE_FILE"
  sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 $INSTALL_DIR/server.py --port 8080 --log $DEFAULT_LOG_PATH|g" "$SERVICE_FILE"
  sed -i "s/Description=.*/Description=Jarvis Ears HTTP Server for POST Requests/g" "$SERVICE_FILE"
  echo "Created service file at $SERVICE_FILE using http-server.service template"
else
  # Create a new service file from scratch
  cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Jarvis Ears HTTP Server for POST Requests
After=network.target

[Service]
Type=simple
User=$NEW_USER
Group=$NEW_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/server.py --port 8080 --log $DEFAULT_LOG_PATH
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
  echo "Created new service file at $SERVICE_FILE"
fi

# Step 4: Update manager script
echo -e "\n[4/5] Creating manager script..."
if [ -f "$OLD_MANAGER_SCRIPT" ]; then
  # Copy and modify the old manager script
  cp "$OLD_MANAGER_SCRIPT" "$MANAGER_SCRIPT"
  # Update service name and paths
  sed -i "s/SERVICE_NAME=\"http-server\"/SERVICE_NAME=\"jarvis-ears\"/g" "$MANAGER_SCRIPT"
  sed -i "s|INSTALL_DIR=\"/opt/http-server\"|INSTALL_DIR=\"$INSTALL_DIR\"|g" "$MANAGER_SCRIPT"
  sed -i "s|DEFAULT_LOG_PATH=\"/var/log/http_server.log\"|DEFAULT_LOG_PATH=\"$DEFAULT_LOG_PATH\"|g" "$MANAGER_SCRIPT"
  sed -i "s/SERVICE_USER=\"[^\"]*\"/SERVICE_USER=\"$NEW_USER\"/g" "$MANAGER_SCRIPT"
  # Update any www-data references
  sed -i "s/www-data/$NEW_USER/g" "$MANAGER_SCRIPT"
  # Update the help text
  sed -i "s/HTTP Server Manager/Jarvis Ears Manager/g" "$MANAGER_SCRIPT"
  echo "Updated manager script created at $MANAGER_SCRIPT"
elif [ -f "./server-manager.sh" ]; then
  # Use manager script from current directory
  cp ./server-manager.sh "$MANAGER_SCRIPT"
  # Update service name and paths
  sed -i "s/SERVICE_NAME=\"http-server\"/SERVICE_NAME=\"jarvis-ears\"/g" "$MANAGER_SCRIPT"
  sed -i "s|INSTALL_DIR=\"/opt/http-server\"|INSTALL_DIR=\"$INSTALL_DIR\"|g" "$MANAGER_SCRIPT"
  sed -i "s|DEFAULT_LOG_PATH=\"/var/log/http_server.log\"|DEFAULT_LOG_PATH=\"$DEFAULT_LOG_PATH\"|g" "$MANAGER_SCRIPT"
  sed -i "s/SERVICE_USER=\"[^\"]*\"/SERVICE_USER=\"$NEW_USER\"/g" "$MANAGER_SCRIPT"
  # Update any www-data references
  sed -i "s/www-data/$NEW_USER/g" "$MANAGER_SCRIPT"
  # Update the help text
  sed -i "s/HTTP Server Manager/Jarvis Ears Manager/g" "$MANAGER_SCRIPT"
  echo "Created manager script at $MANAGER_SCRIPT using server-manager.sh template"
else
  echo "Error: Could not find manager script template. Please make sure server-manager.sh exists in the current directory or at $OLD_MANAGER_SCRIPT"
  exit 1
fi

# Make manager script executable
chmod +x "$MANAGER_SCRIPT"

# Step 5: Set permissions
echo -e "\n[5/5] Setting permissions..."
chmod +x "$INSTALL_DIR/server.py"
chown -R "$NEW_USER":"$NEW_USER" "$INSTALL_DIR"
chown "$NEW_USER":"$NEW_USER" "$DEFAULT_LOG_PATH"

# Enable and start the new service
echo "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable "$NEW_SERVICE_NAME"
systemctl start "$NEW_SERVICE_NAME"

# Check service status
sleep 2 # Give systemd a moment to start
SERVICE_STATUS=$(systemctl is-active "$NEW_SERVICE_NAME")
if [ "$SERVICE_STATUS" = "active" ]; then
  echo -e "\n✅ Setup successful!"
  echo "Jarvis Ears HTTP server is running on port 8080 as user $NEW_USER"
else
  echo -e "\n❌ Service setup completed but service is not running."
  echo "Check the status with: systemctl status $NEW_SERVICE_NAME"
  echo "Check logs with: journalctl -u $NEW_SERVICE_NAME"
fi

# Final instructions
echo -e "\nYou can manage Jarvis Ears using the following commands:"
echo "- sudo jarvis-manager start    # Start the server"
echo "- sudo jarvis-manager stop     # Stop the server"
echo "- sudo jarvis-manager port 9090 # Change port to 9090"
echo "- sudo jarvis-manager logs     # View logs"
echo "- sudo jarvis-manager help     # Show all commands"

echo -e "\nTest the server with:"
echo "curl http://localhost:8080"
echo "curl -X POST -H \"Content-Type: application/json\" -d '{\"test\":\"data\"}' http://localhost:8080"

exit 0
