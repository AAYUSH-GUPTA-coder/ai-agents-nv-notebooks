"""Read the login token at runtime without writing it into configuration files."""

import os


token = os.environ.get("JUPYTER_TOKEN")
if not token:
    raise RuntimeError("JUPYTER_TOKEN is required")

c = get_config()
c.IdentityProvider.token = token
c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = 8888
c.ServerApp.port_retries = 0
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
c.ServerApp.root_dir = "/workspace/research"
c.ServerApp.log_level = "WARN"
