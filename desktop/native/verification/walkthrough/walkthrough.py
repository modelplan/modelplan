#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Walk a packaged test app on a disposable hosted Mac and write screenshots plus a manifest.

Contract: WALKTHROUGH.md. Synthetic only: a fresh HOME holds invented readings, so no reader
touches an account. The tool posts real input, so it refuses to run outside a GitHub-hosted
runner; the owner's Macs keep the booked sequence in SKILL.md.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time

APP_EXECUTABLE = "ModelPlanCommunity"
DISPLAY_CANDIDATES = ((1920, 1200), (1920, 1080), (1680, 1050), (1600, 1200), (1440, 900), (1280, 1024))
PARK = (0.42, 0.62)  # A screen fraction clear of the widget's edges, the menu bar and the Dock.
MIN_COLOURS = 24  # Coarse 12-bit colours: a blank, black or single-tone render has far fewer.
MAX_DOMINANT = 0.97
QUIT_SECONDS = 15
HINT_SECONDS = 15
FRESH_SECONDS = 120  # How long a fresh profile gets to fetch public data by itself.


class WalkthroughError(Exception):
    """A step could not do what it says. The message is the manifest's reason."""


# Targets: pure functions over the helper's accessibility tree, so they run in tests on any host.

def walk(node, window=None):
    if not isinstance(node, dict):
        return
    yield node, window
    for child in node.get("children") or []:
        yield from walk(child, window)


def nodes(tree):
    for window in tree.get("windows") or []:
        yield from walk(window, window)
    yield from walk(tree.get("extras"), None)


def matcher(target):
    kind, _, value = target.partition(":")
    tests = {
        "ax": lambda n: n.get("id") == value,
        "ax^": lambda n: str(n.get("id", "")).startswith(value),
        "label": lambda n: value in (n.get("label"), n.get("title")),
        "value": lambda n: n.get("value") == value,
        "dom^": lambda n: str(n.get("dom", "")).startswith(value),
        "role": lambda n: n.get("role") == value,
    }
    if kind not in tests:
        raise WalkthroughError("unknown target " + target)
    return tests[kind]


def visible(node):
    frame = node.get("frame")
    return bool(frame) and frame[2] > 0 and frame[3] > 0


def resolve_all(tree, target):
    if target == "status-item":
        bar = (tree.get("extras") or {}).get("children") or []
        return [bar[0]] if bar else []
    if target.startswith("window-of:"):
        test = matcher(target[len("window-of:"):])
        found = []
        for node, window in nodes(tree):
            if window is not None and test(node) and window not in found:
                found.append(window)
        return found
    test = matcher(target)
    return [node for node, _ in nodes(tree) if test(node)]


def resolve(tree, target):
    """The first on-screen match. Closed menu items report an empty frame, so they do not count."""
    for node in resolve_all(tree, target):
        if visible(node):
            return node
    return None


def centre(frame):
    return frame[0] + frame[2] / 2, frame[1] + frame[3] / 2


def unmirror_widget(tree):
    """Put the widget's accessibility frames where the pixels are; true if they needed it.

    The grip sits below the rings. Frames that report it above them are reflected inside the
    widget window, so a pointer sent there would land on the wrong ring. The manifest records
    this as a failed check, and the correction switches itself off once the app reports true frames.
    """
    for window in tree.get("windows") or []:
        children = window.get("children") or []
        grip = next((c for c in children if c.get("id") == "dock.grip.0"), None)
        rings = [c for c in children if str(c.get("id", "")).startswith("dock.subscription.")]
        if grip is None or not rings or not all(visible(c) for c in rings):
            continue
        if centre(grip["frame"])[1] < min(centre(r["frame"])[1] for r in rings):
            for child in children:
                if visible(child):
                    child["frame"] = reflected(child["frame"], window["frame"])
            return True
    return False


def reflected(frame, window):
    top, height = window[1], window[3]
    return [frame[0], 2 * top + height - frame[1] - frame[3], frame[2], frame[3]]


def window_ids(windows):
    return {w["id"] for w in windows if w.get("onScreen")}


class Host:
    """The real Mac. Tests replace it."""

    def __init__(self, helper):
        self.helper_path = helper

    def helper(self, *arguments):
        result = subprocess.run([self.helper_path, *map(str, arguments)], capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            raise WalkthroughError("helper %s failed: %s" % (arguments[0], result.stderr.strip()[:200]))
        return json.loads(result.stdout)

    def capture(self, path, rect=None):
        command = ["screencapture", "-x"]
        if rect is not None:
            command.append("-R%d,%d,%d,%d" % tuple(round(v) for v in rect))
        subprocess.run(command + [str(path)], check=True, timeout=30)

    def run(self, command, env, stdin=None, timeout=120):
        return subprocess.run(command, env=env, input=stdin, capture_output=True, text=True, timeout=timeout)

    def launch(self, command, env, log):
        return subprocess.Popen(command, env=env, stdout=log, stderr=log)

    @staticmethod
    def sleep(seconds):
        time.sleep(seconds)

    @staticmethod
    def now():
        return time.time()


class Walkthrough:
    def __init__(self, host, app, out, steps, seed, screen):
        self.host, self.app, self.out = host, Path(app), Path(out)
        self.steps, self.seed, self.screen = steps, seed, screen
        self.pid = None
        self.remembered = None
        self.window_baseline = set()
        self.results, self.statuses = [], {}
        self.frames_mirrored = False
        self.mirror_evidence = {}
        self.crops = {}

    def tree(self):
        tree = self.host.helper("tree", self.pid)
        self.frames_mirrored = unmirror_widget(tree) or self.frames_mirrored
        return tree

    def windows(self):
        return self.host.helper("windows", self.pid)

    def need(self, target):
        node = resolve(self.tree(), target)
        if node is None:
            raise WalkthroughError("target not on screen: " + target)
        return node

    def point(self, fraction):
        return self.screen[0] * fraction[0], self.screen[1] * fraction[1]

    def await_target(self, target, timeout):
        deadline = self.host.now() + timeout
        while True:
            if resolve(self.tree(), target) is not None:
                return
            if self.host.now() >= deadline:
                raise WalkthroughError("timed out waiting for " + target)
            self.host.sleep(0.5)

    # Operations named in steps.json.

    def op_await(self, action):
        self.await_target(action["target"], action.get("timeout", 15))

    def op_wait(self, action):
        self.host.sleep(action["seconds"])

    def op_park(self, _):
        self.host.helper("move", *self.point(PARK))

    def op_press(self, action):
        if not self.host.helper("press", self.pid, action["by"], action["value"]).get("pressed"):
            raise WalkthroughError("could not press " + action["value"])

    def op_click(self, action):
        verb = "rightclick" if action.get("button") == "right" else "click"
        self.host.helper(verb, *centre(self.need(action["target"])["frame"]))

    def op_hover(self, action):
        self.host.helper("move", *centre(self.need(action["target"])["frame"]), 0.5)
        self.host.sleep(action.get("seconds", 1))

    def op_clickIn(self, action):
        frame = self.need(action["target"])["frame"]
        self.host.helper("click", frame[0] + frame[2] * action["at"][0], frame[1] + frame[3] * action["at"][1])

    def op_key(self, action):
        self.host.helper("key", action["name"])

    def op_awaitNewWindow(self, action):
        deadline = self.host.now() + action.get("timeout", 15)
        while not window_ids(self.windows()) - self.window_baseline:
            if self.host.now() >= deadline:
                raise WalkthroughError("no new window within %ss" % action.get("timeout", 15))
            self.host.sleep(0.25)

    def op_assertAbsent(self, action):
        if resolve(self.tree(), action["target"]) is not None:
            raise WalkthroughError("still on screen: " + action["target"])

    def card_at(self, point):
        self.host.helper("move", *point, 0.4)
        self.host.sleep(1.4)
        node = resolve(self.tree(), "ax:dock.card.text.name")
        name = node.get("value") if node else None
        self.host.helper("move", *self.point(PARK))
        self.host.sleep(1.0)
        return name

    def op_ringCardMap(self, _):
        """Which card opens at each ring, at the painted place and at the frame the app reports."""
        raw = self.host.helper("tree", self.pid)
        window = resolve(raw, "window-of:ax:dock.grip.0")
        rings = [n for n in resolve_all(raw, "ax^:dock.subscription.") if visible(n)]
        painted = {n["id"]: resolve(self.tree(), "ax:" + n["id"])["frame"] for n in rings}
        result = []
        for ring in rings:
            result.append({"ring": ring.get("label"), "cardAtPainted": self.card_at(centre(painted[ring["id"]])),
                           "cardAtReported": self.card_at(centre(ring["frame"])),
                           "reportedFrame": ring["frame"], "paintedFrame": painted[ring["id"]]})
        self.mirror_evidence["cards"] = result
        self.mirror_evidence["window"] = window["frame"] if window else None
        wrong = [r["ring"] for r in result if r["cardAtPainted"] != r["ring"]]
        if wrong:
            raise WalkthroughError("card at painted ring differs: " + ", ".join(map(str, wrong)))

    def op_mirrorPixels(self, _):
        """Only the critical ring paints red, so its reported frame should hold the red pixels."""
        raw = self.host.helper("tree", self.pid)
        window = resolve(raw, "window-of:ax:dock.grip.0")
        node = resolve(raw, "ax:dock.subscription.declared:synthetic-critical#manual")
        if window is None or node is None:
            raise WalkthroughError("critical ring not on screen")
        evidence = {"reportedFrame": node["frame"], "windowFrame": window["frame"]}
        for name, frame in (("reported", node["frame"]), ("reflected", reflected(node["frame"], window["frame"]))):
            path = self.out / "measure.png"
            self.host.capture(path, frame)
            evidence[name + "Red"] = self.host.helper("stats", path)["red"]
            path.unlink(missing_ok=True)
            evidence[name + "Hit"] = self.host.helper("hit", *centre(frame))
        self.mirror_evidence["pixels"] = evidence

    def op_remember(self, action):
        self.remembered = self.need(action["target"])["frame"]

    def op_dragStart(self, action):
        self.host.helper("down", *centre(self.need(action["target"])["frame"]))

    def op_dragTo(self, action):
        self.host.helper("held", *self.point(action["point"]), action.get("seconds", 1))

    def op_dragEnd(self, _):
        self.host.helper("up")

    def op_openShutter(self, _):
        shutter = self.need("label:Porthole shutter")
        if str(shutter.get("value")) == "1":  # aria-pressed is true while closed.
            self.host.helper("click", *centre(shutter["frame"]))

    def op_faderStep(self, action):
        fader = self.need(action["target"])
        self.remembered = fader.get("value")
        x, y = centre(fader["frame"])
        self.host.helper("down", x, y)
        self.host.helper("held", x, y - fader["frame"][3] * 0.3, 0.5)
        self.host.helper("up")

    def op_dismissHints(self, _):
        # A first-use hint is a card with one close button; there is no fixed count on purpose.
        for _ in range(3):
            button = resolve(self.tree(), "label:Dismiss hint")
            if button is None:
                return
            self.host.helper("click", *centre(button["frame"]))
            self.host.sleep(1.2)

    # Checks named in steps.json. Each raises with the reason it failed.

    def compare(self, step, record):
        """Crop of this step against the crop of an earlier one, as a changed-pixel share."""
        if record.get("crop") is None or step not in self.crops:
            raise WalkthroughError("no crops to compare with " + step)
        share = self.host.helper("diff", self.out / record["crop"], self.out / self.crops[step])["changedShare"]
        record.setdefault("measures", {})["changedShareFrom:" + step] = round(share, 5)
        return share

    def check(self, check, shot_dir, record):
        kind, value = next(iter(check.items()))
        tree = self.tree()
        if kind == "differsFrom" and self.compare(value["step"], record) < value["min"]:
            raise WalkthroughError("too close to " + value["step"])
        if kind == "matches" and self.compare(value["step"], record) > value["max"]:
            raise WalkthroughError("differs from " + value["step"])
        if kind == "exists" and resolve(tree, value) is None and not resolve_all(tree, value):
            raise WalkthroughError("missing " + value)
        if kind == "opened" and resolve(tree, value) is None:
            raise WalkthroughError("not on screen: " + value)
        if kind == "absent" and resolve(tree, value) is not None:
            raise WalkthroughError("still on screen: " + value)
        if kind == "checked" and str((resolve(tree, value) or {}).get("value")) != "0":
            raise WalkthroughError("not open: " + value)
        if kind == "on" and str((resolve(tree, value) or {}).get("value")) != "1":
            raise WalkthroughError("not on: " + value)
        if kind == "moved":
            node = resolve(tree, value)
            if node is None or node["frame"] == self.remembered:
                raise WalkthroughError("did not move: " + value)
        if kind == "changed":
            node = resolve(tree, value)
            if node is None or node.get("value") == self.remembered:
                raise WalkthroughError("value did not change: " + value)
        if kind == "newWindow" and not window_ids(self.windows()) - self.window_baseline:
            raise WalkthroughError("no new window opened")
        if kind == "noNewWindow" and window_ids(self.windows()) - self.window_baseline:
            raise WalkthroughError("a new window opened")
        if kind == "windowClosed" and not self.window_baseline - window_ids(self.windows()):
            raise WalkthroughError("no window closed")
        if kind == "nonblank":
            node = resolve(tree, value)
            if node is None:
                raise WalkthroughError("nothing to measure: " + value)
            path = shot_dir / "measure.png"
            self.host.capture(path, node["frame"])
            stats = self.host.helper("stats", path)
            path.unlink(missing_ok=True)
            if stats["colours"] < MIN_COLOURS or stats["dominantShare"] > MAX_DOMINANT:
                raise WalkthroughError("blank render: %d colours, %.2f dominant" % (stats["colours"], stats["dominantShare"]))

    def run_step(self, index, step):
        name = "%02d-%s" % (index, step["id"])
        record = {"step": step["id"], "title": step["title"], "expected": step["expected"],
                  "prototype": step.get("prototype"), "file": None, "crop": None, "tree": None}
        blocked = [need for need in step.get("requires", []) if self.statuses.get(need) != "pass"]
        if blocked:
            record.update(status="not-run", reason="needs " + ", ".join(blocked))
            return record
        started = self.host.now()
        reasons = []
        self.window_baseline = window_ids(self.windows())
        try:
            for action in step.get("actions", []):
                getattr(self, "op_" + action["op"])(action)
        except WalkthroughError as error:
            reasons.append(str(error))
        # A failed step is photographed too: the picture shows where it stopped.
        self.host.capture(self.out / (name + ".png"))
        record["file"] = name + ".png"
        tree = self.tree()
        (self.out / (name + ".tree.json")).write_text(json.dumps(tree, indent=1, sort_keys=True), encoding="utf-8")
        record["tree"] = name + ".tree.json"
        crop = step.get("shot", {}).get("crop")
        if crop:
            node = resolve(tree, crop)
            if node is not None:
                self.host.capture(self.out / (name + ".crop.png"), node["frame"])
                record["crop"] = name + ".crop.png"
                self.crops[step["id"]] = record["crop"]
        if not reasons:
            for check in step.get("checks", []):
                try:
                    self.check(check, self.out, record)
                except WalkthroughError as error:
                    reasons.append(str(error))
        record.update(status="fail" if reasons else "pass", reason="; ".join(reasons) or None,
                      seconds=round(self.host.now() - started, 2))
        return record

    def walk_steps(self):
        for index, step in enumerate(self.steps, 1):
            record = self.run_step(index, step)
            self.results.append(record)
            self.statuses[step["id"]] = record["status"]
            print("%-20s %s %s" % (step["id"], record["status"], record.get("reason") or ""), flush=True)
        return self.results


# Synthetic profile.

def stamp(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def declared_quota(seed, now):
    plans = seed["declared"]
    return {"schemaVersion": 1, "plans": [{"planId": p["planId"]} for p in plans],
            "windows": [{"planId": p["planId"], "kind": "five_hour", "remainingPercent": p["remainingPercent"], "resetMode": "rolling",
                         "observedAt": stamp(now - datetime.timedelta(seconds=15)),
                         "resetAt": stamp(now + datetime.timedelta(minutes=p["resetMinutes"]))} for p in plans]}


def codex_reading(seed, now, consent):
    codex = seed["codex"]
    observed = stamp(now - datetime.timedelta(seconds=20))
    return {"schemaVersion": 1, "status": "ok", "observedAt": observed, "plan": codex["plan"],
            "subscriptionRef": codex["subscriptionRef"],
            "admission": {"storeEpoch": consent["storeEpoch"], "generation": consent["generation"], "scope": "codex.runtime_usage"},
            "windows": [{"kind": w["kind"], "windowMinutes": w["windowMinutes"], "usedPercent": 100 - w["remainingPercent"],
                         "observedAt": observed, "resetsAt": stamp(now + datetime.timedelta(minutes=w["resetMinutes"])),
                         "resetMode": "rolling", "limit": "main"} for w in codex["windows"]]}


def child_environment(home):
    return {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "TMPDIR": str(home / "tmp") + "/",
            "PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"}


def consent_call(host, cli, env, arguments, body=None):
    result = host.run([str(cli), "consent", *arguments, "--json"], env, stdin=None if body is None else json.dumps(body))
    if result.returncode != 0:
        raise WalkthroughError("consent %s failed" % " ".join(arguments))
    return json.loads(result.stdout)


def seed_profile(host, cli, home, seed, now):
    """Write invented readings through the same files the bundled CLI reads."""
    (home / "tmp").mkdir(parents=True, exist_ok=True)
    (home / ".codex").mkdir(exist_ok=True)
    env = child_environment(home)
    consent_call(host, cli, env, ["init"])
    before = consent_call(host, cli, env, [])
    consent_call(host, cli, env, ["grant"], {
        "requestId": "00000000-0000-4000-8000-000000000001", "expectStoreEpoch": before["storeEpoch"],
        "expectGeneration": before["generation"], "consentTextVersion": before["consentTextVersion"],
        "allow": ["codex.runtime_usage"], "deny": []})
    after = consent_call(host, cli, env, [])
    config = home / ".config/modelplan"
    config.mkdir(parents=True, exist_ok=True)
    (config / "local.json").write_text(json.dumps(declared_quota(seed, now)), encoding="utf-8")
    observed = home / "Library/Caches/modelplan/observed"
    observed.mkdir(parents=True, exist_ok=True)
    (observed / "codex-account.json").write_text(json.dumps(codex_reading(seed, now, after)), encoding="utf-8")
    return env


def read_bundle(app):
    with (Path(app) / "Contents/Info.plist").open("rb") as stream:
        return plistlib.load(stream)


def check_bundle(info, expected_sha):
    """Only an owner test package offers the steps this walkthrough walks."""
    problems = []
    if info.get("CFBundleExecutable") != APP_EXECUTABLE:
        problems.append("executable is not " + APP_EXECUTABLE)
    if info.get("ModelPlanCockpitEntryEnabled") is not True:
        problems.append("cockpit entry is closed: not an owner test package")
    if expected_sha and info.get("ModelPlanPublicSource") != expected_sha:
        problems.append("bundle source differs from " + expected_sha)
    return problems


def set_display(host):
    """The hosted default is 1024x768, too short to open the porthole. Take the largest offered."""
    offered = {(m["width"], m["height"]) for m in host.helper("modes")}
    for size in DISPLAY_CANDIDATES:
        if size in offered and host.helper("setmode", *size).get("set"):
            host.sleep(3)
            break
    return host.helper("host")


def doctor(host, cli, env, *flags):
    started = host.now()
    result = host.run([str(cli), "doctor", "readers", "--json", *flags], env, timeout=330)
    seconds = round(host.now() - started, 2)
    try:
        return result.returncode, json.loads(result.stdout), seconds
    except ValueError:
        return result.returncode, {}, seconds


def outcome(check, ok, detail):
    return {"check": check, "status": "pass" if ok else "fail", "detail": detail}


def wait_for_quit(host, process, seconds=QUIT_SECONDS):
    deadline = host.now() + seconds
    while process.poll() is None and host.now() < deadline:
        host.sleep(0.25)
    return process.poll()


def launch_app(host, walkthrough, exe, env, log):
    """Start the app and time the first status item and the first reading on the widget."""
    started = host.now()
    process = host.launch([str(exe)], env, log)
    walkthrough.pid = process.pid
    first_window = first_reading = None
    deadline = started + 45
    while host.now() < deadline and process.poll() is None and first_reading is None:
        if first_window is None and window_ids(walkthrough.windows()):
            first_window = round(host.now() - started, 2)
        if resolve(walkthrough.tree(), "ax^:dock.subscription.") is not None:
            first_reading = round(host.now() - started, 2)
        host.sleep(0.25)
    return process, first_window, first_reading


def quit_app(host, walkthrough, process):
    """Quit through the real menu item; the app gets no signal unless that fails."""
    try:
        walkthrough.op_click({"target": "status-item", "button": "right"})
        host.sleep(1)
        walkthrough.op_press({"by": "title", "value": "Quit ModelPlan"})
    except WalkthroughError:
        pass
    code = wait_for_quit(host, process)
    forced = code is None
    if forced:
        process.terminate()
        code = wait_for_quit(host, process, 5)
    if code is None:
        process.kill()
        code = process.wait()
    return code, forced


def widget_frame(walkthrough):
    node = resolve(walkthrough.tree(), "window-of:ax:dock.grip.0")
    return node["frame"] if node else None


def restart_checks(host, walkthrough, exe, env, log, before):
    """Relaunch on the same profile: nothing the first launch settled may come back or be lost."""
    process, first_window, first_reading = launch_app(host, walkthrough, exe, env, log)
    checks = [outcome("restart-launch", first_reading is not None,
                      {"firstWindowSeconds": first_window, "firstReadingSeconds": first_reading})]
    walkthrough.op_park({})  # Off the status item: its tooltip is a window too.
    host.sleep(2)
    baseline = window_ids(walkthrough.windows())
    deadline = host.now() + HINT_SECONDS
    hint = False
    while host.now() < deadline and not hint:
        hint = bool(window_ids(walkthrough.windows()) - baseline)
        host.sleep(0.5)
    checks.append({"check": "restart-first-use-hint", "status": "info", "detail": {"newWindowWithin": HINT_SECONDS, "seen": hint}})
    tree = walkthrough.tree()
    checks.append(outcome("restart-no-first-run", resolve(tree, "ax:firstRun.done") is None, {}))
    after = widget_frame(walkthrough)
    same = before is not None and after is not None and [round(v) for v in after] == [round(v) for v in before]
    checks.append(outcome("restart-widget-place", same, {"before": before, "after": after}))
    readings = sorted(n.get("value", "") for n in resolve_all(tree, "ax^:dock.subscription."))
    checks.append(outcome("restart-readings", bool(readings), {"readings": readings}))
    walkthrough.host.capture(walkthrough.out / "restart.png")
    code, forced = quit_app(host, walkthrough, process)
    checks.append(outcome("restart-quit", code == 0 and not forced, {"exit": code, "forced": forced}))
    return checks


def publication_state(home):
    try:
        state = json.loads((home / "Library/Caches/modelplan/state.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return state


def fresh_profile_probe(host, walkthrough, exe, cli, home, seed, out):
    """Does the app alone fetch public data? Run a second profile that nothing syncs."""
    env = seed_profile(host, cli, home, seed, datetime.datetime.now(datetime.timezone.utc))
    with (out / "fresh-app.log").open("w", encoding="utf-8") as log:
        process, _, reading = launch_app(host, walkthrough, exe, env, log)
        try:
            walkthrough.op_press({"by": "id", "value": "firstRun.login"})
            walkthrough.op_click({"target": "ax:firstRun.done"})
            host.sleep(2)
            walkthrough.op_click({"target": "status-item"})
        except WalkthroughError as error:
            print("fresh profile: " + str(error), flush=True)
        started = host.now()
        fetched_after = None
        while host.now() - started < FRESH_SECONDS and fetched_after is None:
            if publication_state(home).get("componentHash"):
                fetched_after = round(host.now() - started, 1)
            host.sleep(2)
        host.capture(out / "fresh-profile-cockpit.png")
        tree = walkthrough.tree()
        detail = {"waitedSeconds": FRESH_SECONDS, "fetchedAfterSeconds": fetched_after, "firstReadingSeconds": reading,
                  "stateKeys": sorted(publication_state(home)), "hud": resolve(tree, "label:Published models") is not None,
                  "cockpit": resolve(tree, "label:ModelPlan Cockpit") is not None,
                  "unavailableAlert": resolve(tree, "value:Cockpit unavailable") is not None}
        (out / "fresh-profile.tree.json").write_text(json.dumps(tree, indent=1, sort_keys=True), encoding="utf-8")
        process.terminate()
        if wait_for_quit(host, process, 5) is None:
            process.kill()
            process.wait()
    return {"check": "publication-fresh-profile", "status": "info", "detail": detail}


def crash_reports(home):
    reports = home / "Library/Logs/DiagnosticReports"
    return sorted(p.name for p in reports.glob(APP_EXECUTABLE + "*")) if reports.is_dir() else []


def reader_rows(report):
    return {row.get("provider"): row for row in report.get("readers", [])}


def run(args, host):
    if os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise SystemExit("refusing to post input here: this tool is for GitHub-hosted runners only")
    out, home = Path(args.out), Path(args.home)
    out.mkdir(parents=True, exist_ok=True)
    home.mkdir(parents=True, exist_ok=False)
    Path(str(home) + "-fresh").mkdir(parents=True, exist_ok=False)
    app = Path(args.app)
    info = read_bundle(app)
    problems = check_bundle(info, args.source_sha)
    if problems:
        raise SystemExit("; ".join(problems))
    steps = json.loads(Path(args.steps).read_text(encoding="utf-8"))["steps"]
    seed = json.loads(Path(args.seed).read_text(encoding="utf-8"))
    facts = set_display(host)
    frame = facts["screens"][0]["frame"]
    cli, exe = app / "Contents/Helpers/modelplan", app / "Contents/MacOS" / APP_EXECUTABLE
    walkthrough = Walkthrough(host, app, out, steps, seed, (frame[2], frame[3]))
    fresh = fresh_profile_probe(host, walkthrough, exe, cli, Path(str(home) + "-fresh"), seed, out)
    # Public data only. Without it the cockpit has no faders, no HUD and no enlarged view.
    env = seed_profile(host, cli, home, seed, datetime.datetime.now(datetime.timezone.utc))
    synced = host.run([str(cli), "sync"], env, timeout=130)
    checks = [fresh, outcome("publication-sync", synced.returncode == 0, {"exit": synced.returncode})]
    with (out / "app.log").open("w", encoding="utf-8") as log:
        process, first_window, first_reading = launch_app(host, walkthrough, exe, env, log)
        checks.append(outcome("launch", first_window is not None and process.poll() is None,
                              {"firstWindowSeconds": first_window}))
        checks.append(outcome("reader-first-reading", first_reading is not None, {"seconds": first_reading}))
        walkthrough.walk_steps()
        checks.append(outcome("alive-after-walk", process.poll() is None, {"exit": process.poll()}))
        checks.append(outcome("widget-ax-frames", not walkthrough.frames_mirrored, {"mirrored": walkthrough.frames_mirrored, **walkthrough.mirror_evidence}))
        code, report, seconds = doctor(host, cli, env)
        (out / "doctor-readers.json").write_text(json.dumps(report, indent=1, sort_keys=True), encoding="utf-8")
        checks.append(outcome("doctor-readers", code == 0 and bool(report.get("readers")),
                              {"exit": code, "seconds": seconds, "readers": len(report.get("readers", []))}))
        code, refreshed, seconds = doctor(host, cli, env, "--refresh")
        (out / "doctor-readers-refresh.json").write_text(json.dumps(refreshed, indent=1, sort_keys=True), encoding="utf-8")
        checks.append(outcome("reader-refresh-timing", code == 0 and seconds < 60,
                              {"exit": code, "seconds": seconds, "codex": reader_rows(refreshed).get("codex")}))
        before = widget_frame(walkthrough)
        code, forced = quit_app(host, walkthrough, process)
        checks.append(outcome("quit", code == 0 and not forced, {"exit": code, "forced": forced}))
        checks.extend(restart_checks(host, walkthrough, exe, env, log, before))
    crashes = crash_reports(Path.home())
    checks.append(outcome("no-crash-report", not crashes, {"reports": crashes}))
    manifest = {"schemaVersion": 1, "profile": "synthetic", "sourceSHA": info.get("ModelPlanPublicSource"),
                "artifact": args.artifact, "host": facts, "steps": walkthrough.results, "checks": checks}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    (out / "SUMMARY.md").write_text(summary(manifest), encoding="utf-8")
    shutil.rmtree(home, ignore_errors=True)
    shutil.rmtree(str(home) + "-fresh", ignore_errors=True)
    failed = [r["step"] for r in manifest["steps"] if r["status"] != "pass"] + [c["check"] for c in checks if c["status"] == "fail"]
    print("not passed: " + (", ".join(failed) or "none"), flush=True)
    return 1 if failed else 0


def summary(manifest):
    lines = ["# Test build walkthrough", "", "Source `%s`, synthetic profile." % manifest["sourceSHA"], "",
             "| Step | Status | Reason |", "|---|---|---|"]
    lines += ["| %s | %s | %s |" % (r["step"], r["status"], (r.get("reason") or "").replace("|", "/")) for r in manifest["steps"]]
    lines += ["", "| Check | Status | Detail |", "|---|---|---|"]
    lines += ["| %s | %s | `%s` |" % (c["check"], c["status"], json.dumps(c["detail"], sort_keys=True)[:300]) for c in manifest["checks"]]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("app", "out", "home", "helper", "steps", "seed"):
        parser.add_argument("--" + flag, required=True)
    parser.add_argument("--source-sha")
    parser.add_argument("--artifact")
    args = parser.parse_args()
    sys.exit(run(args, Host(args.helper)))


if __name__ == "__main__":
    main()
