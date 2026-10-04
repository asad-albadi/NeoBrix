#!/usr/bin/env python3
"""Controlled stand-in for the workspace CLI in the isolated QML test."""
import os
import socket
import sys
import json

with socket.socket(socket.AF_UNIX) as connection:
    connection.connect(os.environ["NEOBRIX_TEST_SOCKET"])
    connection.settimeout(15)
    connection.sendall(json.dumps(sys.argv[1:]).encode() + b"\n")
    with connection.makefile("r") as stream:
        print(stream.readline().strip(), flush=True)
