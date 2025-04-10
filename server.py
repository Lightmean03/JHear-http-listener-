#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import logging
import argparse
from datetime import datetime

# Parse command line arguments
parser = argparse.ArgumentParser(description='Simple HTTP Server')
parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
parser.add_argument('--log', type=str, default='/var/log/http_server.log', help='Log file path')
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
        logging.info(f"GET request received at {self.path}")
        self._set_response()
        response = {'message': 'Server is running', 'time': str(datetime.now())}
        self.wfile.write(json.dumps(response).encode('utf-8'))
        
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        logging.info(f"POST request received at {self.path}")
        logging.info(f"POST data: {post_data.decode('utf-8')}")
        
        # Process the POST data
        try:
            data = json.loads(post_data.decode('utf-8'))
            # Here you can process the data as needed
            response = {'status': 'success', 'message': 'Data received successfully'}
            status_code = 200
        except json.JSONDecodeError:
            response = {'status': 'error', 'message': 'Invalid JSON data'}
            status_code = 400
        
        self._set_response(status_code)
        self.wfile.write(json.dumps(response).encode('utf-8'))

def run(server_class=HTTPServer, handler_class=RequestHandler, port=8080):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    logging.info(f'Starting HTTP server on port {port}...')
    print(f'Server started on port {port}. Press Ctrl+C to stop.')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info('HTTP server stopped')

if __name__ == '__main__':
    run(port=args.port)
