#!/usr/bin/env python3
"""Read the user's own usage windows from files the harnesses already write on this machine.

Sources (read-only; nothing is sent anywhere):
  - Codex: token_count rate_limits in the recent $CODEX_HOME/sessions/**/rollout-*.jsonl, merged
    per limit id; model and effort from the calling thread (CODEX_THREAD_ID) or the newest
    interactive one, never from background review threads
  - Claude Code: the snapshot `modelplan statusline` records in the Model Plan cache
  - ~/.config/modelplan/local.json, maintained by the user (no secrets)

Prints one JSON report, the same shape as `modelplan quota --json`. Never reads credential
files, never prints raw log lines or unknown fields. Mirrors cli/internal/quota.
"""
import argparse
import datetime as dt
import json
import math
import os
from pathlib import Path
import re
import stat
import sys

NOTE = ("Local observations only, read from files on this machine; never sent anywhere. "
        "Percentages are the harness's own usage meters, not token or task counts. "
        "Pace and headroom are estimates that assume the recent rate of use continues.")
STALE_AFTER = 60  # minutes
DEFAULT_MINUTES = {"five_hour": 300, "weekly": 10080, "monthly": 43200}
IDENT = re.compile(r"[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,95}")
ROLLOUT = re.compile(r"rollout-.*\.jsonl")
CODEX_FILES, CODEX_TAIL, CODEX_HEAD = 8, 4 << 20, 1 << 20


def iso(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if t else None


def parse_time(v):
    if not isinstance(v, str) or not v or len(v) > 40:
        return None
    try:
        t = dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    except ValueError:
        return None
    return t.astimezone(dt.timezone.utc) if t.tzinfo else None


def from_unix(v):
    if type(v) is not int or v <= 0:
        return None
    return dt.datetime.fromtimestamp(v, dt.timezone.utc)


def finite(v, lo, hi):
    return v if type(v) in (int, float) and math.isfinite(v) and lo <= v <= hi else None


def clip(v):
    if not isinstance(v, str):
        return ""
    v = v.strip()
    return v if len(v) <= 80 and IDENT.fullmatch(v) else ""


def round1(v):
    return math.floor(v * 10 + 0.5) / 10 if v >= 0 else -math.floor(-v * 10 + 0.5) / 10


def read_bounded(path, limit):
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return None, "missing"
    except OSError:
        return None, "unreadable"
    if not stat.S_ISREG(info.st_mode):
        return None, "unsafe_path"
    if info.st_size > limit:
        return None, "too_large"
    try:
        with open(path, "rb") as f:
            return f.read(limit + 1), ""
    except OSError:
        return None, "unreadable"


def window(kind, used, resets_at, observed, minutes=0, mode="fixed", limit=""):
    w = {"kind": kind}
    if limit:
        w["limit"] = limit
    w["usedPercent"] = used
    if minutes:
        w["windowMinutes"] = minutes
    w["resetsAt"] = resets_at
    if mode:
        w["resetMode"] = mode
    w["observedAt"] = observed
    return w


# ---- Claude Code snapshot (written by `modelplan statusline`)

def read_claude_code(cache):
    st = {"source": "claude-code"}
    raw, status = read_bounded(os.path.join(cache, "observed", "claude-code.json"), 64 << 10)
    if status:
        st["status"] = status
        if status == "missing":
            st["reason"] = "no status-line snapshot yet; install the Model Plan status line in Claude Code"
        return [], st
    try:
        s = json.loads(raw)
        assert isinstance(s, dict) and s.get("schemaVersion") == 1
        observed = parse_time(s.get("observedAt"))
        h = s.get("harness") if isinstance(s.get("harness"), dict) else {}
        harness = {k: clip(h.get(k)) for k in ("model", "effort") if clip(h.get(k))}
        if isinstance(h.get("fastMode"), bool):
            harness["fastMode"] = h["fastMode"]
        if clip(h.get("version")):
            harness["version"] = clip(h["version"])
        windows = []
        for w in s.get("windows") or []:
            kind = w.get("kind") if w.get("kind") in ("five_hour", "weekly", "spend") else "unknown"
            x = window(kind, finite(w.get("usedPercent"), 0, 1000), parse_time(w.get("resetsAt")),
                       parse_time(w.get("observedAt")) or observed, finite(w.get("windowMinutes"), 1, 10**6) or 0)
            for k in ("usedUsd", "limitUsd"):
                if finite(w.get(k), 0, 1e9) is not None:
                    x[k] = w[k]
            windows.append(x)
    except (ValueError, AssertionError, AttributeError, TypeError):
        st["status"] = "invalid"
        return [], st
    st["status"] = "ok"
    if not windows:
        st["reason"] = "Claude Code reported no usage windows (API key or not yet a response this session)"
    acct = {"source": "claude-code", "observedAt": observed, "harness": harness, "windows": windows}
    return [acct], st


# ---- Codex session logs

def dirs_desc(p):
    try:
        return sorted((e.path for e in os.scandir(p) if e.is_dir(follow_symlinks=False)), reverse=True)
    except OSError:
        return []


def newest_rollouts(root, n):
    found = []
    for y in dirs_desc(root):
        for m in dirs_desc(y):
            for d in dirs_desc(m):
                try:
                    for e in os.scandir(d):
                        if e.is_file(follow_symlinks=False) and ROLLOUT.fullmatch(e.name):
                            found.append((e.stat().st_mtime, e.path))
                except OSError:
                    pass
                if len(found) >= n * 2:
                    break
            else:
                continue
            break
        else:
            continue
        break
    found.sort(reverse=True)
    return [p for _, p in found[:n]]


def kind_of(minutes):
    if 240 <= minutes <= 360:
        return "five_hour"
    if 9000 <= minutes <= 11000:
        return "weekly"
    if 40000 <= minutes <= 46000:
        return "monthly"
    return "unknown"


def origin_of(v):
    """Where a thread came from: cli, vscode, exec, ... or subagent:review, internal:guardian."""
    if isinstance(v, str):
        return clip(v)
    if isinstance(v, dict) and len(v) == 1:
        (k, inner), = v.items()
        if not isinstance(inner, str):
            inner = min(inner) if isinstance(inner, dict) and inner else ""
        return clip(k + ":" + inner)
    return ""


def background(origin, model):
    return origin.startswith("subagent") or origin.startswith("internal") or model == "codex-auto-review"


def scan_rollout(path):
    """First line (session_meta) and the tail: latest snapshot per limit id, latest turn context."""
    try:
        with open(path, "rb") as f:
            first = f.readline(CODEX_HEAD)
            size = os.fstat(f.fileno()).st_size
            f.seek(size - CODEX_TAIL if size > CODEX_TAIL else 0)
            data = f.read()
    except OSError:
        return None
    r = {"path": path, "origin": "", "plan": "", "observed": None, "harness": None, "windows": {}}
    try:
        row = json.loads(first)
        if isinstance(row, dict) and row.get("type") == "session_meta" and isinstance(row.get("payload"), dict):
            r["origin"] = origin_of(row["payload"].get("source"))
    except ValueError:
        pass
    for line in data.splitlines():
        if b'"rate_limits"' not in line and b'"turn_context"' not in line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if not isinstance(row, dict) or not isinstance(row.get("payload"), dict):
            continue
        p, ts = row["payload"], parse_time(row.get("timestamp"))
        if row.get("type") == "turn_context" and ts:
            mode = p.get("collaboration_mode") if isinstance(p.get("collaboration_mode"), dict) else {}
            settings = mode.get("settings") if isinstance(mode.get("settings"), dict) else {}
            h = {"model": clip(p.get("model")), "effort": clip(p.get("effort")) or clip(settings.get("reasoning_effort")),
                 "serviceTier": clip(p.get("service_tier"))}
            h = {k: v for k, v in h.items() if v}
            if h.get("model") or h.get("effort"):
                h["observedAt"] = ts
                r["harness"] = h
        elif row.get("type") == "event_msg" and p.get("type") == "token_count" and isinstance(p.get("rate_limits"), dict) and ts:
            rl = p["rate_limits"]
            r["observed"] = ts
            if clip(rl.get("plan_type")):
                r["plan"] = clip(rl["plan_type"])
            lim = clip(rl.get("limit_id"))
            lim = "" if lim == "codex" else lim
            for cw in (rl.get("primary"), rl.get("secondary")):
                if not isinstance(cw, dict):
                    continue
                minutes = cw.get("window_minutes")
                minutes = minutes if type(minutes) is int and 0 < minutes < 10**6 else 0
                if type(cw.get("resets_at")) is int:
                    resets = from_unix(cw["resets_at"])
                elif type(cw.get("resets_in_seconds")) is int and cw["resets_in_seconds"] >= 0:
                    resets = ts + dt.timedelta(seconds=cw["resets_in_seconds"])
                else:
                    resets = None
                kind = kind_of(minutes)
                r["windows"][(lim, kind, minutes)] = window(kind, finite(cw.get("used_percent"), 0, 1000), resets, ts, minutes, "fixed", lim)
    if r["observed"] is None and r["harness"] is None:
        return None
    return r


def find_thread(root, thread):
    suffix, days = "-" + thread + ".jsonl", 0
    for y in dirs_desc(root):
        for m in dirs_desc(y):
            for d in dirs_desc(m):
                days += 1
                if days > 62:
                    return ""
                try:
                    for e in os.scandir(d):
                        if e.is_file(follow_symlinks=False) and ROLLOUT.fullmatch(e.name) and e.name.endswith(suffix):
                            return e.path
                except OSError:
                    pass
    return ""


def merge_codex(rs):
    """Plan and observedAt from the newest snapshot; windows newest per limit/kind/length."""
    snaps = [r for r in rs if r["observed"]]
    if not snaps:
        return None
    newest = max(snaps, key=lambda r: r["observed"])
    acct = {"source": "codex", "observedAt": newest["observed"], "windows": []}
    if newest["plan"]:
        acct["plan"] = newest["plan"]
    pos = {}
    for r in [newest] + snaps:
        if r["plan"] and newest["plan"] and r["plan"] != newest["plan"]:
            continue
        for k, w in r["windows"].items():
            if k in pos:
                if w["observedAt"] > acct["windows"][pos[k]]["observedAt"]:
                    acct["windows"][pos[k]] = w
                continue
            pos[k] = len(acct["windows"])
            acct["windows"].append(w)
    return acct


def codex_harness(rs, own):
    pick = None
    for r in rs:
        h = r["harness"]
        if not h:
            continue
        if r["path"] == own:
            pick = r
            break
        if background(r["origin"], h.get("model", "")):
            continue
        if pick is None or h["observedAt"] > pick["harness"]["observedAt"]:
            pick = r
    if pick is None:
        return None
    h = dict(pick["harness"])
    h["attribution"] = "current-thread" if pick["path"] == own else "recent-thread"
    if pick["origin"]:
        h["origin"] = pick["origin"]
    return h


def read_codex(home, thread=""):
    """Account windows merged across recent rollouts (every thread reports the same meters);
    model and effort from one thread: the named one when found, else the newest interactive
    thread, marked recent-thread. Background threads never supply them."""
    st = {"source": "codex"}
    root = os.path.join(home, "sessions")
    files = newest_rollouts(root, CODEX_FILES)
    own = ""
    thread = clip(thread or "")
    if thread:
        own = find_thread(root, thread)
        if own and own not in files:
            files.insert(0, own)
    if not files:
        st.update(status="missing", reason="no Codex session logs found")
        return [], st
    rs = [r for r in (scan_rollout(f) for f in files) if r]
    acct = merge_codex(rs)
    if acct is None:
        st.update(status="empty", reason="recent Codex sessions carry no rate-limit snapshot (API key login or no turn yet)")
        return [], st
    h = codex_harness(rs, own)
    if h:
        acct["harness"] = h
    st["status"] = "ok"
    return [acct], st


# ---- user-maintained local.json

def read_local(path, now):
    st = {"source": "user"}
    raw, status = read_bounded(path, 128 << 10)
    if status:
        st["status"] = status
        return [], st
    try:
        d = json.loads(raw)
    except ValueError:
        st["status"] = "invalid"
        return [], st
    if not isinstance(d, dict) or type(d.get("schemaVersion")) is not int or d["schemaVersion"] != 1:
        st["status"] = "unsupported_schema" if isinstance(d, dict) else "invalid"
        return [], st
    accounts, order = {}, []

    def acct(pid):
        if pid not in accounts:
            accounts[pid] = {"source": "user", "plan": pid, "observedAt": None, "windows": [], "cards": []}
            order.append(pid)
        return accounts[pid]

    rows = {k: d.get(k, []) for k in ("plans", "resetCards", "windows")}
    if any(not isinstance(v, list) or len(v) > 100 for v in rows.values()):
        st["status"] = "invalid"
        return [], st
    for key, items in rows.items():
        for r in items:
            if not isinstance(r, dict) or not isinstance(r.get("planId"), str) or not IDENT.fullmatch(r["planId"]):
                st["status"] = "invalid"
                return [], st
    for r in rows["plans"]:
        acct(r["planId"])
    for r in rows["resetCards"]:
        c = r.get("count")
        acct(r["planId"])["cards"].append({
            "kind": r.get("kind") if r.get("kind") in ("five_hour", "weekly") else "unknown",
            "count": c if type(c) is int and 0 <= c <= 100000 else None,
            "expiresAt": parse_time(r.get("expiresAt")),
        })
    for r in rows["windows"]:
        rem = finite(r.get("remainingPercent"), 0, 100)
        observed = parse_time(r.get("observedAt"))
        used = 100 - rem if rem is not None else None
        if observed is None or observed > now:
            used, observed = None, None
        kind = r.get("kind") if r.get("kind") in ("five_hour", "weekly", "monthly") else "unknown"
        mode = r.get("resetMode") if r.get("resetMode") in ("fixed", "rolling") else "unknown"
        a = acct(r["planId"])
        a["windows"].append(window(kind, used, parse_time(r.get("resetAt")), observed, 0, mode))
        if observed and (a["observedAt"] is None or observed > a["observedAt"]):
            a["observedAt"] = observed
    st["status"] = "ok"
    out = []
    for pid in order:
        a = accounts[pid]
        if not a["cards"]:
            del a["cards"]
        out.append(a)
    return out, st


# ---- evaluation (same rules as the Go client)

def eval_window(w, now):
    observed = w.get("observedAt")
    w["remainingPercent"] = w["resetsInMinutes"] = w["elapsedPercent"] = w["projectedPercent"] = None
    w["ageMinutes"] = int(max(0, (now - observed).total_seconds() / 60)) if observed else None
    if not w.get("windowMinutes"):
        if DEFAULT_MINUTES.get(w["kind"]):
            w["windowMinutes"] = DEFAULT_MINUTES[w["kind"]]
    w["pace"] = "unknown"
    used = w.get("usedPercent")
    if used is None:
        return
    w["remainingPercent"] = round1(max(0, 100 - used))
    left = None
    if w.get("resetsAt"):
        secs = (w["resetsAt"] - now).total_seconds()
        if secs <= 0:
            w["pace"], w["remainingPercent"] = "reset_passed", None
            return
        left = math.ceil(secs / 60)
        w["resetsInMinutes"] = left
    if used >= 100:
        w["pace"] = "exhausted"
        return
    if not w.get("resetsAt") or not w.get("windowMinutes") or w.get("resetMode") == "rolling":
        if used >= 90:
            w["pace"] = "tight"
        return
    length = float(w["windowMinutes"])
    elapsed = max(0.0, min(1.0, 1 - left / length))
    w["elapsedPercent"] = round1(elapsed * 100)
    if elapsed >= 0.1:
        w["projectedPercent"] = round1(used / elapsed)
    proj = w["projectedPercent"]
    if used >= 90 or (proj is not None and proj > 100 and elapsed >= 0.2):
        w["pace"] = "tight"
    elif 100 - used >= 30 and (left <= length * 0.25 or (proj is not None and proj <= 60 and elapsed >= 0.5)):
        w["pace"] = "surplus"
    else:
        w["pace"] = "on_track"


def headroom(ws):
    ordered = sorted(ws, key=lambda w: -(w.get("windowMinutes") or 0))
    for pace, verdict in (("exhausted", "exhausted"), ("tight", "conserve")):
        for w in ordered:
            if w["pace"] == pace:
                return verdict, w["kind"]
    spend, known = "", False
    for w in ordered:
        if w["pace"] == "surplus":
            known = True
            spend = spend or w["kind"]
        elif w["pace"] == "on_track":
            known = True
            if w["projectedPercent"] is None or w["projectedPercent"] > 80:
                return "normal", w["kind"]
    if spend:
        return "spend", spend
    return ("normal", "") if known else ("unknown", "")


def evaluate(a, now):
    obs = a.get("observedAt")
    a["stale"] = bool(obs) and (now - obs).total_seconds() / 60 > STALE_AFTER
    for w in a["windows"]:
        eval_window(w, now)
    a["headroom"], deciding = headroom(a["windows"])
    if deciding:
        a["deciding"] = deciding


def ordered_account(a):
    keys = ["source", "plan", "observedAt", "stale", "harness", "windows", "cards", "headroom", "deciding"]
    out = {k: a[k] for k in keys if k in a and not (k in ("plan", "deciding") and not a[k]) and not (k == "harness" and not a[k])}
    if out.get("observedAt") is None:
        out["observedAt"] = dt.datetime(1, 1, 1, tzinfo=dt.timezone.utc)
    return out


def jsonable(v):
    if isinstance(v, dt.datetime):
        return "0001-01-01T00:00:00Z" if v.year == 1 else iso(v)
    if isinstance(v, dict):
        return {k: jsonable(x) for k, x in v.items()}
    if isinstance(v, list):
        return [jsonable(x) for x in v]
    return v


def default_cache():
    if os.environ.get("MODELPLAN_CACHE"):
        return os.environ["MODELPLAN_CACHE"]
    home = Path.home()
    if sys.platform == "darwin":
        return str(home / "Library" / "Caches" / "modelplan")
    if os.name == "nt":
        return os.path.join(os.environ.get("LOCALAPPDATA", str(home)), "modelplan")
    return os.path.join(os.environ.get("XDG_CACHE_HOME") or str(home / ".cache"), "modelplan")


def report(cache, codex_home, local_file, now, codex_thread=""):
    accounts, sources = [], []
    for found, st in (read_claude_code(cache), read_codex(codex_home, codex_thread), read_local(local_file, now)):
        accounts += found
        sources.append(st)
    for a in accounts:
        evaluate(a, now)
    return jsonable({"schemaVersion": 1, "evaluatedAt": now, "accounts": [ordered_account(a) for a in accounts],
                     "sources": sources, "note": NOTE})


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--now", help="evaluate at this ISO time (testing)")
    ap.add_argument("--cache", default=default_cache())
    ap.add_argument("--codex-home", default=os.environ.get("CODEX_HOME") or str(Path.home() / ".codex"))
    ap.add_argument("--local", default=str(Path.home() / ".config" / "modelplan" / "local.json"))
    args = ap.parse_args(argv)
    now = parse_time(args.now) if args.now else dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    if now is None:
        ap.error("--now must be an ISO time with a timezone")
    # Codex sets CODEX_THREAD_ID for the commands a thread runs: read that thread's model and effort.
    thread = os.environ.get("CODEX_THREAD_ID", "")
    json.dump(report(args.cache, args.codex_home, args.local, now, thread), sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
