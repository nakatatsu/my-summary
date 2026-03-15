"""GitHub App token sidecar server.

Thin HTTP server that generates GitHub App installation access tokens.
Endpoints:
  GET /token  - Generate and return a new installation access token
  GET /health - Health check (200 OK)
"""

import http.server
import json
import os
import sys
import time
import urllib.request

import jwt

PEM_PATH = "/secrets/private-key.pem"
CLIENT_ID = os.environ.get("GH_APP_CLIENT_ID", "")
INSTALLATION_ID = os.environ.get("GH_APP_INSTALLATION_ID", "")

_private_key = None


def _load_private_key():
    global _private_key
    with open(PEM_PATH, "r") as f:
        _private_key = f.read()


def _generate_jwt():
    now = int(time.time())
    payload = {
        "iat": now - 60,
        "exp": now + 600,
        "iss": CLIENT_ID,
    }
    return jwt.encode(payload, _private_key, algorithm="RS256")


def _get_installation_token():
    encoded_jwt = _generate_jwt()
    url = f"https://api.github.com/app/installations/{INSTALLATION_ID}/access_tokens"
    req = urllib.request.Request(url, method="POST", data=b"{}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Authorization", f"Bearer {encoded_jwt}")
    req.add_header("User-Agent", "gh-token-sidecar")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


class TokenHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._json_response(200, {"status": "ok"})
        elif self.path == "/token":
            try:
                result = _get_installation_token()
                self._json_response(200, {"token": result["token"]})
            except Exception as e:
                self._json_response(500, {"error": str(e)})
        else:
            self._json_response(404, {"error": "not found"})

    def _json_response(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())


def main():
    if not CLIENT_ID:
        print("ERROR: GH_APP_CLIENT_ID is not set", file=sys.stderr)
        sys.exit(1)
    if not INSTALLATION_ID:
        print("ERROR: GH_APP_INSTALLATION_ID is not set", file=sys.stderr)
        sys.exit(1)

    try:
        _load_private_key()
    except FileNotFoundError:
        print(f"ERROR: Private key not found at {PEM_PATH}", file=sys.stderr)
        sys.exit(1)

    server = http.server.HTTPServer(("0.0.0.0", 80), TokenHandler)
    print("gh-token-sidecar listening on :80")
    server.serve_forever()


if __name__ == "__main__":
    main()
