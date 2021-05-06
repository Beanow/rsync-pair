# rsync-pair

![License](https://img.shields.io/badge/License-BlueOak-blue)

A Docker container running rsync-over-ssh.
The `sshd` is locked down to only run a very specific
rsync push/pull command.

The client always initializes the sync, while the server
enforces strict jails.

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
