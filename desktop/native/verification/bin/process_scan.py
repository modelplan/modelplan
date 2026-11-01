# SPDX-License-Identifier: MIT
"""Project-scoped process scan for one run: owned processes by exact executable path or synthetic HOME.

Never matches by process name. A process matches only when it belongs to the effective user and
either its executable path is exactly the run's subject executable (resolved) or its environment
carries exactly `HOME=<the run's fresh synthetic home>`. Both are unique per run (run scratch,
`mkdir(exist_ok=False)`), so a match is this run's subject, its exec gate or its LaunchServices
`open` helper, never an unrelated process.
"""
import ctypes
import os
from pathlib import Path
import sys


def valid_scope(scope):
    """A scope names at least one absolute, non-root path; anything else cannot be scanned."""
    if not isinstance(scope, dict) or set(scope) - {'executable', 'home'}:
        return False
    values = [v for v in (scope.get('executable'), scope.get('home')) if v is not None]
    return bool(values) and all(isinstance(v, str) and v.startswith('/') and v.rstrip('/') and '\0' not in v
                                for v in values)


def scope_for(executable=None, home=None):
    scope = {}
    if executable is not None:
        scope['executable'] = os.path.realpath(executable)
    if home is not None:
        scope['home'] = str(home)  # the literal value placed in the subject's environment
    if not valid_scope(scope):
        raise ValueError('scan scope needs an absolute executable path or synthetic home')
    return scope


def _linux_candidates():
    me = os.getpid()
    for entry in os.listdir('/proc'):
        if not entry.isdigit() or int(entry) == me:
            continue
        pid = int(entry)
        try:
            if os.stat(f'/proc/{pid}').st_uid != os.geteuid():
                continue
        except OSError:
            continue
        def exe(pid=pid):
            try:
                return os.readlink(f'/proc/{pid}/exe')
            except OSError:
                return None
        def home(pid=pid):
            try:
                raw = Path(f'/proc/{pid}/environ').read_bytes()
            except OSError:
                return None
            return _home_from(raw.split(b'\0'))
        yield pid, exe, home


def _home_from(items):
    for item in items:
        if item == b'':
            break
        if item.startswith(b'HOME='):
            return os.fsdecode(item[5:])
    return None


def _darwin_candidates():
    proc = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
    proc.proc_listallpids.argtypes = [ctypes.c_void_p, ctypes.c_int]
    proc.proc_listallpids.restype = ctypes.c_int
    proc.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    proc.proc_pidpath.restype = ctypes.c_int
    libc.sysctl.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_uint, ctypes.c_void_p,
                            ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p, ctypes.c_size_t]
    libc.sysctl.restype = ctypes.c_int
    estimate = proc.proc_listallpids(None, 0)
    if estimate <= 0:
        raise OSError(ctypes.get_errno(), 'proc_listallpids failed')
    pids = (ctypes.c_int * (estimate + 512))()
    count = proc.proc_listallpids(pids, ctypes.sizeof(pids))
    if count <= 0:
        raise OSError(ctypes.get_errno(), 'proc_listallpids failed')
    argmax = ctypes.c_int(0); size = ctypes.c_size_t(ctypes.sizeof(argmax))
    mib = (ctypes.c_int * 2)(1, 8)  # CTL_KERN, KERN_ARGMAX
    if libc.sysctl(mib, 2, ctypes.byref(argmax), ctypes.byref(size), None, 0) != 0 or argmax.value <= 0:
        raise OSError(ctypes.get_errno(), 'KERN_ARGMAX unavailable')
    buffer = ctypes.create_string_buffer(argmax.value)
    me = os.getpid()
    for pid in list(pids[:count]):
        if pid <= 0 or pid == me:
            continue
        def exe(pid=pid):
            path = ctypes.create_string_buffer(4096)  # PROC_PIDPATHINFO_MAXSIZE
            n = proc.proc_pidpath(pid, path, 4096)
            return os.fsdecode(path.raw[:n]) if n > 0 else None
        def home(pid=pid):
            length = ctypes.c_size_t(argmax.value)
            args = (ctypes.c_int * 3)(1, 49, pid)  # CTL_KERN, KERN_PROCARGS2, pid
            if libc.sysctl(args, 3, buffer, ctypes.byref(length), None, 0) != 0 or length.value < 4:
                return None
            raw = buffer.raw[:length.value]
            argc = int.from_bytes(raw[:4], sys.byteorder)
            rest = raw[4:]
            pos = rest.find(b'\0')  # end of exec_path, followed by NUL padding
            if pos < 0:
                return None
            while pos < len(rest) and rest[pos] == 0:
                pos += 1
            parts = rest[pos:].split(b'\0')
            return _home_from(parts[argc:]) if len(parts) > argc else None
        yield pid, exe, home


def scan(scope, identity, candidates=None):
    """Identities of owned processes inside `scope`. `identity(pid)` must return None for other users.

    Each result is the identity dict (pid plus start time) with `matchedBy` naming the criterion.
    Raises OSError when the platform enumeration itself fails: an unreadable process table is
    never reported as "nothing found".
    """
    if not valid_scope(scope):
        raise ValueError('invalid scan scope')
    if candidates is None:
        candidates = _darwin_candidates() if sys.platform == 'darwin' else _linux_candidates()
    found = []
    for pid, exe, home in candidates:
        matched = None
        if scope.get('executable') is not None and exe() == scope['executable']:
            matched = 'executable'
        elif scope.get('home') is not None and home() == scope['home']:
            matched = 'home'
        if matched is None:
            continue
        ident = identity(pid)
        if ident is not None:  # owned by this user and still alive
            found.append(dict(ident, matchedBy=matched))
    return found
