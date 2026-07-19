



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






            