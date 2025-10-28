Tailserver

Simple Python TCP tail server. Note: the logfile is expected to be ASCII encoded; undecodable bytes will be replaced.

Parameters
-- logfile (positional): path to the logfile to tail (ASCII encoded).
-- --host: network interface to bind to (default: 0.0.0.0). Set to 127.0.0.1 to restrict to localhost.
-- --port: TCP port to listen on (required).

Usage:

In PowerShell (host machine):

# Run directly

python tailserver.py C:\path\to\logfile --port 9000

docker build -t tailserver:latest .
docker run --rm -p 9000:9000 -v C:\path\to\logdir:/var/log tailserver:latest /var/log/myapp.log --port 9000

# Build Docker image

docker build -t tailserver:latest .

# Run container (mount logfile)

docker run --rm -p 9000:9000 -v C:\path\to\logdir:/var/log tailserver:latest /var/log/myapp.log --port 9000

Docker Compose example (docker-compose.yml)

```yaml
version: '3.8'
services:
	tailserver:
		image: tailserver:latest
		build: .
		ports:
			- "9000:9000"
		volumes:
			- C:\\path\\to\\logdir:/var/log:ro
		command: ["/var/log/myapp.log", "--host", "0.0.0.0", "--port", "9000"]
		restart: unless-stopped
```

Clients can connect via telnet or nc and will receive new lines as they are appended to the logfile. The server handles logrotate copytruncate by detecting file size shrinking and inode changes.
