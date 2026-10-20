import os
import socket
from flask import Flask

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")
OWNER = os.environ.get("OWNER", "student")
TOKEN = os.environ.get("TOKEN", "none")


@app.route("/")
def home():
    return f"Capstone app (class demo) v{VERSION} | owner={OWNER} | token={TOKEN}\n"


@app.route("/health")
def health():
    return "ok"


@app.route("/host")
def host():
    return socket.gethostname() + "\n"
