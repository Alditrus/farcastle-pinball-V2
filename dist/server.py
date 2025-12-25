#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
import sys

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required headers for SharedArrayBuffer
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    port = 8080
    print(f'Starting server on http://localhost:{port}')
    print('Press Ctrl+C to stop')
    httpd = HTTPServer(('localhost', port), CORSRequestHandler)
    httpd.serve_forever()