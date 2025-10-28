# Clean multi-stage Dockerfile (safe copy). Rename to Dockerfile to use.
FROM python:3.12-alpine AS builder

WORKDIR /build
COPY tailserver.py /build/tailserver.py

# Byte-compile the script to .pyc (quiet)
RUN python -m compileall -q . \
    && mkdir -p /out \
    && cp __pycache__/tailserver.*.pyc /out/tailserver.pyc || true

FROM alpine:3.19

# Install minimal Python runtime
RUN apk add --no-cache python3

WORKDIR /app
# Copy only the compiled bytecode to keep the image minimal
COPY --from=builder /out/tailserver.pyc /app/tailserver.pyc

EXPOSE 9000

ENTRYPOINT ["/usr/bin/python3", "/app/tailserver.pyc"]
CMD ["/var/log/myapp.log", "--port", "9000"]
