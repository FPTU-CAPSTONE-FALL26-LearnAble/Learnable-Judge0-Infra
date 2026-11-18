# LearnAble Judge0 Infrastructure

Deployment configuration and operational tooling for the Judge0 CE code execution service used by LearnAble. The stack runs on an existing AWS EC2 instance using Docker Compose and official container images.

The LearnAble backend submits programs to Judge0 and polls for execution results. API credentials are managed on the backend, and the frontend communicates through the backend.

## Architecture

```text
LearnAble Backend → HTTPS reverse proxy → Judge0 API
                                              │
                                        PostgreSQL / Redis
                                              │
                                         Judge0 Worker
```

| Service | Image version | Role |
| --- | --- | --- |
| `server` | Judge0 CE 1.13.1 | Authenticated API for submissions and results |
| `workers` | Judge0 CE 1.13.1 | Sandboxed compilation and execution |
| `db` | PostgreSQL 16.16-bookworm | Submission and result storage |
| `redis` | Redis 7.2.17-bookworm | Job queue with AOF persistence |
| `proxy` | Nginx 1.30.6 | HTTPS endpoint, enabled through the `https` profile |

Images are pinned by version and SHA-256 digest. The API binds to `127.0.0.1:2358`. PostgreSQL and Redis use an internal Docker network and persistent named volumes. The API and worker use privileged containers as required by the official Judge0 CE 1.13.1 deployment configuration.

## Prerequisites

- An accessible Linux x86-64 host with Docker Engine and Docker Compose.
- A cgroups v1 configuration compatible with the pinned Judge0 release.
- Python 3 for configuration generation and smoke checks, plus OpenSSL for demo TLS certificates.
- Sufficient CPU, memory and disk space for the configured limits, compiler images, submission data and backups.

Inspect the target host before deployment and review existing containers, configuration and volumes. Resource sizing, data preservation and upgrade procedures are covered in the operations guide.

## Getting started

Run these commands from the repository root on the deployment host.

```sh
bash scripts/inspect-host.sh
cp -n .env.example .env
```

Review `.env` and set the host configuration paths, volume names and resource budgets. For an existing installation, identify and back up its data before starting the stack.

For a new installation, generate a configuration file outside the checkout. The generator refuses to overwrite an existing file. UID 1000 is the Judge0 user in the pinned image.

```sh
sudo python3 scripts/init-config.py /opt/learnable-judge0/secrets/judge0.conf
sudo chown 1000:1000 /opt/learnable-judge0/secrets/judge0.conf
sudo bash scripts/preflight.sh
sudo docker compose pull
sudo docker compose up -d --wait --wait-timeout 240 db redis server workers
sudo docker compose ps
```

Complete the smoke checks in the operations guide to verify authentication, supported languages, execution results and sandbox behavior. Repeat them after service restarts.

## Configuration and security

`.env.example` defines deployment paths, volume names and container resource budgets. `judge0.conf.example` defines authentication, worker settings and execution limits. Real tokens, passwords, private keys and configuration files belong in protected storage outside Git.

The demo configuration uses one worker, a queue limit of 20, a CPU time limit of 2 seconds, a wall time limit of 5 seconds and a memory limit of 128000 KB per submission. Submission networking is disabled. Review these settings against the host capacity and supported languages before deployment.

The optional `https` profile exposes Nginx on port 443 using Linux host networking. Configure its certificate and restrict access to the intended backend and administration sources. For demos without a domain, the repository includes an IP SAN self-signed certificate helper. Backend clients must explicitly trust that certificate and keep TLS verification enabled.

## Documentation

| Guide | Contents |
| --- | --- |
| [Operations](docs/operations.md) | Installation, secrets, HTTPS, smoke checks, monitoring, backups, retention and rollback |
| [Backend integration](docs/integration.md) | Authentication, endpoints, submission states, limits and polling |
| [Deployment review](docs/deployment-review.md) | Release requirements, configuration choices and resource planning |
| [Validation record](docs/validation.md) | Completed checks and outstanding deployment verification |
| [Host discovery](docs/discovery.md) | Recorded infrastructure observations |
| [SSH access](docs/ssh-access.md) | Access requirements and remote inspection |

## Development workflow

Commit and push changes to `dev` for review. The project maintainer merges approved changes into `main`.
