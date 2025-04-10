# Jarvis Ears HTTP Server

A lightweight HTTP server designed to listen for POST requests and log incoming data. Perfect for collecting data from various sources, monitoring webhooks, or as a simple API endpoint.

## Features

- 🚀 Simple HTTP server for receiving POST requests
- 📊 Accepts JSON data with automatic validation
- 📝 Comprehensive logging of all requests
- 🔄 Systemd service for reliable operation
- 🔧 Easy-to-use management script for common tasks
- 🔒 Basic security features included
- 🌐 Cross-distribution Linux support

## Installation

### Quick Install

1. Clone this repository:
   ```bash
   git clone https://github.com/Lightmean03/JHear-http-listener.git
   cd jarvis-ears
   ```

2. Run the installation script:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

3. Create dedicated user and set up service:
   ```bash
   chmod +x setup-user.sh
   sudo ./setup-user.sh
   ```

### Manual Installation

If you prefer to install manually or need to customize the installation:

1. Make sure Python 3 and jq are installed on your system
2. Create the lil-duck user:
   ```bash
   sudo useradd -r -s /sbin/nologin lil-duck
   ```
3. Create the installation directory:
   ```bash
   sudo mkdir -p /opt/jarvis-ears
   sudo cp server.py /opt/jarvis-ears/
   sudo chmod +x /opt/jarvis-ears/server.py
   ```
4. Create the service file:
   ```bash
   sudo cp jarvis-ears.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable jarvis-ears
   sudo systemctl start jarvis-ears
   ```
5. Install the management script:
   ```bash
   sudo cp jarvis-manager.sh /usr/local/bin/jarvis-manager
   sudo chmod +x /usr/local/bin/jarvis-manager
   ```

## Usage

### Managing the Server

Control and configure the server using the `jarvis-manager` command:

```bash
# Start the server
sudo jarvis-manager start

# Stop the server
sudo jarvis-manager stop

# Restart the server
sudo jarvis-manager restart

# Check server status
sudo jarvis-manager status

# Change the server port to 9090
sudo jarvis-manager port 9090

# Open an additional port in the firewall
sudo jarvis-manager open 8081

# List all open ports
sudo jarvis-manager ports

# Change log file location
sudo jarvis-manager log-path /path/to/new/logfile.log

# View the last 50 lines of logs
sudo jarvis-manager logs

# View the last 100 lines of logs
sudo jarvis-manager logs 100
```

### Sending Requests to the Server

You can send data to the server using curl or any HTTP client:

```bash
# Test with a simple GET request
curl http://localhost:8080

# Send JSON data with a POST request
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"test", "value":123, "message":"Hello Jarvis!"}' \
  http://localhost:8080
```

### View Logs

Check the logs to see incoming requests:

```bash
# Using the manager script
sudo jarvis-manager logs

# Direct log access
sudo tail -f /var/log/jarvis-ears.log

# Using journalctl (system logs)
sudo journalctl -u jarvis-ears -f
```

## Configuration

### Server Configuration

Default configuration is stored in `/opt/jarvis-ears/config.json`:

```json
{
  "port": 8080,
  "log_path": "/var/log/jarvis-ears.log"
}
```

You can modify this file directly or use the `jarvis-manager` script to make changes.

### Service Configuration

The systemd service file is located at `/etc/systemd/system/jarvis-ears.service`. If you need to make advanced changes, edit this file and then reload the systemd configuration:

```bash
sudo systemctl daemon-reload
sudo systemctl restart jarvis-ears
```
## Troubleshooting

### Service Won't Start

Check the service status and logs:

```bash
sudo systemctl status jarvis-ears
sudo journalctl -u jarvis-ears
```

Common issues:
- Port already in use
- Permission problems with log file
- Python dependencies missing

### Can't Connect to Server

Verify:
1. Server is running: `sudo jarvis-manager status`
2. Correct port is open: `sudo jarvis-manager ports`
3. Firewall allows connections: `sudo firewall-cmd --list-all` or `sudo ufw status`



