# Clean multi-stage Dockerfile (safe copy). Rename to Dockerfile to use.
FROM python:3.12-alpine AS builder

WORKDIR /build
COPY tailserver.py /build/tailserver.py

# Optional: keep compileall if you want the bytecode for caching purposes
RUN python -m compileall -q .

FROM alpine:3.19

RUN apk add --no-cache python3

# Ensure Python output is unbuffered in Docker logs and encoding is UTF-8
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

WORKDIR /app
# Copy the source file (let the runtime Python create its own .pyc)
COPY tailserver.py /app/tailserver.py

EXPOSE 9000

ENTRYPOINT ["/usr/bin/python3", "/app/tailserver.py"]
CMD ["/var/log/myapp.log", "--port", "9000"]
