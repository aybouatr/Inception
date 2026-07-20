*This project has been created as part of the 42 curriculum by aybouatr.*

# Inception

## Description

Inception is a system administration project whose goal is to learn how to
set up a small, realistic web infrastructure entirely with Docker, following
the "one service, one container" philosophy instead of relying on ready-made
images from Docker Hub.

The mandatory part builds three custom containers, orchestrated with
Docker Compose:

- **NGINX** — the only entry point into the infrastructure. It terminates
  TLS (HTTPS only, no plaintext HTTP) and forwards PHP requests to WordPress.
- **WordPress + php-fpm** — the actual website, with no built-in HTTP server
  (NGINX handles that role).
- **MariaDB** — the database used by WordPress, running with no built-in
  HTTP server either.

Each service is built from scratch on a minimal base image (Alpine or
Debian), configured through its own `Dockerfile` and configuration files, and
communicates with the others only over a dedicated, internal Docker network.
No `latest` tags, no pre-built "all-in-one" images, no `network: host`, and
containers must restart automatically in case of a crash.

On top of that, this repository also implements several bonus services:

- **Redis** — object-cache backend for WordPress.
- **FTP server (vsftpd)** — remote access to the WordPress volume.
- **Adminer** — lightweight web UI to inspect/administer the MariaDB
  database.
- **Static website** — a simple static NGINX site, independent of WordPress.
- **Portainer** — a web UI to visualize and manage the Docker daemon,
  containers, images, volumes, and networks.

## Instructions

### Requirements

- A Linux machine (or VM) with `docker` and the `docker compose` plugin
  installed
- `make`
- `sudo` rights (used once, to add a line to `/etc/hosts`)

### Setup

1. Clone the repository.
2. Fill in the `srcs/.env` file at the root of `srcs/` with your own values
   (see the table below for the variables that are expected). **This file
   must never be committed to Git.**
3. From the `inceptions/` directory, simply run:

```bash
make
```

This single command:
- creates the persistent data directories on the host
  (`/home/<user>/data/mariadb` and `/home/<user>/data/wordpress`),
- adds a `127.0.0.1 <login>.42.fr` entry to `/etc/hosts` so the domain
  resolves locally,
- builds every image and starts every container in detached mode via
  `docker compose`.

### Environment variables (`srcs/.env`)

| Variable | Used by | Purpose |
|---|---|---|
| `MYSQL_HOST`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | wordpress, mariadb | DB connection info / credentials for the WordPress DB user |
| `MYSQL_ROOT_PASSWORD` | mariadb | MariaDB root password |
| `DOMAIN_NAME` | wordpress | The site's domain (`<login>.42.fr`) |
| `WP_TITLE` | wordpress | WordPress site title |
| `WP_ADMIN_USER`, `WP_ADMIN_PASSWORD`, `WP_ADMIN_EMAIL` | wordpress | WordPress administrator account (must **not** contain "admin"/"administrator" as required by the subject) |
| `WP_USER`, `WP_USER_PASSWORD`, `WP_USER_EMAIL` | wordpress | A second, non-admin WordPress user |
| `FTP_USER`, `FTP_PASSWORD`, `FTP_PASV_ADDRESS` | ftp | vsftpd account and passive-mode address |

### Other Makefile targets

```bash
make        # setup + build + start everything (detached)
make down   # stop and remove containers + Compose-managed volumes
make clean  # down, then docker system prune -af and remove host data dirs
make re     # clean, then rebuild everything from scratch
```

### Accessing the services

| Service | URL / port | Notes |
|---|---|---|
| WordPress site | `https://<login>.42.fr` (port 443) | Only entry point, served through NGINX over TLS |
| Adminer | `http://<host>:8888` | MariaDB admin UI |
| Portainer | `https://<host>:9443` | Docker management UI |
| FTP | port 21 (+ passive range 30000-30009) | Access to the WordPress volume |
| Static site | internal only, reverse-proxied | Not directly published on a host port |

## Core Concepts

The concepts below are presented in the same logical progression a Docker
course would follow (containers → Docker → images → engine → network →
storage → Dockerfile → Compose → Portainer), but limited strictly to what
this project actually uses. Swarm, Docker Stack, Kubernetes, and other
topics sometimes covered in general Docker courses are intentionally left
out, since none of them are part of Inception.

### 1. Containers

![Alternative text](https://i.sstatic.net/Cx1eo.png)

A container is a lightweight, isolated environment that bundles an
application with everything it needs to run (code, runtime, libraries,
config), while sharing the host machine's kernel instead of running its own.
In this project, every service — NGINX, WordPress, MariaDB, and each bonus
service — runs as exactly one container, following the "one process per
container" rule the subject requires.

### 2. Container Architecture

![Alternative text](https://storage.ghost.io/c/5f/2f/5f2f4d20-2abf-4534-8d40-7aa233aedd43/content/images/2025/03/namespaces-controlgroups-1.png)

A container gets its isolation from two Linux kernel mechanisms:
- **namespaces**, which give a container its own private view of the
  system (its own network interfaces, process tree, mount points,
  hostname, ...) even though it runs on the same kernel as everything else
  on the host,
- **cgroups**, which limit and account for the resources (CPU, memory, I/O)
  a container's processes are allowed to use.

This is why containers start almost instantly and cost far less than a full
virtual machine: there's no second kernel to boot, only a new, isolated view
of the existing one.

### 3. Docker

Docker is the tool used to build, ship, and run these containers. It takes a
`Dockerfile`, builds an image from it, and runs that image as a container,
handling the underlying namespaces/cgroups setup so the project doesn't
have to manage them by hand. `docker compose` extends this to run several
containers together as a coordinated stack, which is exactly how this
project's ten services (three mandatory + bonus) are launched with a single
`make`.

### 4. Images

An image is the read-only, versioned template a container is created from.
It is built in layers, one per `Dockerfile` instruction, each layer cached
so unrelated rebuilds are fast. Every image in this project is built `FROM`
a minimal base (`alpine:latest`, or a pinned `debian:bookworm` /
`debian:bookworm-slim`), not from a pre-built service image, per the
subject's requirement to write each `Dockerfile` from scratch.

### 5. Docker Engine Architecture

![Alternative text](https://cdn.educba.com/academy/wp-content/uploads/2019/10/Docker-Architecture.jpg)

The Docker Engine is a client/server system: the Docker CLI (`docker`,
`docker compose`) talks to the **Docker daemon** (`dockerd`), which does the
actual work of building images, and creating/starting/stopping containers,
networks, and volumes. Portainer (bonus service) is a web UI for exactly
this daemon: its container is given access to `/var/run/docker.sock` so it
can query and control the same Docker Engine `docker compose` uses, without
needing its own separate Docker installation.


### 6. Network

By default, Docker isolates each container's network stack; containers on
the same **bridge** network can reach each other by container/service name
through Compose's built-in DNS, but nothing is reachable from outside
unless a port is explicitly published. This project defines one custom
bridge network, `inception`, shared by every service, and only publishes
the ports that genuinely need to be public (443 for NGINX, 21 and
30000-30009 for FTP, 8888 for Adminer, 9443 for Portainer) — see the
[Docker Network vs Host Network](#docker-network-vs-host-network) comparison
below for more detail.

### 7. Storage

Containers are ephemeral by default: anything written to a container's own
filesystem disappears when the container is removed. To keep data across
restarts and rebuilds, this project uses named Docker volumes
(`wordpress_data`, `mariadb_data`, `portainer_data`) backed by fixed
directories on the host — see
[Docker Volumes vs Bind Mounts](#docker-volumes-vs-bind-mounts) below.

### 8. Dockerfile

Each service's `Dockerfile` defines its base image, the packages it
installs, the configuration files it copies in, and the command that runs
when the container starts (`CMD` / `ENTRYPOINT`). For example, the MariaDB
and WordPress containers use an `ENTRYPOINT` startup script to perform
first-run setup (creating the database/user, installing WordPress via
WP-CLI) before handing off to the actual server process, so the whole stack
is ready to use as soon as it starts.

### 9. Docker Compose

`srcs/docker-compose.yml` declares every service, its build context, its
environment variables, its volumes, and the shared network, so the entire
ten-container infrastructure is described in one file and brought up
together with `docker compose up -d --build` (wrapped here by `make`).

### 10. Portainer (bonus)

Portainer is a web-based UI on top of the Docker Engine: it lets you see and
manage running containers, images, volumes, and networks visually instead
of through the CLI. It's included here as a bonus service, reachable at
`https://<host>:9443`.

## Project Description

### Use of Docker and sources included in the project

The infrastructure is described declaratively in a single
`srcs/docker-compose.yml`, which builds one image per service from the
Dockerfiles under `srcs/requirement/` (mandatory part: `nginx`, `wordpress`,
`mariadb`) and `srcs/bonus/` (bonus part: `redis`, `FTP`, `Adminer`,
`static`, `portainer`). Every image is built `FROM` a minimal base
(`alpine:latest` or a pinned `debian:bookworm` / `debian:bookworm-slim`
release) — never from an existing service image — and each container runs
a single foreground process as PID 1 (`nginx -g "daemon off;"`, `php-fpm`,
`mysqld`, `redis-server`, `vsftpd`, `portainer`, ...), with `restart: always`
(or `unless-stopped` for the bonus services) so a crashed service comes back
up on its own.

**Main design choices:**
- **NGINX is the single public entry point.** Only port 443 (TLS) is
  published for it; WordPress's php-fpm process is only reachable from
  inside the Docker network (`expose: 9000`, not `ports:`), so it can never
  be hit directly from outside the infrastructure.
- **Self-signed TLS certificate**, generated once at image-build time with
  `openssl req -x509 ...` and baked into the NGINX image, since the domain
  (`<login>.42.fr`) only needs to resolve locally.
- **WordPress and MariaDB store their data in named Docker volumes**
  (`wordpress_data`, `mariadb_data`) bind-mounted from host directories
  created by `make setup`, so content and the database survive
  `docker compose down` / container recreation.
- **Startup scripts (`ENTRYPOINT`) handle first-run configuration**: the
  MariaDB container initializes the database/user on first boot, and the
  WordPress container waits for MariaDB, then uses WP-CLI to install
  WordPress non-interactively and create the admin/user accounts from
  environment variables, so the whole stack comes up ready to use with a
  single `make`.
- **One dedicated bridge network (`inception`)** connects every service;
  nothing uses the host network, and inter-service communication relies on
  Compose's internal DNS (containers reach each other by service name, e.g.
  `mariadb`, `wordpress`).
- **Bonus services reuse the same volumes/network where relevant**: FTP
  mounts the same `wordpress_data` volume so it can serve the site's files,
  Adminer talks to MariaDB over the internal network, and Redis is available
  to WordPress as an object-cache backend.

### Virtual Machines vs Docker

![Alternative text](https://media.geeksforgeeks.org/wp-content/uploads/20230109130229/Docker-vs-VM.png)

| | Virtual Machines | Docker (Containers) |
|---|---|---|
| Isolation unit | A whole machine, including its own OS/kernel | A group of processes, isolated via Linux namespaces/cgroups |
| Overhead | Heavy: each VM boots and runs a full guest OS | Light: containers share the host kernel |
| Startup time | Slow (boots an OS) | Fast (starts a process) |
| Resource usage | High (dedicated OS resources per VM) | Low (only the app's own footprint) |
| Isolation strength | Very strong (separate kernel per VM, hypervisor boundary) | Strong, but weaker than a VM (shared host kernel) |
| Use case | Running different OSes, strong security boundaries | Packaging and shipping applications quickly and consistently |

For this project, Docker was the natural choice: each service (NGINX,
WordPress, MariaDB, and the bonus services) is just a process plus its
dependencies, not a whole different operating system, so paying the cost of
a full VM per service would be unnecessary overhead for what is essentially
"install this software and run it in isolation."

### Secrets vs Environment Variables

- **Environment variables** (used throughout this project via `srcs/.env`
  and the `environment:` blocks in `docker-compose.yml`) are simple
  key/value pairs injected into a container. They are convenient for
  configuration, but they are visible to anyone able to run
  `docker inspect` on the container or read `/proc/<pid>/environ`, and they
  can leak into logs or crash dumps if the application isn't careful.
- **Docker secrets** are designed specifically for sensitive values
  (passwords, private keys, API tokens). In Swarm mode they are encrypted at
  rest and only mounted into memory (`/run/secrets/<name>`) inside the
  containers that need them, never exposed through `docker inspect` or baked
  into an image layer.

This project uses plain environment variables (via a git-ignored `.env`
file) for all credentials, which is acceptable for a local/evaluation Docker
Compose setup but is not how it would be handled in a production or Swarm
deployment, where the same values (DB passwords, WordPress admin password,
FTP password, ...) should instead be provided as Docker secrets so they
never appear in `docker inspect` output or shell history.

## Docker Networks

Docker provides several network drivers, the most common being:

- **bridge** *(used in this project)*: Each container runs in its own isolated
  network namespace and connects to a virtual bridge created by Docker.
  Containers on the same bridge network communicate using their service
  names through Docker's built-in DNS, while only ports explicitly published
  with `ports:` are accessible from outside the Docker network.
- **host**: The container shares the host's network stack directly. There is
  no network isolation, and the container uses the host's network interfaces
  and ports without port mapping.
- **none**: The container has no external network connectivity and only the
  loopback (`lo`) interface is available.

This project uses a single custom **bridge** network named `inception`.
All services (NGINX, WordPress, MariaDB, Redis, Adminer, FTP, and
Portainer) communicate through this private network using their Compose
service names. Only the services that must be reachable from outside Docker
publish ports to the host:

- **443** → NGINX
- **21** and **30000-30009** → FTP
- **8888** → Adminer
- **9443** → Portainer

Using a bridge network keeps inter-container communication private while
allowing controlled external access. Using `network_mode: host` is
forbidden by the Inception subject and would remove this network isolation.

---

## Docker Volumes

Docker provides two common ways to persist data outside a container's
writable layer: **named volumes** and **bind mounts**.

### Named Volumes

Named volumes are managed by Docker and are the recommended solution for
persistent application data.

This project defines the following named volumes:

- `wordpress_data`
- `mariadb_data`
- `portainer_data`

These volumes preserve important data such as MariaDB databases,
WordPress uploads, plugins and themes, and Portainer's configuration.
Containers can be recreated, updated, or replaced without losing this data.

### Bind Mounts

A bind mount maps an existing file or directory from the host directly into
a container.

Unlike named volumes, the storage location is chosen by the user rather
than Docker.

Examples used in this project include:

- `/home/<login>/data/mariadb`
- `/home/<login>/data/wordpress`
- `/var/run/docker.sock` (mounted into the Portainer container)

Bind mounts allow containers to access host files directly, making them
useful for persistent project data and for sharing resources such as the
Docker socket.

### Named Volumes vs Bind Mounts

| Named Volumes | Bind Mounts |
|---------------|-------------|
| Managed by Docker | Managed by the host filesystem |
| Docker manages the volume lifecycle | User specifies the exact host path |
| Recommended for persistent application data | Useful for sharing existing host files |
| Independent of a specific directory structure | Depends on the host filesystem layout |
| Easy to attach to multiple containers | Provides direct access to host files |

### How This Project Uses Storage

Although this project declares **named volumes** in
`docker-compose.yml`, they are configured with the Docker **local**
volume driver and bind to fixed directories on the host:

- `/home/<login>/data/mariadb`
- `/home/<login>/data/wordpress`

This approach combines Docker's volume management with the directory
structure required by the Inception subject. Data remains persistent
between container recreations while also being easy to locate, inspect,
and back up directly from the host.
## Resources

### Documentation & references

- [Docker official documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker networking overview](https://docs.docker.com/network/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker secrets (Swarm)](https://docs.docker.com/engine/swarm/secrets/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB server documentation](https://mariadb.com/kb/en/documentation/)
- [vsftpd documentation](https://security.appspot.com/vsftpd.html)
- [Redis documentation](https://redis.io/docs/latest/)
- [Adminer](https://www.adminer.org/)
- [Portainer documentation](https://docs.portainer.io/)
- [BigData Channel — Docker full course (YouTube)](https://youtu.be/PrusdhS2lmo):
  chapters used for the "Core Concepts" section above — Introduction to
  Containers, Container Architecture, Introduction to Docker, Images - Deep
  Dive, Docker Engine Architecture, Network, Storage, Dockerfile - Deep
  Dive, Docker Compose, Portainer. (Swarm, Stack, and Kubernetes chapters
  from the same video are not relevant to this project and were not used.)

<!-- ## ----------------------------------------------------------------------------------
# Intrucduction About Containers 



### virtual machines vs docker architecture



![Alternative text](https://media.geeksforgeeks.org/wp-content/uploads/20250823130235313168/virtual_machines.webp)


containersation since it come from 1970

the problem wost stockage and sucurity it's come concepte virtualisation
for make virtulisation need layer under the os hyperfiser 

virtsualisation is solve lettle problem but i still has it
like is OS it's take from rescourcace 

--> big problem it's has each virtula machine OS 
let's know OS : it's just karnel and kernale mode and user mode 

in my stituation not neeed user mode and kernel mode just need karnel 

{awal haja nhayd guest os and conect with host os that main idia containers }

that become all delete just install thing i need in user mode cmd packages ...

 
this is way can add app with all dependacies like create env foe spicifque app

----------------- but containarisation since from unix ---------------
![Alternative text](https://www.technologyuk.net/computing/operating-systems/images/monolithic_os_kernel.gif)


two thing important :

cgroup : feature that limits, measures, and isolates resource usage for a group of processes.

namespace : They make a process think it has its own system view, even though it’s sharing the same
            kernel with others.

when run first procee all thing return before it child it respoansible the namespaces (procis wahd kayno m9awm containers pid 1 how mas2ould application) 


---------------------- image --------------------------------

docker image : is build time cmd  just file and layers 
image and layers : 

Conyainers : are lightweight, isolated packages that bundle an application with all its dependencies (libraries, tools, config) so it runs the same everywhere.


---------------------- network ------------------------

can used temprary : 

type of network :

none   :  
host   : can access withoud export port out 
bridge :


------ stockage 

when i want see containers presstence /var/lib/docker/723f3276r23v2373v2376/diif

---------------------- dockerfile 


build context 

entrypoint ["cmd","arg"]

CMD = ["arg for entrypoint"]


time : [4:55]  -->






            