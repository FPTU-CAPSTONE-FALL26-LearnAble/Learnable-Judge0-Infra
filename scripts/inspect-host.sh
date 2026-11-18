#!/usr/bin/env bash
# Run locally on the target EC2 after verifying its SSH identity.
# Avoid dumping configuration, environment variables or raw application logs.
set -u

section() {
    printf '\n%s\n' "$1"
}

section 'OS and kernel'
if [ -r /etc/os-release ]; then
    cat /etc/os-release
fi
uname -srmo

section 'CPU, memory and filesystems'
getconf _NPROCESSORS_ONLN
free -h
df -hT

section 'Cgroups'
stat -fc %T /sys/fs/cgroup
if [ -r /proc/cgroups ]; then
    cat /proc/cgroups
fi
if [ -r /sys/fs/cgroup/cgroup.controllers ]; then
    cat /sys/fs/cgroup/cgroup.controllers
fi

section 'Listening TCP ports'
if command -v ss >/dev/null 2>&1; then
    ss -lnt
fi

section 'Docker and Compose'
if ! command -v docker >/dev/null 2>&1; then
    printf 'Docker command unavailable\n'
    exit 0
fi
docker --version
docker compose version
if ! docker info --format 'Server={{.ServerVersion}} Architecture={{.Architecture}} CgroupDriver={{.CgroupDriver}} CgroupVersion={{.CgroupVersion}}' ; then
    printf 'Docker daemon inaccessible to this user. Have an authorized administrator run this script to complete inventory.\n'
    exit 1
fi

section 'Containers including stopped containers'
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

section 'Image inventory'
docker image ls --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'

section 'Volumes and networks'
docker volume ls
docker network ls
docker compose ls -a

section 'Container mount metadata and runtime permissions'
while IFS= read -r container_id; do
    [ -n "$container_id" ] || continue
    docker inspect --format 'Name={{.Name}} Image={{.Config.Image}} Privileged={{.HostConfig.Privileged}} Restart={{.HostConfig.RestartPolicy.Name}} MemoryBytes={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}unconfigured{{end}}' "$container_id"
    docker inspect --format '{{range .Mounts}}Type={{.Type}} Name={{.Name}} Source={{.Source}} Destination={{.Destination}} Writable={{.RW}}{{println}}{{end}}' "$container_id"
done < <(docker ps -aq)

section 'Remaining manual discovery'
printf '%s\n' \
    'Verify EC2 instance ID, current IP, security groups and SSH host fingerprint through the trusted AWS console.' \
    'Locate existing deployment/configuration files using mount paths and administrator knowledge.' \
    'Review secret names and presence only. Keep values and raw logs out of shared output.' \
    'Confirm Judge0 version from its authenticated API and image digest, database version, data ownership and backup policy.' \
    'Check firewall, HTTPS, reverse proxy, queue and CPU credit balance with appropriate read-only permissions.'
