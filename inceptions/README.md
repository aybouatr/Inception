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

### Docker Network vs Host Network

Docker supports several network drivers:

- **none**: the container gets no network access at all.
- **bridge** (used here, via the custom `inception` network): the container
  gets its own private, isolated network namespace and virtual interface,
  connected to the host through a virtual bridge. Only explicitly published
  ports (`ports:`) are reachable from outside; every other port stays
  internal to the network, and containers reach each other by service name
  over Compose's built-in DNS.
- **host**: the container shares the host's network namespace directly,
  using the host's interfaces and ports as-is, with no isolation and no
  possibility of port remapping.

This project uses a single custom **bridge** network (`inception`) shared by
every service. This keeps all inter-container traffic (WordPress ↔
MariaDB, WordPress ↔ Redis, Adminer ↔ MariaDB, FTP ↔ the WordPress volume,
...) private to the Docker network, and only the ports that genuinely need
to be public (443 for NGINX, 21/30000-30009 for FTP, 8888 for Adminer, 9443
for Portainer) are published to the host. Using `network: host` is
explicitly disallowed by the subject and would defeat the purpose of
isolating each service.

### Docker Volumes vs Bind Mounts

Both let container data live outside the container's writable layer so it
survives container recreation, but they differ in where that data lives and
who manages it:

- **Volumes** (used here for `wordpress_data`, `mariadb_data`, and
  `portainer_data`) are managed entirely by Docker and stored under
  Docker's own storage area. They are the recommended way to persist data
  a container owns (a database's files, WordPress's uploads/themes/plugins,
  Portainer's state), are portable across hosts, and don't depend on a
  specific host directory structure.
- **Bind mounts** map an arbitrary, already-existing path on the host
  directly into the container. They're simpler and give direct access to
  host files, which is convenient for this project's requirement that data
  persist under `/home/<login>/data/...` on the host (created by
  `make setup`), and for mounting the Docker socket
  (`/var/run/docker.sock`) into the Portainer container so it can control
  the Docker daemon — but they tie the setup to the host's own filesystem
  layout and give the container direct read/write access to that part of
  the host.

In practice this project combines both: named volumes are declared in
`docker-compose.yml`, but they are backed by fixed bind-mount paths on the
host (`/home/<user>/data/mariadb`, `/home/<user>/data/wordpress`) so the
data is both managed through Docker's volume model and easy to locate,
back up, or inspect directly on the host.

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


# ----------------------------------

*This project has been created as part of the 42 curriculum by [your_login].*

# Containers & Docker

## Description

This project is an introduction to containerization, with Docker as the main
tool used to explore the concept in practice.

Before virtualization, running multiple isolated applications on the same
physical machine meant either dedicating separate hardware to each of them
(expensive, wasteful) or running them side by side with no isolation
(insecure, fragile). Virtual machines solved the isolation and resource-sharing
problem by adding a hypervisor layer under the operating system, allowing
several guest OSes to run on a single host. This works, but it is heavy: every
virtual machine ships and runs its own full operating system (kernel + user
space), which costs CPU, memory, and disk just to keep each guest OS alive.

Containers take a lighter approach. An operating system is really just a
kernel (kernel mode) plus the user-space tools and libraries that run on top
of it (user mode). In most cases, what an application actually needs is not a
whole separate kernel — it needs its own isolated user space. Containers
exploit this: instead of virtualizing an entire machine and guest OS, they
isolate a group of processes at the kernel level and give each group its own
view of the system (its own filesystem, processes, network, etc.), while all
containers share the same host kernel.

The goal of this project is to understand:
- why containers exist and what problem they solve compared to full
  virtualization,
- the Linux kernel mechanisms that make containers possible (`cgroups` and
  `namespaces`),
- how Docker images, layers, networking, and storage work,
- how to write and use a `Dockerfile` to package an application.

## Instructions

### Requirements
- A Linux-based system (or WSL2 / a VM) with a working internet connection
- [Docker Engine](https://docs.docker.com/engine/install/) installed
- (Optional) `docker-compose` if the project uses multiple services

### Build the image
```bash
docker build -t <image_name> .
```

### Run a container
```bash
docker run --name <container_name> <image_name>
```

Useful flags:
- `-d` : run in detached mode (background)
- `-it` : run interactively with a TTY (useful for debugging/shell access)
- `-p <host_port>:<container_port>` : expose a container port on the host
- `-v <host_path>:<container_path>` : mount a host directory into the container
- `--network <network_name>` : attach the container to a specific network

### Stop / clean up
```bash
docker stop <container_name>
docker rm <container_name>
docker rmi <image_name>
```

### Inspect a container's filesystem layer
```bash
sudo ls /var/lib/docker/overlay2/<container_layer_id>/diff
```

## Project Description

### Docker in this project

Docker is used here to package the application (and its dependencies) into
one or more images, and to run those images as isolated, reproducible
containers. Each service of the project runs in its own container, built from
a `Dockerfile` that defines the base image, the dependencies to install, the
files to copy in, and the command to run when the container starts
(`ENTRYPOINT` / `CMD`).

Two Linux kernel features make this isolation possible without needing a
full guest OS:

- **cgroups** (control groups): limit and measure the resources (CPU, memory,
  I/O, etc.) that a group of processes is allowed to use.
- **namespaces**: give a process its own isolated view of the system (PIDs,
  network interfaces, mount points, hostname, etc.) even though it shares the
  same kernel with every other process on the host. The first process started
  inside a container (PID 1) is responsible for reaping its child processes,
  exactly like an init system would on a full machine.

A Docker **image** is a read-only template built at build time from a
`Dockerfile`. It is made of stacked, cached **layers**, each corresponding to
one instruction in the `Dockerfile`. A **container** is a running instance of
an image: a lightweight, isolated environment that bundles an application
with all of its dependencies (libraries, tools, configuration) so that it
behaves the same on any machine.

### Virtual Machines vs Docker

| | Virtual Machines | Docker (Containers) |
|---|---|---|
| Isolation unit | Whole machine, including its own OS/kernel | A group of processes, isolated via namespaces/cgroups |
| Overhead | Heavy: each VM runs a full guest OS | Light: containers share the host kernel |
| Startup time | Slow (boots an OS) | Fast (starts a process) |
| Resource usage | High (dedicated OS resources per VM) | Low (only the app's own footprint) |
| Isolation strength | Very strong (separate kernel per VM) | Strong, but weaker than a VM (shared kernel) |
| Use case | Running different OSes, strong security boundaries | Packaging and shipping applications quickly and consistently |

### virtual machines vs docker architecture
![Alternative text](https://media.geeksforgeeks.org/wp-content/uploads/20230109130229/Docker-vs-VM.png)

In short: VMs virtualize the hardware and run a full OS per instance, which
is heavy but very isolated. Containers virtualize at the OS level, sharing
one kernel across many isolated processes, which is much lighter but relies
on the kernel itself being secure and up to date.

### Secrets vs Environment Variables

- **Environment variables** are simple key/value pairs passed to a
  container (`-e KEY=value`, or an `.env` file). They are easy to use but are
  visible to anyone who can inspect the container (`docker inspect`,
  `/proc/<pid>/environ`), and they can end up in logs, image layers, or
  process listings if not handled carefully.
- **Secrets** (e.g. Docker Secrets, or files mounted read-only at runtime)
  are meant specifically for sensitive data (passwords, API keys, certificates).
  They are stored encrypted and are only mounted into memory/a tmpfs inside
  the container at runtime, not baked into the image or exposed through
  ordinary environment inspection.

Rule of thumb: use environment variables for non-sensitive configuration, and
secrets for anything that must stay confidential (passwords, private keys,
tokens).

### Docker Network vs Host Network

Docker supports several network drivers:

- **none**: the container has no network access at all.
- **bridge** (default): the container gets its own private, isolated network
  namespace and virtual interface, connected to the host through a virtual
  bridge. Ports must be explicitly published (`-p`) to be reachable from
  outside.
- **host**: the container shares the host's network namespace directly. It
  uses the host's network interfaces and ports as-is — no port mapping is
  needed (and none is possible), but this also means less isolation between
  the container and the host network stack.

In short: the **bridge** network isolates the container's network stack from
the host (safer, requires explicit port publishing), while the **host**
network gives the container direct access to the host's networking (faster,
simpler for some use cases, but less isolated).

### Docker Volumes vs Bind Mounts

Both let a container persist or share data with the host filesystem, but they
differ in where that data lives and who manages it:

- **Volumes**: managed entirely by Docker, stored under Docker's own storage
  area (e.g. `/var/lib/docker/volumes/`). They are the preferred way to
  persist data generated by containers (databases, uploads, etc.), are
  portable, and can be backed up, shared between containers, or driven by
  volume plugins.
- **Bind mounts**: map an arbitrary path on the host filesystem directly into
  the container. They are simpler and give direct access to host files
  (useful for development, e.g. mounting source code), but they depend on the
  host's directory structure and are less portable, and give the container
  direct read/write access to that part of the host filesystem.

Rule of thumb: use **volumes** for data the container itself owns and should
persist across restarts, and **bind mounts** when you specifically need to
share existing files/directories from the host (e.g. live-reloading code
during development).

## Resources

### Documentation & references
- [Docker official documentation](https://docs.docker.com/)
- [Docker Engine overview](https://docs.docker.com/engine/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker networking overview](https://docs.docker.com/network/)
- [Docker storage overview](https://docs.docker.com/storage/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/)
- Linux manual pages: `man cgroups`, `man namespaces`
- [What even is a container: namespaces and cgroups (Julia Evans)](https://jvns.ca/blog/2016/10/10/what-even-is-a-container/)

### AI usage

An AI assistant (Claude) was used to:
- reorganize and rewrite raw personal notes taken while learning about
  containers, cgroups, namespaces, and Docker, into clear, well-structured
  English sections,
- fill gaps in the notes with standard, verifiable technical explanations
  (e.g. image/layer structure, network driver behavior, volumes vs bind
  mounts),
- format the final document according to the 42 README requirements
  (mandatory sections, comparison tables).

All technical content was reviewed against the official Docker documentation
referenced above. No project-specific code or configuration was generated by
AI.




## ----------------------------------------------------------------------------------
# Intrucduction About Containers 

containersation since it come from 1970

the problem wost stockage and sucurity it's come concepte virtualisation
for make virtulisation need layer under the os hyperfiser 

virtsualisation is solve lettle problem but i still has it
like is OS it's take from rescourcace 

--> big problem it's has each virtula machine OS 
let's know OS : it's just karnel and kernale mode and user mode 

![Alternative text](https://media.geeksforgeeks.org/wp-content/uploads/20250823130235313168/virtual_machines.webp)

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


time : [4:55] 






            