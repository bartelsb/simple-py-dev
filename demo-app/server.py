from flask import Flask
import os

app = Flask(__name__)

@app.route("/healthz")
def healthz():
    return {"status":"ok"}

@app.route("/version")
def version():
    return os.environ.get("APP_VERSION", "unknown")