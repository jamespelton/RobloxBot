"""Tiny CORS-enabled HTTP server for handing PNGs to the browser during icon/thumbnail uploads."""
import http.server
import os

PORT = 8765
DIR = "/Users/jamespelton/Apps/React/RobloxBot/marketing"


class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()


os.chdir(DIR)
print(f"Serving {DIR} on http://localhost:{PORT}")
http.server.HTTPServer(("127.0.0.1", PORT), CORSHandler).serve_forever()
