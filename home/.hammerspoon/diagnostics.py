#!/usr/bin/env python3
"""Opt-in event codes only. No titles, paths, app names or subprocess output."""
import fcntl
import os
from pathlib import Path
import stat
import sys
import time

EVENTS = set("""aerospace-failed aerospace-timeout aerospace-sequence-failed
notification-timeout notification-refresh-failed notification-clear-failed
terminal-stack-skipped terminal-window-split inherit-target inherit-move
inherit-failed inherit-fixed-skipped window-created dialog-repair
dialog-repair-failed watcher-started aerospace-missing reveal-no-window
reveal-window attention-clear attention-watcher-started""".split())
MAX_BYTES = 64 * 1024
MAX_AGE = 24 * 60 * 60


def write_event(home, event, code, now=None):
    if event not in EVENTS or not -255 <= int(code) <= 255:
        raise ValueError("Invalid diagnostic event")
    now = int(time.time() if now is None else now)
    # Resolve HOME itself (macOS may provide an alias), but no child symlinks.
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    root = os.open(str(Path(home).resolve()), flags)
    try:
        base = os.open(".hammerspoon", flags, dir_fd=root)
    finally:
        os.close(root)
    try:
        try:
            os.mkdir("diagnostics", 0o700, dir_fd=base)
        except FileExistsError:
            pass
        directory = os.open("diagnostics", flags, dir_fd=base)
    finally:
        os.close(base)
    try:
        info = os.fstat(directory)
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError("Diagnostic directory must be owned by you and mode 0700")
        fd = os.open("events.log", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                     0o600, dir_fd=directory)
        with os.fdopen(fd, "r+", encoding="ascii") as output:
            info = os.fstat(output.fileno())
            if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or
                    info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600):
                raise ValueError("Diagnostic log must be a private regular file")
            fcntl.flock(output, fcntl.LOCK_EX)
            info = os.fstat(output.fileno())
            # Retention is evaluated on each enabled write, not by a daemon.
            first = output.readline(128).split(" ", 1)[0]
            expired = not first.strip().isdigit() or now - int(first) >= MAX_AGE
            if expired or info.st_size >= MAX_BYTES - 128:
                output.seek(0)
                output.truncate()
            output.seek(0, os.SEEK_END)
            output.write("%d %s %d\n" % (now, event, int(code)))
    finally:
        os.close(directory)


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Expected event and exit code")
        write_event(os.environ["HOME"], sys.argv[1], int(sys.argv[2]))
    except (OSError, ValueError, KeyError):
        # Never echo a path/argument that might contain sensitive text.
        print("Private diagnostics refused; check path ownership and permissions.", file=sys.stderr)
        sys.exit(1)
