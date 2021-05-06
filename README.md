# rsync-pair

A Docker container running rsync-over-ssh.
The `sshd` is locked down to only run a very specific
rsync push/pull command.

The client always initializes the sync, while the server
enforces strict jails.
