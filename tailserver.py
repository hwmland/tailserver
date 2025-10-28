#!/usr/bin/env python3
"""
Simple TCP tail server:
- Accepts multiple clients concurrently
- Watches a logfile and broadcasts new lines to all connected clients
- Handles logrotate with copytruncate by checking file inode/size and seeking appropriately
- CLI: logfile, --host (default 0.0.0.0), --port
"""

import argparse
import asyncio
import os
import stat
import time


async def tail_file(path, broadcaster, poll_interval=0.2):
    """Watch file and send appended lines to broadcaster(callback).
    Handles copytruncate by detecting if file was truncated or replaced.
    broadcaster(line: str)
    """
    try:
        # Logfile is ASCII encoded; replace undecodable bytes if any
        with open(path, "r", encoding="ascii", errors="replace") as f:
            # Seek to end
            f.seek(0, os.SEEK_END)
            inode = os.fstat(f.fileno()).st_ino
            while True:
                where = f.tell()
                line = f.readline()
                if line:
                    await broadcaster(line)
                else:
                    await asyncio.sleep(poll_interval)
                    try:
                        stat_info = os.stat(path)
                    except FileNotFoundError:
                        # File removed; wait until it reappears
                        await asyncio.sleep(poll_interval)
                        continue
                    # If inode changed, reopened file (rotated)
                    try:
                        cur_inode = stat_info.st_ino
                    except AttributeError:
                        cur_inode = None
                    if cur_inode is not None and cur_inode != inode:
                        # Reopen the file and continue
                        try:
                            newf = open(path, "r", encoding="ascii", errors="replace")
                        except Exception:
                            await asyncio.sleep(poll_interval)
                            continue
                        f.close()
                        f = newf
                        inode = os.fstat(f.fileno()).st_ino
                        # start at beginning of new file
                        continue
                    # Detect truncation (copytruncate) by comparing size
                    try:
                        if stat_info.st_size < where:
                            f.seek(0, os.SEEK_SET)
                    except Exception:
                        pass
    except Exception as e:
        print(f"tail_file error: {e}")


class Broadcaster:
    def __init__(self):
        self.clients = set()
        self.lock = asyncio.Lock()

    async def register(self, writer: asyncio.StreamWriter):
        async with self.lock:
            self.clients.add(writer)

    async def unregister(self, writer: asyncio.StreamWriter):
        async with self.lock:
            self.clients.discard(writer)

    async def broadcast(self, data: str):
        async with self.lock:
            to_remove = []
            for w in list(self.clients):
                try:
                    w.write(data.encode("utf-8"))
                    await w.drain()
                except Exception:
                    to_remove.append(w)
            for w in to_remove:
                self.clients.discard(w)


async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter, broadcaster: Broadcaster):
    addr = writer.get_extra_info("peername")
    print(f"Client connected: {addr}")
    await broadcaster.register(writer)
    try:
        # Keep the connection open until client disconnects
        while True:
            data = await reader.read(100)
            if not data:
                break
            # Optional: could support simple commands from client
    finally:
        print(f"Client disconnected: {addr}")
        await broadcaster.unregister(writer)
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def main():
    parser = argparse.ArgumentParser(description="Tail a logfile and stream new lines over TCP to clients.")
    parser.add_argument("logfile", help="Path to logfile to tail")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind (default 0.0.0.0)")
    parser.add_argument("--port", type=int, required=True, help="Port to listen on")
    args = parser.parse_args()

    broadcaster = Broadcaster()

    server = await asyncio.start_server(lambda r, w: handle_client(r, w, broadcaster), host=args.host, port=args.port)
    addr = server.sockets[0].getsockname()
    print(f"Serving on {addr}, tailing {args.logfile}")

    tail_task = asyncio.create_task(tail_file(args.logfile, broadcaster.broadcast))

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Shutting down")
