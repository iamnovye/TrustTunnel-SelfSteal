import os
import re
import subprocess
import secrets
from functools import wraps
from flask import Flask, request, jsonify, session
from flask_cors import CORS

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", secrets.token_hex(32))
CORS(app, supports_credentials=True, origins=os.environ.get("ALLOWED_ORIGIN", "*"))

ADMIN_USER = os.environ.get("ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("ADMIN_PASS", "changeme")

VPN_TOML = os.environ.get("VPN_TOML", "/trusttunnel/vpn.toml")
HOSTS_TOML = os.environ.get("HOSTS_TOML", "/trusttunnel/hosts.toml")
CREDENTIALS_FILE = os.environ.get("CREDENTIALS_FILE", "/trusttunnel/credentials.toml")
TT_BINARY = os.environ.get("TT_BINARY", "/trusttunnel/trusttunnel_endpoint")
SERVER_ADDRESS = os.environ.get("SERVER_ADDRESS", "")


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("authenticated"):
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated


def _read_credentials():
    """Returns list of (username, password) from TOML credentials file."""
    if not os.path.exists(CREDENTIALS_FILE):
        return []
    users = []
    current = {}
    with open(CREDENTIALS_FILE) as f:
        for line in f:
            line = line.strip()
            if line == "[[client]]":
                if current:
                    users.append(current)
                current = {}
            elif line.startswith("username"):
                m = re.match(r'username\s*=\s*"([^"]*)"', line)
                if m:
                    current["username"] = m.group(1)
            elif line.startswith("password"):
                m = re.match(r'password\s*=\s*"([^"]*)"', line)
                if m:
                    current["password"] = m.group(1)
    if current:
        users.append(current)
    return users


def _list_usernames():
    return [u["username"] for u in _read_credentials()]


def _user_exists(username):
    return username in _list_usernames()


def _add_user_to_credentials(username, password):
    with open(CREDENTIALS_FILE, "a") as f:
        f.write(f'\n[[client]]\nusername = "{username}"\npassword = "{password}"\n')


def _remove_user_from_credentials(username):
    if not os.path.exists(CREDENTIALS_FILE):
        return
    users = [u for u in _read_credentials() if u["username"] != username]
    with open(CREDENTIALS_FILE, "w") as f:
        for u in users:
            f.write(f'[[client]]\nusername = "{u["username"]}"\npassword = "{u["password"]}"\n\n')


def _reload_trusttunnel():
    """Send SIGHUP to trusttunnel_endpoint process so it reloads credentials."""
    import signal as _signal
    try:
        for pid_str in os.listdir("/proc"):
            if not pid_str.isdigit():
                continue
            try:
                with open(f"/proc/{pid_str}/comm") as f:
                    if "trusttunnel_end" in f.read():
                        os.kill(int(pid_str), _signal.SIGHUP)
                        return
            except OSError:
                continue
    except Exception:
        pass


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(force=True)
    if data.get("username") == ADMIN_USER and data.get("password") == ADMIN_PASS:
        session["authenticated"] = True
        return jsonify({"ok": True})
    return jsonify({"error": "Invalid credentials"}), 401


@app.route("/api/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"ok": True})


@app.route("/api/users", methods=["GET"])
@require_auth
def list_users():
    return jsonify({"users": _list_usernames()})


@app.route("/api/users", methods=["POST"])
@require_auth
def add_user():
    data = request.get_json(force=True)
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()

    if not username or not password:
        return jsonify({"error": "username and password are required"}), 400

    if not re.match(r"^[a-zA-Z0-9_\-\.]{1,64}$", username):
        return jsonify({"error": "Invalid username (alphanumeric, _, -, . only)"}), 400

    if _user_exists(username):
        return jsonify({"error": "User already exists"}), 409

    _add_user_to_credentials(username, password)
    _reload_trusttunnel()

    link = _generate_link(username)
    return jsonify({"ok": True, "username": username, "link": link}), 201


@app.route("/api/users/<username>", methods=["DELETE"])
@require_auth
def delete_user(username):
    if not _user_exists(username):
        return jsonify({"error": "User not found"}), 404
    _remove_user_from_credentials(username)
    _reload_trusttunnel()
    return jsonify({"ok": True})


@app.route("/api/users/<username>/link", methods=["GET"])
@require_auth
def get_link(username):
    if not _user_exists(username):
        return jsonify({"error": "User not found"}), 404
    link = _generate_link(username)
    if link is None:
        return jsonify({"error": "Failed to generate link"}), 500
    return jsonify({"link": link})


def _generate_link(username):
    if not SERVER_ADDRESS:
        return None
    try:
        cmd = [
            TT_BINARY,
            VPN_TOML,
            HOSTS_TOML,
            "-c", username,
            "-a", SERVER_ADDRESS,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        match = re.search(r"tt://[^\s]+", output)
        if match:
            return match.group(0)
        return output.strip() or None
    except Exception:
        return None


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"ok": True})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
