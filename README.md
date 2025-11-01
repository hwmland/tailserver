# Tailserver

Simple Python TCP tail server. Note: the logfile is expected to be ASCII encoded; undecodable bytes will be replaced.

Parameters
-- logfile (positional): path to the logfile to tail (ASCII encoded).
-- --host: network interface to bind to (default: 0.0.0.0). Set to 127.0.0.1 to restrict to localhost.
-- --port: TCP port to listen on (required).

Usage:

## Run directly

```ps
python tailserver.py C:\path\to\logfile --port 9000
```

```sh
docker build -t tailserver:latest .
```

## Build Docker image

```sh
docker build -t tailserver:latest .
docker run --rm -p 9000:9000 -v logdir:/var/log tailserver:latest /var/log/myapp.log --port 9000
```

## Run container (mount logfile)

```sh
docker run --rm -p 9000:9000 -v logdir:/var/log ghcr.io/hwmland/tailserver:latest /var/log/myapp.log --port 9000
```

## Docker Compose example (docker-compose.yml)

```yaml
version: "3.8"
services:
  tailserver:
    image: ghcr.io/hwmland/tailserver:latest
    ports:
      - "9000:9000"
    volumes:
      - mylogdir:/var/log:ro
    command: ["/var/log/myapp.log", "--host", "0.0.0.0", "--port", "9000"]
    restart: unless-stopped
```

Clients can connect via telnet or nc and will receive new lines as they are appended to the logfile. The server handles logrotate copytruncate by detecting file size shrinking and inode changes.
