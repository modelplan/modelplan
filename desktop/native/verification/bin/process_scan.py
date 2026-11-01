# SPDX-License-Identifier: MIT
"""Project-scoped process scan for one run, by executable path and recorded helper identity only.

Never matches by process name and never reads another process's environment or arguments. A
process is in scope only when it belongs to the effective user and either
- its resolved executable path is exactly the run's subject executable,
- its resolved executable path lies under the run's scratch prefix (the LaunchServices .app), or
- it is a helper this run spawned itself (exec gate, `open -n` helper), recorded at spawn time by
  PID plus start time, so a reused PID with a different start time never matches.
The only per-process reads are the executable path (/proc/<pid>/exe, proc_pidpath) and the owner
and start identity (the caller's `identity`).
"""
import ctypes
import os
import sys

SCOPE_KEYS = {'executable', 'prefix', 'helpers'}
IDENTITY_KEYS = ('pid', 'startSeconds', 'startMicroseconds')


def _path(value):
    return isinstance(value, str) and value.startswith('/') and bool(value.rstrip('/')) and '\0' not in value


def _helper(value):
    return (isinstance(value, dict) and set(value) == set(IDENTITY_KEYS)
            and all(type(value[k]) is int for k in IDENTITY_KEYS) and value['pid'] > 0)


def valid_scope(scope):
    """At least one absolute, non-root path, and well-formed helper identities; nothing else."""
    if not isinstance(scope, dict) or set(scope) - SCOPE_KEYS:
        return False
    paths = [scope[k] for k in ('executable', 'prefix') if k in scope]
    helpers = scope.get('helpers', [])
    return (bool(paths) and all(_path(p) for p in paths)
            and isinstance(helpers, list) and all(_helper(h) for h in helpers))


def scope_for(executable=None, prefix=None, helpers=()):
    scope = {}
    if executable is not None:
        scope['executable'] = os.path.realpath(executable)
    if prefix is not None:
        scope['prefix'] = os.path.realpath(prefix)
    scope['helpers'] = [{k: h[k] for k in IDENTITY_KEYS} for h in helpers]
    if not valid_scope(scope):
        raise ValueError('scan scope needs an absolute executable path or scratch prefix')
    return scope


def with_helper(scope, ident):
    """The scope plus one helper identity recorded at spawn time."""
    if not isinstance(ident, dict):
        raise ValueError('helper identity unavailable')
    helper = {k: ident.get(k) for k in IDENTITY_KEYS}
    if not _helper(helper):
        raise ValueError('helper identity unavailable')
    return dict(scope, helpers=[*scope.get('helpers', []), helper])


def _linux_candidates():
    me = os.getpid()
    for entry in os.listdir('/proc'):
        if not entry.isdigit() or int(entry) == me:
            continue
        pid = int(entry)
        try:
            if os.stat(f'/proc/{pid}').st_uid != os.geteuid():
                continue
            yield pid, os.readlink(f'/proc/{pid}/exe')
        except OSError:
            continue


def _darwin_candidates():
    proc = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    proc.proc_listallpids.argtypes = [ctypes.c_void_p, ctypes.c_int]
    proc.proc_listallpids.restype = ctypes.c_int
    proc.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    proc.proc_pidpath.restype = ctypes.c_int
    estimate = proc.proc_listallpids(None, 0)
    if estimate <= 0:
        raise OSError(ctypes.get_errno(), 'proc_listallpids failed')
    pids = (ctypes.c_int * (estimate + 512))()
    count = proc.proc_listallpids(pids, ctypes.sizeof(pids))
    if count <= 0:
        raise OSError(ctypes.get_errno(), 'proc_listallpids failed')
    me = os.getpid()
    path = ctypes.create_string_buffer(4096)  # PROC_PIDPATHINFO_MAXSIZE
    for pid in list(pids[:count]):
        if pid <= 0 or pid == me:
            continue
        n = proc.proc_pidpath(pid, path, 4096)
        if n > 0:
            yield pid, os.fsdecode(path.raw[:n])


def _in_scope(exe, scope):
    if not isinstance(exe, str):
        return None
    if scope.get('executable') is not None and exe == scope['executable']:
        return 'executable'
    prefix = scope.get('prefix')
    if prefix is not None and exe.startswith(prefix.rstrip('/') + '/'):
        return 'prefix'
    return None


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
    found, seen = [], set()
    for helper in scope.get('helpers', []):
        ident = identity(helper['pid'])
        if ident is not None and all(ident.get(k) == helper[k] for k in IDENTITY_KEYS):
            found.append(dict(ident, matchedBy='helper')); seen.add(helper['pid'])
    for pid, exe in candidates:
        matched = _in_scope(exe, scope)
        if matched is None or pid in seen:
            continue
        ident = identity(pid)
        if ident is not None:  # owned by this user and still alive
            found.append(dict(ident, matchedBy=matched)); seen.add(pid)
    return found
