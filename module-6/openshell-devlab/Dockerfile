# syntax=docker/dockerfile:1

FROM docker:29.4.0-dind@sha256:a6dd5322747a95cd8e3207bd8d415a8fd20ec34e9c00f06dc019cbd912013489 AS docker
FROM ghcr.io/astral-sh/uv:0.12.5@sha256:e85be844203885286c60ffad8a858d48afb6c5a5c237ca0e67f12e74b8f174b1 AS uv
FROM python:3.12-slim-bookworm@sha256:392307d22300de8b5986851a12d9176dfc0fc073e65bf6523ebd7dcbeb23564e AS runtime-base

# OpenShell runs a private Docker daemon, never the VM's Docker socket.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl iproute2 iptables kmod openssh-client openssl tini \
    && rm -rf /var/lib/apt/lists/*
COPY --from=docker /usr/local/bin/ /usr/local/bin/
COPY --from=docker /usr/local/libexec/docker/cli-plugins/ /usr/local/libexec/docker/cli-plugins/
COPY --from=uv /uv /uvx /usr/local/bin/

# Keep the CLI and gateway on the same upstream release. Runtime images are
# pinned to this release in gateway.toml too.
RUN curl -fsSL --retry 3 -o /tmp/cli.tar.gz \
        https://github.com/NVIDIA/OpenShell/releases/download/v0.1.1/openshell-x86_64-unknown-linux-musl.tar.gz \
    && echo '822e8e462944366cb1b3d3b023be20a675016714666124b05ad8699a03c43143  /tmp/cli.tar.gz' | sha256sum -c - \
    && tar -xzf /tmp/cli.tar.gz -C /usr/local/bin \
    && curl -fsSL --retry 3 -o /tmp/gateway.tar.gz \
        https://github.com/NVIDIA/OpenShell/releases/download/v0.1.1/openshell-gateway-x86_64-unknown-linux-gnu.tar.gz \
    && echo '297dd4464b1c9fe1a3385a1d10a2bbd6a8e96ebbd12c6635d3879b5fe346e008  /tmp/gateway.tar.gz' | sha256sum -c - \
    && tar -xzf /tmp/gateway.tar.gz -C /usr/local/bin \
    && rm /tmp/cli.tar.gz /tmp/gateway.tar.gz

FROM runtime-base

# Root is intentional: this outer runtime starts a rootful private Docker daemon.
# Jupyter is authenticated administrator access, outside the agent's sandbox.
# Switching USER alone breaks startup; privilege separation needs a separate design.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_PROGRESS=1 \
    DOCKER_HOST=unix:///run/openshell-docker.sock \
    OPENSHELL_GATEWAY=devlab \
    OPENSHELL_WORKSPACE=default \
    XDG_CONFIG_HOME=/workspace/.openshell/config \
    XDG_STATE_HOME=/workspace/.openshell/state \
    XDG_DATA_HOME=/workspace/.openshell/data

# Keep the certificate bundle aligned with the third-party notice and sandbox lockfile.
RUN uv pip install --system jupyterlab==4.6.4 certifi==2026.7.22
COPY research/ /opt/research/
COPY quickstart.ipynb /opt/research/quickstart.ipynb
COPY gateway.toml /etc/openshell/gateway.toml
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY start-openshell.py /usr/local/bin/start-openshell.py

WORKDIR /workspace/research
EXPOSE 8888
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["python", "/usr/local/bin/start-openshell.py"]
