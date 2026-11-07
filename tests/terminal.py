"""Run real LuaLS in a bounded PTY; retain terminal output on failure."""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

root = Path(__file__).resolve().parent.parent
artifacts = Path(tempfile.mkdtemp(prefix="lua-tools-terminal-"))
env = dict(os.environ, TERM="xterm-256color", LUA_TOOLS_ROOT=str(root),
           LUA_TOOLS_TEST_TMP=str(artifacts), LUA_TOOLS_SCRIPT=str(root / "tests/integration.lua"))
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
process = subprocess.Popen([os.environ.get("NVIM_BIN", "nvim"), "-u", "NONE", "-i", "NONE", "-n",
                            "-c", "lua dofile(vim.env.LUA_TOOLS_SCRIPT)"],
                           env=env, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
os.close(slave)
capture = bytearray()
deadline = time.monotonic() + 80
try:
    while process.poll() is None and time.monotonic() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            try:
                chunk = os.read(master, 65536)
                if not chunk:
                    break
                capture.extend(chunk)
            except OSError:
                break
    try:
        process.wait(timeout=max(0.1, deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)
    (artifacts / "terminal.log").write_bytes(capture)
    result = artifacts / "result"
    if not result.exists() or process.returncode:
        raise RuntimeError((result.read_text() if result.exists() else capture[-3000:].decode(errors="replace"))
                           + "\nPTY artifacts: " + str(artifacts))
    print(result.read_text(), end="")
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGKILL)
    process.wait()
    os.close(master)
