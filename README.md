# rsync-pair

![License](https://img.shields.io/badge/License-BlueOak-blue)

A Docker container running rsync-over-ssh.
The server `sshd` is locked down to only run a very specific
set of rsync commands limiting what can be synced.

## Push vs Pull

The task names are named from the perspective of the client.

```
           Client              Server
"push"   /media/push  ---->  /media/push
"pull"   /media/pull  <----  /media/pull
```

Therefore it's recommended to set the following volumes as read-only:
- `/media/push` on the _client_.
- `/media/pull` on the _server_.

## Permissions

Both sides will run with root permissions. This is to preserve the
original file permissions and properties as much as possible.
However between running in a container, the strict rsync command and
the read-only flag for volumes, risks are limited.

## First run

On first run, you'll likely have two issues.
The client doesn't know the server identity and vice versa.

1. Run your client first, which will output a line like:
	```
	Make sure to authorize the following public key:
	ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHazGX/GQFEGXB8yBBdOVkjF1b0kISPWsf4ZNnL9DrZG root@bef99dedad09
	```
2. Add this to your server's `PUSH_KEY` / `PULL_KEY` environment and restart.
3. Add `StrictHostKeyChecking no` to your client's `SSH_CONFIG` to automatically add the server as a known host.
4. On subsequent runs, `StrictHostKeyChecking no` can be removed or set to `yes`.

## Volumes

**Client**

- `/root/.ssh` - for client identity key and `known_hosts`.
- `/media/push` (`:ro`) - directory to read from for pushing to the server.
- `/media/pull` - directory to write to for pulling from the server.

**Server**

- `/keys` - for storing the server identity keys.
- `/media/push` - directory to write to when data is pushed to the server.
- `/media/pull` (`:ro`) - directory to read from when data is pulled from the server.

## Custom ports, bastion servers, etc.

By default the client and server use the standard port 22.
Plus you might want to layer additional security measures on top of what this image offers.

For the server, simply use docker's port publishing.

```yaml
version: "3.4"
services:
  server:
    image: ghcr.io/beanow/rsync-pair
    command: server
    ports:
      - 5022:22
    # ...
```

For the client, you'll want to use the `SSH_CONFIG` environment.


```yaml
version: "3.4"
services:
  client:
    image: ghcr.io/beanow/rsync-pair
    command: client
    environment:
      PULL_FROM: server
      PUSH_TO: server
      SSH_CONFIG: |
        LogLevel DEBUG
        Host server
          HostName 10.20.0.5
          Port 5022
          ProxyJump bastion.example.org
        Host bastion.example.org
          Port 5023
          User bastion-user
          IdentitiesOnly yes
          IdentityFile /path/to/key
    # ...
```

## Local test

```
DOCKER_BUILDKIT=1 docker-compose up --build --force-recreate
```

## Building for production

```
docker buildx create --use
docker buildx build --push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 \
	--tag ghcr.io/beanow/rsync-pair:latest src
```
