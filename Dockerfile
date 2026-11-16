FROM alpine:3.23 AS python-builder

ARG PYTHON_VERSION=3.12.16
ARG PYTHON_SHA512=adc13563d138248e5049e3d71f6497ff645e5fb3713fc14146fef8809608f447c7d205a6fa468434239504e56b9f826554e1a02c31c9e123e65b17030a7c2afc

RUN apk upgrade --no-cache \
    && apk add --no-cache --virtual .build-deps \
        build-base \
        bzip2-dev \
        expat-dev \
        gdbm-dev \
        libffi-dev \
        linux-headers \
        mpdecimal-dev \
        ncurses-dev \
        openssl-dev \
        readline-dev \
        xz-dev \
        zlib-dev \
        curl

# CPython's _sqlite3 is unused by tailserver; omit sqlite-dev so it is not built.
WORKDIR /tmp
RUN curl -fsSLo Python.tar.xz \
        "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz" \
    && echo "${PYTHON_SHA512}  Python.tar.xz" | sha512sum -c - \
    && tar -xJf Python.tar.xz

WORKDIR /tmp/Python-${PYTHON_VERSION}
# Keep only runtime files in the copied Python tree.
RUN ./configure \
        --prefix=/usr/local \
        --without-ensurepip \
        --with-system-expat \
        --with-system-libmpdec \
    && make -j2 \
    && make install \
    && python3 -c 'import argparse, asyncio, os, stat, time, ssl' \
    && ! python3 -c 'import _sqlite3' 2>/dev/null \
    && rm -rf \
        /usr/local/include \
        /usr/local/lib/pkgconfig \
        /usr/local/lib/libpython3.12.a \
        /usr/local/lib/python3.12/config-* \
        /usr/local/lib/python3.12/test \
        /usr/local/lib/python3.12/idlelib \
        /usr/local/lib/python3.12/tkinter \
        /usr/local/lib/python3.12/turtledemo \
        /usr/local/lib/python3.12/lib2to3 \
        /usr/local/lib/python3.12/ensurepip \
        /usr/local/lib/python3.12/pydoc_data \
        /usr/local/lib/python3.12/__pycache__ \
        /usr/local/share/man \
    && rm -f \
        /usr/local/bin/2to3* \
        /usr/local/bin/idle* \
        /usr/local/bin/pydoc3* \
        /usr/local/bin/python3-config

FROM alpine:3.23

RUN apk upgrade --no-cache \
    && apk add --no-cache \
        libbz2 \
        libexpat \
        libffi \
        gdbm \
        mpdecimal \
        ncurses-libs \
        libssl3 \
        readline \
        xz-libs \
        zlib

COPY --from=python-builder /usr/local /usr/local

# Image metadata (OCI labels)
# - org.opencontainers.image.description: short description of the image
# - org.opencontainers.licenses: SPDX license identifier
# - org.opencontainers.source: URL to the source repository
LABEL org.opencontainers.image.description="Simple Python tail-server that streams log lines over TCP"
LABEL org.opencontainers.licenses="MIT"
LABEL org.opencontainers.source="https://github.com/hwmland/tailserver"

# Ensure Python output is unbuffered in Docker logs and encoding is UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

WORKDIR /app
COPY tailserver.py /app/tailserver.py

RUN python3 -c 'import argparse, asyncio, os, stat, time, ssl' \
    && ! python3 -c 'import _sqlite3' 2>/dev/null \
    && ! apk info --installed sqlite-libs

USER 65532:65532

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/python3", "/app/tailserver.py"]
CMD ["/var/log/myapp.log", "--port", "9000"]
