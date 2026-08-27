#!/usr/bin/env python3
"""Safely return a small, regular JSON state file on stdout."""

import os
import stat
import sys

MAX_STATE_BYTES = 64 * 1024


def main() -> int:
    if len(sys.argv) != 2:
        return 2

    flags = os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW

    try:
        fd = os.open(sys.argv[1], flags)
    except FileNotFoundError:
        return 0
    except OSError:
        return 1

    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_STATE_BYTES:
            return 1
        data = os.read(fd, MAX_STATE_BYTES + 1)
        if len(data) > MAX_STATE_BYTES:
            return 1
        sys.stdout.buffer.write(data)
        return 0
    except OSError:
        return 1
    finally:
        os.close(fd)


if __name__ == "__main__":
    raise SystemExit(main())
