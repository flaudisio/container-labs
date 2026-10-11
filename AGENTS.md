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
| `healthcheck:` | `["CMD", ...]` or `["CMD-SHELL", "..."]`. Include `interval/timeout/retries/start_period`. Postgres: `pg_isready` (below) |
| `depends_on:` | Simple list by default. `condition: service_healthy` for DBs; `condition: service_completed_successfully` for init containers |
| `environment:` | Key-value map (dominant) or `KEY=VALUE` list format. Env vars from `.env` via `${VAR}` |
| YAML anchors | `x-credentials:` + `&var` / `*var` for DB credential reuse |
| Comments | `# Ref: https://...` to cite upstream. `# NOTE:`, `# HACK:`, `# TODO:` for notes |
| `version:` | Omit in new files |

### Postgres healthcheck & dependency

All Postgres services use the same `pg_isready` check, and dependents wait on it:

```yaml
# postgres service
healthcheck:
  test: ["CMD-SHELL", 'pg_isready -U "$${POSTGRES_USER}" -d "$${POSTGRES_DB}"']
  interval: 10s
  timeout: 5s
  retries: 5

# dependent service
depends_on:
  postgres:
    condition: service_healthy
```

- `$$` defers expansion to the container's shell instead of `docker compose up`; quote the values.
- Use the default Unix socket — do not add `-h localhost`.
- Use the container's own DB variable when it is not `POSTGRES_DB`, e.g. `POSTGRES_DATABASE`.
- Compose cannot mix list and map form in one `depends_on`; write healthcheck-less co-deps
  (redis, etc.) as `condition: service_started`.

### Secrets & .env

- `.env` is gitignored — place it per-directory with `${VAR}` references in compose
- Placeholder convention: `xxxxxx` (e.g. `TOKEN=xxxxxx`)
- `.env.example` is committed with `xxxxxx` placeholders (never real secrets)

### URLs & hostnames

- Never hardcode real/private service URLs or hostnames in `compose.yml` — reference a variable
  instead (e.g. `PROMETHEUS_URL: ${PROMETHEUS_URL}`)
- Commit the variable in `.env.example` with a generic placeholder domain, e.g.
  `PROMETHEUS_URL=https://prometheus.example.com`
- Public upstream citations in `# Ref:` comments are exempt

### Runtime data

- Host bind-mount dirs holding runtime/user data (SQLite DBs, caches, uploads) are gitignored
  via a per-stack `.gitignore` (e.g. `data/`, `files/`)

## Tooling & validation

- **prek**: 10 hooks (trailing-whitespace, end-of-file-fixer, yamllint --strict, shellcheck, etc.)

  ```bash
  mise run lint                    # prek run --all-files --color always
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
    .env.example         # committed template (xxxxxx + example URLs)
    .gitignore           # ignore runtime data dirs (data/, files/, ...)
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
