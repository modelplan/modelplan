# SPDX-License-Identifier: MIT
"""Realistic seed parts for the dogfood walk (seed-dogfood.json, WALKTHROUGH.md "Dogfood seed").

Pure builders (tested in tests/test_walkthrough.py) plus the file writes walkthrough.py calls. Everything here is
invented data written through the files the bundled CLI already reads; nothing reaches a provider.
"""
import datetime
import gzip
import hashlib
import json
import re
import uuid
from pathlib import Path

TIME_RE = re.compile(r"^@now(?:([+-])(\d+)([mhd]))?$")
UNITS = {"m": 60, "h": 3600, "d": 86400}


def stamp(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def at(now, spec):
    """'@now', '@now-90m', '@now+3d' -> an RFC 3339 stamp relative to now; anything else is returned unchanged."""
    m = TIME_RE.match(spec) if isinstance(spec, str) else None
    if not m:
        return spec
    seconds = 0 if not m.group(1) else int(m.group(2)) * UNITS[m.group(3)] * (1 if m.group(1) == "+" else -1)
    return stamp(now + datetime.timedelta(seconds=seconds))


def resolve_times(value, now):
    """Every '@now...' string inside a JSON value becomes a stamp, so seed files stay valid whenever the walk runs."""
    if isinstance(value, dict):
        return {k: resolve_times(v, now) for k, v in value.items()}
    if isinstance(value, list):
        return [resolve_times(v, now) for v in value]
    return at(now, value)


def declared_windows(plan, now, observed):
    """local.json windows of one declared plan: the old one-window form or a 'windows' list."""
    windows = plan.get("windows") or [{"kind": "five_hour", "remainingPercent": plan["remainingPercent"],
                                       "resetMinutes": plan["resetMinutes"]}]
    return [{"planId": plan["planId"], "kind": w["kind"], "remainingPercent": w["remainingPercent"],
             "resetMode": w.get("resetMode", "rolling"), "observedAt": observed,
             "resetAt": stamp(now + datetime.timedelta(minutes=w["resetMinutes"]))} for w in windows]


def declared_reset_cards(plans, now):
    return [{"planId": p["planId"], "kind": c["kind"], "count": c["count"],
             "expiresAt": stamp(now + datetime.timedelta(minutes=c["expiresMinutes"]))}
            for p in plans for c in p.get("resetCards", [])]


def codex_extras(codex, now, observed):
    """Banked resets (credits) and usage credits (points) on the Codex reading (codexaccount.go accountSnap)."""
    extra = {}
    credits = codex.get("credits")
    if credits:
        expiry = stamp(now + datetime.timedelta(minutes=credits["expiresMinutes"]))
        ids = [hashlib.sha256(("dogfood-credit-%d" % n).encode()).hexdigest() for n in range(credits["count"])]
        extra["credits"] = {"count": credits["count"], "expiries": [expiry] * credits["count"], "identityObserved": True,
                            "identityComplete": True, "items": [{"id": i, "expiresAt": expiry} for i in ids]}
    if "usageCredits" in codex:
        extra["usageCredits"] = {"balance": codex["usageCredits"], "observedAt": observed}
        extra["usageRead"] = True
    return extra


def rollout_lines(session, start):
    """One Codex rollout: session_meta (cwd), then per turn task_started, turn_context, token_count, task_complete."""
    def line(moment, kind, payload):
        return json.dumps({"timestamp": moment.strftime("%Y-%m-%dT%H:%M:%S.000Z"), "type": kind, "payload": payload})
    out = [line(start, "session_meta", {"cwd": session["cwd"], "id": session.get("id", "")})]
    total = {"input_tokens": 0, "cached_input_tokens": 0, "output_tokens": 0, "reasoning_output_tokens": 0}
    turns = max(1, session.get("turns", 1))
    for n in range(turns):
        t = start + datetime.timedelta(seconds=40 * n + 1)
        last = {"input_tokens": session.get("inputTokens", 0) // turns, "cached_input_tokens": session.get("cachedTokens", 0) // turns,
                "output_tokens": session.get("outputTokens", 0) // turns, "reasoning_output_tokens": 0}
        for k in total:
            total[k] += last[k]
        context = {"model": session["model"], "effort": session.get("effort", "medium"), "cwd": session["cwd"]}
        if session.get("fast"):
            context["service_tier"] = "fast"
        out += [line(t, "event_msg", {"type": "task_started"}), line(t, "turn_context", context),
                line(t + datetime.timedelta(seconds=20), "event_msg", {"type": "token_count", "info": {"last_token_usage": last, "total_token_usage": dict(total)}}),
                line(t + datetime.timedelta(seconds=30), "event_msg", {"type": "task_complete", "duration_ms": 30000})]
    return out


def history_sessions(history, now):
    """A deterministic 30-day history: per day one session per listed model, tokens following a weekly rhythm."""
    sessions = []
    for day in range(1, history.get("days", 30)):
        weight = (3, 1, 0, 2, 5, 4, 6)[day % 7]
        if weight == 0:
            continue
        for i, model in enumerate(history["models"]):
            sessions.append({"model": model["model"], "effort": model.get("effort", "medium"), "cwd": history["cwds"][(day + i) % len(history["cwds"])],
                             "turns": 2, "inputTokens": model["inputTokens"] * weight, "cachedTokens": model["inputTokens"] * weight // 2,
                             "outputTokens": model["outputTokens"] * weight, "start": now - datetime.timedelta(days=day, hours=i + 1)})
    return sessions


def rollout_path(home, session, start):
    sid = session.get("id") or str(uuid.uuid5(uuid.NAMESPACE_URL, "%s|%s|%s" % (session["cwd"], session["model"], start.isoformat())))
    return Path(home) / ".codex/sessions" / start.strftime("%Y/%m/%d") / ("rollout-%s-%s.jsonl" % (start.strftime("%Y-%m-%dT%H-%M-%S"), sid))


def write_sessions(home, seed, now, live_only=False):
    """Writes the seed's sessions (live ones end now, so the live strip counts them) and, unless live_only, its history."""
    written = []
    sessions = [dict(s, start=now - datetime.timedelta(minutes=s.get("minutesAgo", 2))) for s in seed.get("sessions", [])]
    if live_only:
        sessions = [s for s in sessions if s.get("live")]
    elif seed.get("history"):
        sessions += history_sessions(seed["history"], now)
    for s in sessions:
        if s["cwd"] == "~" or s["cwd"].startswith("~/"):   # a cwd under the walk's HOME (the home dir itself, scratch chats)
            s = dict(s, cwd=str(home) + s["cwd"][1:])
        path = rollout_path(home, s, s["start"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(rollout_lines(s, s["start"])) + "\n", encoding="utf-8")
        written.append(path)
    return written


def write_files(home, files, now):
    """Plain files of the seed (Claude settings, a fake kiro-cli, reader state), relative to HOME, never outside it."""
    root = Path(home).resolve()
    for f in files:
        path = (root / f["path"]).resolve()
        if root not in path.parents:
            raise ValueError("seed file outside HOME: %s" % f["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        body = json.dumps(resolve_times(f["json"], now)) if "json" in f else f["text"]
        path.write_text(body, encoding="utf-8")
        if "mode" in f:
            path.chmod(int(f["mode"], 8))


def identity(manifest):
    """publicationId of a manifest (sync.go manifestIdentity): the fixed core order, raw subobjects compacted."""
    core = "{%s}" % ",".join('"%s":%s' % (k, json.dumps(manifest[k], separators=(",", ":"), ensure_ascii=False))
                             for k in ("schemaVersion", "comparisonVersion", "methods", "components"))
    return hashlib.sha256(core.encode("utf-8")).hexdigest()[:24]


def decode_object(raw):
    if raw.startswith(b"MPGZ1\x00"):
        return gzip.decompress(raw[10:])
    return raw


def add_reset_events(cache, events, now):
    """Adds announced/confirmed reset news to the synced public data (the client object's data.resets), re-addressing the
    object, manifest and state the way the CLI verifies them. Checks the unmodified manifest's identity first and changes
    nothing when this code does not reproduce it. Returns a detail dict for the manifest."""
    cache = Path(cache)
    try:
        state = json.loads((cache / "state.json").read_text(encoding="utf-8"))
        old_id = state["publicationId"]
        manifest = json.loads((cache / "releases" / old_id / "manifest.json").read_text(encoding="utf-8"))
        if identity(manifest) != old_id:
            return {"patched": False, "why": "manifest identity not reproduced"}
        client_ref = manifest["components"]["client"]
        body = decode_object((cache / "objects" / (client_ref["hash"] + ".json")).read_bytes())
        if hashlib.sha256(body).hexdigest() != client_ref["hash"]:
            return {"patched": False, "why": "client object hash mismatch"}
        client = json.loads(body)
        client["data"]["resets"] = list(client["data"].get("resets") or []) + resolve_times(events, now)
        new_body = json.dumps(client, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        new_hash = hashlib.sha256(new_body).hexdigest()
        (cache / "objects" / (new_hash + ".json")).write_bytes(new_body)
        client_ref["hash"], client_ref["bytes"] = new_hash, len(new_body)
        new_id = identity(manifest)
        manifest["publicationId"] = new_id
        manifest_bytes = json.dumps(manifest, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        (cache / "releases" / new_id).mkdir(parents=True, exist_ok=True)
        (cache / "releases" / new_id / "manifest.json").write_bytes(manifest_bytes)
        state.update(publicationId=new_id, manifestHash=hashlib.sha256(manifest_bytes).hexdigest(), componentHash=new_hash,
                     component="client", nextCheckAt=stamp(now + datetime.timedelta(hours=24)))
        tmp = cache / "state.json.dogfood"
        tmp.write_text(json.dumps(state, indent=2), encoding="utf-8")
        tmp.replace(cache / "state.json")
        return {"patched": True, "events": len(events), "publicationId": new_id}
    except (OSError, ValueError, KeyError, TypeError) as error:
        return {"patched": False, "why": "%s: %s" % (type(error).__name__, error)}


def targets_for(seed, language):
    """Target replacements of the seed for this language (step labels differ in zh-Hans and with realistic names)."""
    return dict(seed.get("walk", {}).get("targets", {}).get(language, {}))


def retarget(value, mapping):
    if not mapping:
        return value
    if isinstance(value, dict):
        return {k: retarget(v, mapping) for k, v in value.items()}
    if isinstance(value, list):
        return [retarget(v, mapping) for v in value]
    return mapping.get(value, value) if isinstance(value, str) else value


def select_steps(steps, seed, language):
    """The steps a seed walks: a seed with walk.only walks those ids (in steps.json order), the others every step
    without a 'profiles' list; a step with 'profiles' runs only for a seed whose walk.profile is listed."""
    walk = seed.get("walk", {})
    profile, only = walk.get("profile"), walk.get("only")
    chosen = [s for s in steps if (s["id"] in only if only else not s.get("profiles"))
              and (not s.get("profiles") or profile in s["profiles"])]
    return retarget(chosen, targets_for(seed, language))
