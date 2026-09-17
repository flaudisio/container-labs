# Container Labs — AGENTS.md

Compose + Nomad test/lab configurations. Every directory is an independent project.

## Compose file conventions

- File **must** be named `compose.yml` (not `docker-compose.yml`)
- Start with `---`, 2-space indent, 140-char max line length
- **Do not add `version:`** — it is being phased out (only 25/58 files still have it; new files omit it)

### Attribute order (consistently followed)

```yaml
image:
command: / entrypoint:     # if present — right after image
restart: unless-stopped    # universal; never anything else
container_name:            # set explicitly when used
user:                      # if needed
cap_add: / hostname: / network_mode: / pid: / stop_grace_period:
ports:                     # quoted string "PORT:PORT" dominant; "127.0.0.1:P:P" for reverse proxy
volumes:                   # absolute: /srv/container-labs/{app}/... ; config: ./file:/path:ro
environment: / env_file:
depends_on:                # simple list; condition: service_healthy for DBs
healthcheck:
networks:
labels:                    # only for Traefik integration
sysctls:
```

### Pattern inventory

| Element | Convention |
| --------- | ----------- |
| `restart:` | `unless-stopped` always |
| `ports:` | `"HOST:CONTAINER"` quoted string (dominant). Unquoted integers and UDP/TCP suffix also seen |
| `volumes:` | Host paths: `/srv/container-labs/{app}/...`. Config: `./file:/container/path:ro` |
| `container_name:` | Always set when used. Hyphenated or underscored matching the app |
| `networks:` | Default bridge is the norm. `network_mode: host` for system services (plex, frps, adguardhome). `external: true` for Traefik ingress |
| `healthcheck:` | `["CMD", ...]` or `["CMD-SHELL", "..."]`. Include `interval/timeout/retries/start_period` |
| `depends_on:` | Simple list by default. `condition: service_healthy` for DBs; `condition: service_completed_successfully` for init containers |
| `environment:` | Key-value map (dominant) or `KEY=VALUE` list format. Env vars from `.env` via `${VAR}` |
| YAML anchors | `x-credentials:` + `&var` / `*var` for DB credential reuse |
| Comments | `# Ref: https://...` to cite upstream. `# NOTE:`, `# HACK:`, `# TODO:` for notes |
| `version:` | Omit in new files |

### Secrets & .env

- `.env` is gitignored — place it per-directory with `${VAR}` references in compose
- Placeholder convention: `CHANGEME` or `changeme` (e.g. `TOKEN=CHANGEME`)
- No `.env.example` convention exists — if you create one, use real defaults not secrets

## Tooling & validation

- **pre-commit**: 10 hooks (trailing-whitespace, end-of-file-fixer, yamllint --strict, shellcheck, etc.)

  ```bash
  mise run pre-commit              # pre-commit run --all-files --color always
  ```

  yamllint runs in `--strict` mode — do not leave warnings.
- **mise.toml**: manages consul, nomad, shellcheck, terragrunt versions

  ```bash
  mise run fmt                     # terragrunt hcl fmt
  ```

- **yamllint rules**: 2-space indent, 140-char line max, max 1 blank consecutive line
- **shellcheck**: runs on all `.sh` files

## Shell script conventions

Follow the **bash-scripting** skill when creating, reviewing, or improving any shell script in
this repo. It is the source of truth for shebangs, `set` options (`set -o pipefail`, prefer
`set -u`; avoid `set -e`), function naming (`snake_case`, imperative), quoting, safety,
portability, and style — including its bundled `check-bash-style.sh` checker. **If the skill is
not available, warn the user before proceeding.**

For ash-compatible scripts (e.g. inside Alpine containers): `#!/bin/sh` with
`# shellcheck shell=ash` on line 2.

## HCL file conventions

Used for Nomad/Consul agent configs and `.nomad` job files.

- Double-quoted strings
- `datacenter = "dc1"`, `region = "global"`, `domain = "consul"`, `log_level = "INFO"`
- Section headers: `# --- SECTION NAME ---`
- `.nomad` extension associated with HCL in `.vscode/settings.json`

## Directory layout

```text
{category}/
  {srv-name}/
    compose.yml          # independent project
    .env                 # secrets (gitignored)
    extra-configs/       # volumes, Dockerfiles, scripts as needed

000-deprecated/
  {project}/
    v0/  compose.yml     # versioned, self-contained
    v1/  compose.yml
```

### Categories

| Category | Description |
| ---------- | ------------- |
| `infra/` | Infrastructure, networking, DNS, proxy, tunnels, platform, secrets |
| `monitoring/` | Observability, exporters, dashboards, alerting |
| `storage/` | Databases, registries, file systems, backups |
| `apps/` | Productivity apps, pastebins, CMS, design tools, sync |
| `media/` | Media servers, photo backup, torrent clients |
| `automation/` | CI/CD, workflow orchestration, event agents, job runners |

## Nomad jobs

Only one Nomad job file exists (`storage/pgreplication/pgreplication.nomad`). Uses modern HCL2 syntax (no wrapping braces). Pattern:

```hcl
job "name" {
  datacenters = ["dc1"]
  group "name" {
    task "name" {
      driver = "docker"
      template { data = file(".env"); destination = "${NOMAD_SECRETS_DIR}/.env"; env = true }
    }
  }
}
```

## VS Code

- Extensions: `EditorConfig.EditorConfig`, `hashicorp.hcl`
- `.alloy` and `.nomad` files get HCL syntax highlighting
