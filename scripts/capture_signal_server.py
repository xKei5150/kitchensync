#!/usr/bin/env python3
"""Echo listener for the integration suite's capture-signal handshake.

`shopping_mvp_emulator_test` and `shopping_visual_state_matrix_test` pause at
the point where a screenshot is meant to be taken and speak a real handshake:

    connect -> send one byte -> block on `socket.first` (20s) -> close

If nothing echoes a byte back the app blocks for 20 seconds and then the target
fails. A port number alone is not enough; a listener process must exist.

This server accepts connections until it is terminated, so it serves a target
that signals once (`shopping_mvp`, 1 signal) or several times
(`shopping_visual_state_matrix`, up to 3).
"""

from __future__ import annotations

import argparse
import socket
import sys


def serve(port: int, host: str = "127.0.0.1") -> int:
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((host, port))
    listener.listen(4)
    print(f"capture-signal listener ready on {host}:{port}", flush=True)

    served = 0
    try:
        while True:
            connection, _ = listener.accept()
            with connection:
                if not connection.recv(1):
                    continue
                connection.sendall(b"1")
                served += 1
                print(f"capture signal {served} acknowledged", flush=True)
    except KeyboardInterrupt:
        return served
    finally:
        listener.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int)
    parser.add_argument("--host", default="127.0.0.1")
    arguments = parser.parse_args()
    serve(arguments.port, arguments.host)
    return 0


if __name__ == "__main__":
    sys.exit(main())
