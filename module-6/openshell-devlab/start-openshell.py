"""Start a trusted Devlab application and its private OpenShell runtime."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


WORKSPACE = Path("/workspace")
STATE = WORKSPACE / ".openshell"
DOCKER_RUNTIME = Path("/run/openshell-docker")


def seed_workspace(source: Path, destination: Path) -> None:
    """Add initial course files without replacing the user's edits on restart."""
    destination.mkdir(parents=True, exist_ok=True)
    for entry in source.rglob("*"):
        target = destination / entry.relative_to(source)
        if entry.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif not target.exists():
            shutil.copyfile(entry, target)


def wait_ready(check, processes, timeout=90):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if any(process.poll() is not None for process in processes):
            raise RuntimeError("An OpenShell runtime process exited during startup")
        if check():
            return
        time.sleep(1)
    raise RuntimeError("OpenShell runtime did not become ready")


def docker_ready(env):
    try:
        return subprocess.run(["docker", "info"], env=env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=5).returncode == 0
    except subprocess.TimeoutExpired:
        return False


def gateway_ready():
    try:
        with urllib.request.urlopen("http://127.0.0.1:17671/readyz", timeout=2) as response:
            return response.status == 200
    except (OSError, urllib.error.URLError):
        return False


def register_gateway(env):
    # Registration is persistent; `gateway add` rejects a duplicate on restart.
    result = subprocess.run(["openshell", "gateway", "list", "--output", "json"],
                            env=env, check=True, capture_output=True, text=True)
    if not any(gateway["name"] == "devlab" for gateway in json.loads(result.stdout)):
        subprocess.run(["openshell", "gateway", "add", "https://127.0.0.1:17670",
                        "--local", "--name", "devlab"], env=env, check=True)


def reset_docker_runtime():
    # A same-container restart preserves /run; stale PIDs can belong to new
    # processes. Only discard private runtime state, never /workspace/.docker.
    DOCKER_RUNTIME.with_suffix(".pid").unlink(missing_ok=True)
    try:
        shutil.rmtree(DOCKER_RUNTIME)
    except FileNotFoundError:
        pass


def stop_processes(processes):
    # Signal every child before waiting, leaving time for the coding launcher
    # to stop its own children within Docker's default ten-second grace period.
    deadline = time.monotonic() + 8
    running = [process for process in reversed(processes) if process.poll() is None]
    for process in running:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    for process in running:
        try:
            process.wait(timeout=max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()


def main():
    mode = os.environ.get("OPENSHELL_MODE", "research")
    secret = {"research": "JUPYTER_TOKEN", "coding": "PASSWORD"}.get(mode)
    if secret is None:
        raise SystemExit("OPENSHELL_MODE must be research or coding")
    if not os.environ.get(secret):
        raise SystemExit(f"{secret} is required; refusing to start an unauthenticated application")
    os.umask(0o077)
    STATE.mkdir(parents=True, exist_ok=True)
    if mode == "research":
        seed_workspace(Path("/opt/research"), WORKSPACE / "research")

    # Neither infrastructure process needs the application's credentials.
    runtime_env = {key: value for key, value in os.environ.items()
                   if key not in {"JUPYTER_TOKEN", "PASSWORD", "TOFA_API_KEY", "TAVILY_API_KEY"}}
    tls = STATE / "tls"
    if not tls.exists():
        with tempfile.TemporaryDirectory(dir=STATE) as temporary:
            generated = Path(temporary) / "tls"
            subprocess.run(["openshell-gateway", "generate-certs", "--output-dir", str(generated)],
                           env=runtime_env, check=True)
            generated.rename(tls)
    client = Path(os.environ["XDG_CONFIG_HOME"]) / "openshell/gateways/devlab/mtls"
    client.mkdir(parents=True, exist_ok=True)
    for source in (tls / "ca.crt", tls / "client/tls.crt", tls / "client/tls.key"):
        shutil.copyfile(source, client / source.name)

    subprocess.run(["openshell-gateway", "config", "preflight", "--path",
                    "/etc/openshell/gateway.toml"], env=runtime_env, check=True)
    processes = []

    def stop(_signal, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        reset_docker_runtime()
        processes.append(subprocess.Popen([
            "dind", "dockerd", "--host=unix:///run/openshell-docker.sock",
            "--data-root=/workspace/.docker", "--exec-root=/run/openshell-docker",
            "--pidfile=/run/openshell-docker.pid", "--log-level=warn",
        ], env=runtime_env, start_new_session=True))
        wait_ready(lambda: docker_ready(runtime_env), processes)
        processes.append(subprocess.Popen([
            "openshell-gateway", "--config", "/etc/openshell/gateway.toml",
        ], env=runtime_env, start_new_session=True))
        wait_ready(gateway_ready, processes)
        register_gateway(runtime_env)

        if mode == "research":
            # Keep the token out of argv, configuration files and startup banners.
            command = ["jupyter", "lab", "--config", "/etc/jupyter/jupyter_server_config.py"]
        else:
            command = ["python", "/usr/local/bin/start-coding.py"]
        processes.append(subprocess.Popen(command, start_new_session=True))
        print("OpenShell runtime is ready. Open the Devlab URL to get started.", flush=True)
        while all(process.poll() is None for process in processes):
            time.sleep(1)
        raise RuntimeError("An application or OpenShell runtime process exited")
    finally:
        stop_processes(processes)


if __name__ == "__main__":
    main()
