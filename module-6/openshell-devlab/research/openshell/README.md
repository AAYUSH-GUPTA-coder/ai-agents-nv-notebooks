# Secure runtime commands

The agent image installs its Python dependencies from the checked-in `uv.lock`.
The trusted wrapper uses only Python's standard library.
This course targets NVIDIA OpenShell CLI and gateway v0.1.1. Devlab startup
provides the CLI and a private local gateway; the wrapper never creates one.
The CLI and `docker` must address that gateway's Docker daemon.

```bash
# Import the two endpointless credential profiles and create/update providers.
python openshell/run.py setup

# Rebuild the locked image (cached), run the agent, and download runs/.
python openshell/run.py run \
  "Compare Linear against Jira and Asana"
```

The run command prints the generated sandbox name. It stays available so the
effective composed policy and its decisions can be examined:

```bash
python openshell/run.py inspect <sandbox-name>
python openshell/run.py demo <sandbox-name>
python openshell/run.py delete <sandbox-name>
```

Use `run --delete` when policy inspection is not needed. Run artifacts are
downloaded before deletion. A failed download preserves the sandbox for recovery.
Each successful run saves the final response to `runs/<run-id>/final.md`, alongside
the agent-authored notes and search trace. The research question and search results
are sent to the configured third-party APIs and retained in these local artifacts.

To build the inner image without running research or supplying credentials:

```bash
python openshell/run.py build
```

This tags `openshell-deep-research-agent:course-1` in the local Docker daemon;
it does not push to a registry. `run` also rebuilds so code edits take effect.
Both API credentials come from the Devlab creation form. They remain on the
trusted Devlab side and are registered as OpenShell providers, not passed as
sandbox environment values. Do not put keys in workspace files or notebook cells.

The denial demo checks three independent controls: an unlisted host (Reddit),
an allowed host reached by the wrong executable, and an allowed host/executable
pair using an unapproved HTTP method. It requires a fresh matching policy audit
event for each failure; a timeout, TLS/DNS error, or historical event is not a pass.
The real agent can only call Nebius
`POST /v1/chat/completions` and Tavily `POST /search`. Tavily is also told to
exclude X/Twitter and Reddit from returned search results.
