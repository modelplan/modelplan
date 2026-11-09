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
import hashlib
import socket
import subprocess
import sys
import threading
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


class WalkthroughSkip(Exception):
    """A step that this host cannot walk, such as a display mode it does not offer. Not a failure."""


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
        "label^": lambda n: str(n.get("label") or n.get("title") or "").startswith(value),
        "label~": lambda n: value in str(n.get("label") or n.get("title") or ""),
        "value": lambda n: n.get("value") == value,
        "value~": lambda n: value in str(n.get("value") or ""),
        "help~": lambda n: value in str(n.get("help") or ""),
        "dom^": lambda n: str(n.get("dom", "")).startswith(value),
        "role": lambda n: n.get("role") == value,
        "subrole": lambda n: n.get("subrole") == value,
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


def inside(frame, bounds, slack=1):
    return (frame[0] >= bounds[0] - slack and frame[1] >= bounds[1] - slack
            and frame[0] + frame[2] <= bounds[0] + bounds[2] + slack and frame[1] + frame[3] <= bounds[1] + bounds[3] + slack)


def visible_area(facts):
    """The main screen's visible area in top-left coordinates, as accessibility frames use.

    The helper reports AppKit frames, which count from the bottom: menu bar above, Dock below.
    """
    screen = facts["screens"][0]
    height = screen["frame"][3]
    x, y, w, h = screen["visible"]
    return [x, height - y - h, w, h]


def ring_order(tree):
    """Rings as the eye reads them: top to bottom, then left to right."""
    rings = [n for n in resolve_all(tree, "ax^:dock.subscription.") if visible(n)]
    return sorted(rings, key=lambda n: (round(n["frame"][1]), round(n["frame"][0])))


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

    def capture_window(self, path, window_id):
        """One window by its CGWindow number, without its shadow (-o). The PNG keeps the window's alpha, so a clear
        window shows as transparent and an opaque backing does not; the visual comparison lane reads this."""
        subprocess.run(["screencapture", "-x", "-o", "-l%d" % window_id, str(path)], check=True, timeout=30)

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
        self.measures = {}
        self.expected_card = None
        self.facts = None
        self.home = None
        self.live = None
        self.step_name = ""
        self.samples = []
        self.regions = {}
        self.named = {}
        self.step_id = ""

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
        started = self.host.now()
        self.await_target(action["target"], action.get("timeout", 15))
        if action.get("timed"):
            self.measures["secondsTo:" + action["target"]] = round(self.host.now() - started, 2)

    def op_awaitAbsent(self, action):
        """Wait until a target has left the screen, such as the first-run page still looking for tools."""
        deadline = self.host.now() + action.get("timeout", 15)
        while resolve(self.tree(), action["target"]) is not None:
            if self.host.now() >= deadline:
                raise WalkthroughError("still on screen after %ss: %s" % (action.get("timeout", 15), action["target"]))
            self.host.sleep(0.5)

    def op_when(self, action):
        """Run nested actions only when a target is on screen ("present"), is not ("absent"), or shows a value
        ("equals": {"target", "value"}), so one walk fits a build with the flow and a build without it (the
        first-run chooser, a widget that starts collapsed)."""
        if "equals" in action:
            node = resolve(self.tree(), action["equals"]["target"])
            hit = node is not None and str(node.get("value")) == action["equals"]["value"]
        else:
            target = action.get("present") or action.get("absent")
            hit = (resolve(self.tree(), target) is not None) == ("present" in action)
        if hit:
            for nested in action["then"]:
                getattr(self, "op_" + nested["op"])(nested)

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

    def op_clickFirst(self, action):
        """Click the first of several targets that is on screen; the step fails when none is."""
        tree = self.tree()
        for target in action["targets"]:
            node = resolve(tree, target)
            if node is not None:
                self.host.helper("click", *centre(node["frame"]))
                return
        raise WalkthroughError("none of the targets is on screen: " + ", ".join(action["targets"]))

    def op_hover(self, action):
        self.host.helper("move", *centre(self.need(action["target"])["frame"]), 0.5)
        self.host.sleep(action.get("seconds", 1))

    def op_hoverRemembered(self, action):
        """Point at a fraction of the frame remembered earlier, such as the edge where a collapsed widget waits."""
        if self.remembered is None:
            raise WalkthroughError("nothing remembered to point at")
        frame = self.remembered
        self.host.helper("move", frame[0] + frame[2] * action["at"][0], frame[1] + frame[3] * action["at"][1], 0.5)
        self.host.sleep(action.get("seconds", 1))

    def op_clickRing(self, action):
        """Click a ring by reading order or by target; the card that opens should carry its name."""
        tree = self.tree()
        if "target" in action:
            ring = resolve(tree, action["target"])
        else:
            rings = ring_order(tree)
            ring = rings[action["index"]] if len(rings) > action["index"] else None
        if ring is None:
            raise WalkthroughError("ring not on screen: %s" % action.get("target", action.get("index")))
        self.expected_card = ring.get("label")
        self.host.helper("click", *centre(ring["frame"]))

    def op_dragStrip(self, action):
        """Drag the cockpit by its title strip: left of the strip buttons, at their height."""
        window = self.need(action["window"])["frame"]
        button = self.need(action["strip"])["frame"]
        start = (window[0] + window[2] * action.get("x", 0.12), centre(button)[1])
        self.host.helper("down", *start)
        self.host.helper("held", start[0] + action["by"][0], start[1] + action["by"][1], action.get("seconds", 1.0))
        self.host.helper("up")

    def op_setDisplay(self, action):
        """Switch the main display to a size, or skip when this host does not offer it."""
        offered = {(m["width"], m["height"]) for m in self.host.helper("modes")}
        size = tuple(action["size"]) if action["size"] != "largest" else next(
            (c for c in DISPLAY_CANDIDATES if c in offered), None)
        if size not in offered:  # A stand-in with the same height, which is what decides a vertical fit.
            size = next((tuple(f) for f in action.get("fallback", []) if tuple(f) in offered), size)
            if size in offered:
                self.measures["requested"] = "x".join(map(str, action["size"]))
        if size not in offered:
            raise WalkthroughSkip("display %s not offered here; offered: %s" % (
                "x".join(map(str, action["size"])) if size is None else "%dx%d" % size,
                ", ".join("%dx%d" % m for m in sorted(offered, reverse=True)[:12])))
        if not self.host.helper("setmode", *size).get("set"):
            raise WalkthroughError("could not switch the display to %dx%d" % size)
        self.host.sleep(action.get("settle", 3))
        self.facts = self.host.helper("host")
        frame = self.facts["screens"][0]["frame"]
        self.screen = (frame[2], frame[3])
        self.measures["display"] = "%dx%d" % size

    def op_toggleCockpit(self, action):
        """Bring the cockpit to the wanted state with the menu bar icon; nothing to do when it is there already."""
        target = "label:ModelPlan Cockpit"
        if (resolve(self.tree(), target) is not None) == (action["want"] == "open"):
            return
        self.host.helper("click", *centre(self.need("status-item")["frame"]))
        if action["want"] == "open":
            self.await_target(target, action.get("timeout", 25))
            return
        # The icon closing the cockpit is its own step (cockpit-toggle-close); here the Close button backs it up.
        for fallback in (None, "label:Close"):
            if fallback is not None:
                self.host.helper("key", "escape")
                button = resolve(self.tree(), fallback)
                if button is None:
                    break
                self.host.helper("click", *centre(button["frame"]))
            deadline = self.host.now() + action.get("timeout", 5)
            while resolve(self.tree(), target) is not None and self.host.now() < deadline:
                self.host.sleep(0.25)
            if resolve(self.tree(), target) is None:
                return
        raise WalkthroughError("cockpit still open")

    def op_closeShutter(self, _):
        shutter = self.need("label:Porthole shutter")
        if str(shutter.get("value")) != "1":  # aria-pressed is true while closed.
            self.host.helper("click", *centre(shutter["frame"]))

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
        corrected = self.tree()
        painted = {}
        for n in rings:
            node = resolve(corrected, "ax:" + n["id"])
            if node is None:
                raise WalkthroughError("ring left the screen while mapping: " + str(n.get("label")))
            painted[n["id"]] = node["frame"]
        result = []
        for ring in rings:
            result.append({"ring": ring.get("label"), "cardAtPainted": self.card_at(centre(painted[ring["id"]])),
                           "cardAtReported": self.card_at(centre(ring["frame"])),
                           "reportedFrame": ring["frame"], "paintedFrame": painted[ring["id"]]})
        self.mirror_evidence["cards"] = result
        self.mirror_evidence["window"] = window["frame"] if window else None
        wrong = [r["ring"] for r in result if r["cardAtPainted"] != r["ring"]]
        self.measures["wrongCards"] = wrong
        if len(wrong) > 1:  # Seven stacked rings leave one hover on a neighbour's edge; more than one is a real mix-up.
            raise WalkthroughError("card at painted ring differs: " + ", ".join(map(str, wrong)))

    def op_mirrorPixels(self, _):
        """Only the critical ring paints red, so its reported frame should hold the red pixels."""
        raw = self.host.helper("tree", self.pid)
        window = resolve(raw, "window-of:ax:dock.grip.0")
        node = resolve(raw, "ax:dock.subscription.declared:synthetic-empty#manual")
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

    def op_rememberNamed(self, action):
        """Remember a frame under a name, for checks that compare a later frame with it."""
        self.named[action["name"]] = self.need(action["target"])["frame"]

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


    def op_startSession(self, _):
        """Start the running Codex session of the synthetic profile (it keeps going until the walk ends)."""
        if self.home is None:
            raise WalkthroughError("no profile to write a session into")
        if self.live is None:
            self.live = LiveSession(self.home, self.seed)
            # The ledger record needs the consent epoch and the Codex account's reference (the widget's ring id).
            ring = resolve(self.tree(), "label:Codex")
            ref = str((ring or {}).get("id", "")).rpartition(".")[2]
            cli = self.app / "Contents/Helpers/modelplan"
            epoch = consent_call(self.host, cli, child_environment(self.home), []).get("storeEpoch")
            if epoch and re.fullmatch("[0-9a-f]{16}", ref):
                self.live.record = (epoch, ref)
        self.live.start()

    def op_watch(self, action):
        """Read a target's title, value and help text again and again while the pointer rests where it is (or on it)."""
        self.samples = []
        if action.get("hover"):
            self.host.helper("move", *centre(self.need(action["target"])["frame"]), 0.5)
        end = self.host.now() + action["seconds"]
        while True:
            node = resolve(self.tree(), action["target"])
            if node is not None:
                self.samples.append({key: node.get(key) for key in ("title", "value", "label", "help") if node.get(key) is not None})
            if self.host.now() >= end:
                break
            self.host.sleep(action.get("every", 0.5))
        self.measures["samples"] = self.samples

    def op_dragFaderUp(self, action):
        """Hold a fader and pull it up by a detent or two, as a hand does, then let go over it."""
        fader = self.need(action["target"])
        x, y = centre(fader["frame"])
        self.remembered = fader.get("value")
        self.host.helper("down", x, y)
        self.host.helper("held", x, y - fader["frame"][3] * action.get("by", 0.3), action.get("seconds", 0.6))
        self.host.helper("up")

    def op_dismissHints(self, _):
        # A first-use hint is a card (help.card.<anchor>) with one button; there is no fixed count on purpose.
        for _ in range(3):
            card = resolve(self.tree(), "ax^:help.card.")
            button = next((n for n, _ in walk(card) if n.get("role") == "AXButton" and visible(n)), None) if card else None
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
        if kind == "cardNamed":
            node = resolve(tree, "ax:dock.card.text.name")
            name = node.get("value") if node else None
            if name != self.expected_card:
                raise WalkthroughError("card shows %r, expected %r" % (name, self.expected_card))
        if kind == "collapsed":
            node = resolve(tree, value)
            before = self.remembered
            if node is not None and (before is None or node["frame"][2] * node["frame"][3] > 0.5 * before[2] * before[3]):
                raise WalkthroughError("not collapsed: " + value)
        if kind == "allOnScreen":
            found = [n for n in resolve_all(tree, value) if visible(n)]
            screen = [0, 0, self.screen[0], self.screen[1]]
            outside = [n.get("id") or n.get("label") for n in found if not inside(n["frame"], screen)]
            if not found or outside:
                raise WalkthroughError("off screen: %s" % (", ".join(map(str, outside)) or "nothing found for " + value))
        if kind == "fits":
            node = resolve(tree, value)
            area = visible_area(self.facts or self.host.helper("host"))
            if node is None or not inside(node["frame"], area):
                raise WalkthroughError("%s at %s is not inside the visible area %s" % (value, node and node["frame"], area))
            record.setdefault("measures", {})["frame:" + value] = node["frame"]
        if kind == "newWindow" and not window_ids(self.windows()) - self.window_baseline:
            raise WalkthroughError("no new window opened")
        if kind == "noNewWindow" and window_ids(self.windows()) - self.window_baseline:
            raise WalkthroughError("a new window opened")
        if kind == "windowClosed" and not self.window_baseline - window_ids(self.windows()):
            raise WalkthroughError("no window closed")
        if kind == "anyExists" and not any(resolve(tree, t) is not None or resolve_all(tree, t) for t in value):
            raise WalkthroughError("none of these is on screen: " + ", ".join(value))
        if kind == "underStatusItem":
            node, icon = resolve(tree, value["target"]), resolve(tree, "status-item")
            if node is None or icon is None:
                raise WalkthroughError("nothing to place against the menu bar icon: " + value["target"])
            x, y, w, h = node["frame"]
            icon_x = centre(icon["frame"])[0]
            under = y <= icon["frame"][1] + icon["frame"][3] + value.get("down", 140) and x - value.get("slack", 30) <= icon_x <= x + w + value.get("slack", 30)
            record.setdefault("measures", {})["under:" + value["target"]] = {"frame": node["frame"], "icon": icon["frame"], "under": under}
            if under != value.get("is", True):
                raise WalkthroughError("%s is %sunder the menu bar icon (frame %s, icon %s)" % (value["target"], "" if under else "not ", node["frame"], icon["frame"]))
        if kind == "nearNamed":
            node, before = resolve(tree, value["target"]), self.named.get(value["name"])
            if node is None or before is None:
                raise WalkthroughError("nothing to compare with %s: %s" % (value["name"], value["target"]))
            axes = value.get("axes", "xy")
            gap = max([abs(centre(node["frame"])[0] - centre(before)[0])] * ("x" in axes) + [abs(centre(node["frame"])[1] - centre(before)[1])] * ("y" in axes) + [0])
            record.setdefault("measures", {})["gap:%s:%s" % (value["target"], value["name"])] = round(gap, 1)
            if (gap <= value.get("slack", 30)) != value.get("is", True):
                raise WalkthroughError("%s is %s px from where %s was (frame %s, was %s)" % (value["target"], round(gap), value["name"], node["frame"], before))
        if kind == "countAtLeast":
            found = [n for n in resolve_all(tree, value["target"]) if visible(n)]
            record.setdefault("measures", {})["count:" + value["target"]] = len(found)
            if len(found) < value["min"]:
                raise WalkthroughError("%d of %s on screen, expected at least %d" % (len(found), value["target"], value["min"]))
        if kind == "stable":
            texts = [json.dumps(sample, sort_keys=True) for sample in self.samples]
            if len(texts) < 3 or len(set(texts)) != 1:
                raise WalkthroughError("%s changed under the pointer: %s" % (value, "; ".join(sorted(set(texts)))[:300]))
        if kind == "valueIs":
            node = resolve(tree, value["target"])
            if node is None or str(node.get(value.get("key", "value"))) != value["is"]:
                raise WalkthroughError("%s is %r, expected %r" % (value["target"], node and node.get(value.get("key", "value")), value["is"]))
        if kind == "regionShot":
            self.region_shot(value, record, keep=True)
        if kind == "regionDiffers":
            share = self.compare_region(value, record)
            if share < value["min"]:
                raise WalkthroughError("%s looks the same as in %s (%.5f changed, need %s)" % (value["target"], value["step"], share, value["min"]))
        if kind == "markSizes":
            self.mark_sizes(value, shot_dir, record)
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

    def region_shot(self, value, record, keep=False):
        """A part of a surface (fractions x, y, width, height of its frame) photographed alone. With `keep` the picture
        stays beside the manifest as evidence and later steps can compare with it by step id."""
        node = resolve(self.tree(), value["target"])
        if node is None:
            raise WalkthroughError("nothing to photograph: " + value["target"])
        x, y, w, h = node["frame"]
        fx, fy, fw, fh = value["at"]
        name = "%s.region.png" % self.step_name if keep else "measure.png"
        self.host.capture(self.out / name, [x + w * fx, y + h * fy, w * fw, h * fh])
        if keep:
            record["region"] = name
            self.regions[self.step_id] = name
        return self.out / name

    def compare_region(self, value, record):
        before = self.regions.get(value["step"])
        if before is None:
            raise WalkthroughError("no picture of %s to compare with" % value["step"])
        path = self.region_shot(value, record, keep=True)
        share = self.host.helper("diff", path, self.out / before)["changedShare"]
        record.setdefault("measures", {})["regionChangedShareFrom:" + value["step"]] = round(share, 5)
        return share

    def mark_sizes(self, value, record_shot, record):
        """The size of the vendor mark at the left of each tab, measured from the picture by glyph bounds (the mark
        pixels differ from the tab's background), not from a frame: marks of different artwork can sit in equal boxes."""
        sizes = {}
        for target in value["targets"]:
            node = resolve(self.tree(), target)
            if node is None:
                raise WalkthroughError("tab not on screen: " + target)
            x, y, w, h = node["frame"]
            path = self.out / ("%s.tab-%d.png" % (self.step_name, len(sizes)))
            self.host.capture(path, [x, y, w, h])
            glyph = self.host.helper("glyph", path, value.get("share", 0.22))
            sizes[target] = {"file": path.name, "width": glyph.get("width"), "height": glyph.get("height")}
        record.setdefault("measures", {})["marks"] = sizes
        extent = [max(g["width"] or 0, g["height"] or 0) for g in sizes.values()]
        if not extent or min(extent) < value.get("least", 6):
            raise WalkthroughError("no mark found: " + json.dumps(sizes))
        if max(extent) > min(extent) * (1 + value.get("within", 0.35)):
            raise WalkthroughError("mark sizes differ by more than %d%%: %s" % (value.get("within", 0.35) * 100, json.dumps(sizes)))

    def window_holding(self, frame):
        """The smallest on-screen window of the app whose bounds contain the centre of `frame`."""
        cx, cy = frame[0] + frame[2] / 2, frame[1] + frame[3] / 2
        found = [win for win in self.windows() if win.get("onScreen") and win.get("bounds")
                 and win["bounds"][0] <= cx <= win["bounds"][0] + win["bounds"][2]
                 and win["bounds"][1] <= cy <= win["bounds"][1] + win["bounds"][3]]
        return min(found, key=lambda win: win["bounds"][2] * win["bounds"][3], default=None)

    def run_step(self, index, step):
        name = "%02d-%s" % (index, step["id"])
        self.step_name, self.step_id = name, step["id"]
        record = {"step": step["id"], "title": step["title"], "expected": step["expected"],
                  "prototype": step.get("prototype"), "file": None, "crop": None, "tree": None}
        skipped_needs = [need for need in step.get("requires", []) if self.statuses.get(need) == "skipped"]
        if skipped_needs:
            record.update(status="skipped", reason="needs %s, which was skipped" % ", ".join(skipped_needs))
            return record
        blocked = [need for need in step.get("requires", []) if self.statuses.get(need) not in ("pass", "skipped")]
        if blocked:
            record.update(status="not-run", reason="needs " + ", ".join(blocked))
            return record
        started = self.host.now()
        reasons, skipped = [], None
        only_if = step.get("onlyIf")
        if only_if and resolve(self.tree(), only_if) is None:
            # A control that only some builds have (the detach key, D88): a build without it skips the step.
            record.update(status="skipped", reason="this build has no " + only_if, seconds=0)
            return record
        self.measures = {}
        self.window_baseline = window_ids(self.windows())
        try:
            for action in step.get("actions", []):
                getattr(self, "op_" + action["op"])(action)
        except WalkthroughSkip as skip:
            skipped = str(skip)
        except WalkthroughError as error:
            reasons.append(str(error))
        except Exception as error:  # A harness fault is this step's failure, not the end of the manifest.
            reasons.append("harness error: %s: %s" % (type(error).__name__, error))
        if self.measures:
            record["measures"] = dict(self.measures)
        if skipped:
            record.update(status="skipped", reason=skipped, seconds=round(self.host.now() - started, 2))
            return record
        # A failed step is photographed too: the picture shows where it stopped.
        self.host.capture(self.out / (name + ".png"))
        record["file"] = name + ".png"
        tree = self.tree()
        (self.out / (name + ".tree.json")).write_text(json.dumps(tree, indent=1, sort_keys=True), encoding="utf-8")
        record["tree"] = name + ".tree.json"
        crop = step.get("shot", {}).get("crop")
        if crop:
            # "remembered" crops the frame an action remembered, such as where a collapsed widget was.
            node = {"frame": self.remembered} if crop == "remembered" and self.remembered else resolve(tree, crop)
            if node is not None:
                self.host.capture(self.out / (name + ".crop.png"), node["frame"])
                record["crop"] = name + ".crop.png"
                self.crops[step["id"]] = record["crop"]
        window = step.get("shot", {}).get("window")
        if window:
            # The app window that holds the target, captured alone with its alpha (visual comparison evidence).
            if window == "remembered-edge" and self.remembered:
                # The collapsed sliver is a thin window on the edge where the widget was: look there, not at the old centre.
                x, y, w, h = self.remembered
                edge = x + 2 if x < self.screen[0] / 2 else x + w - 2
                node = {"frame": [edge - 1, y + h / 2, 2, 2]}
            else:
                node = {"frame": self.remembered} if window == "remembered" and self.remembered else resolve(tree, window)
            shot = node and self.window_holding(node["frame"])
            if shot is not None:
                self.host.capture_window(self.out / (name + ".window.png"), shot["id"])
                record["window"] = {"file": name + ".window.png", "bounds": shot["bounds"], "target": node["frame"]}
        if not reasons:
            for check in step.get("checks", []):
                try:
                    self.check(check, self.out, record)
                except WalkthroughError as error:
                    reasons.append(str(error))
                except Exception as error:
                    reasons.append("harness error in check: %s: %s" % (type(error).__name__, error))
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


STUB_CODEX = """#!/bin/sh
# Synthetic Codex runtime: answers the app-server questions the reader asks, with invented numbers.
[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
  case "$line" in
    *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
    *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"walkthrough@example.invalid","planType":"%(plan)s"},"requiresOpenaiAuth":true}}' ;;
    *'"method":"account/rateLimits/read"'*) echo '{"id":2,"result":%(limits)s}' ;;
  esac
done
"""


def codex_runtime_script(seed, now):
    """A stand-in for the `codex` executable (found through MODELPLAN_CODEX), so the real account reader runs on
    the runner and keeps answering: a static cache file would go stale and end in reader_error after about five
    minutes, because the runner has no Codex. The numbers are invented: one window nearly used up, a reserve balance."""
    codex = seed["codex"]
    epoch = lambda minutes: int((now + datetime.timedelta(minutes=minutes)).timestamp())
    primary, secondary = codex["windows"]
    limits = {"ordinaryUsageAllowed": True, "rateLimits": None, "rateLimitsByLimitId": {"codex": {
        "limitId": "codex", "planType": codex["plan"],
        "primary": {"usedPercent": 100 - primary["remainingPercent"], "windowDurationMins": primary["windowMinutes"], "resetsAt": epoch(primary["resetMinutes"])},
        "secondary": {"usedPercent": 100 - secondary["remainingPercent"], "windowDurationMins": secondary["windowMinutes"], "resetsAt": epoch(secondary["resetMinutes"])},
        "credits": {"hasCredits": True, "unlimited": False, "balance": str(codex["reserveCredits"])}}},
        "rateLimitResetCredits": {"availableCount": codex["resetCards"], "credits": [
            {"id": "synthetic-credit-%d" % i, "resetType": "codexRateLimits", "status": "available",
             "grantedAt": epoch(-60), "expiresAt": epoch(60 * 24 * (20 + i)), "title": "Full reset", "description": None}
            for i in range(codex["resetCards"])]}}
    return STUB_CODEX % {"plan": codex["plan"], "limits": json.dumps(limits, separators=(",", ":"))}


def short_ref(*parts):
    return hashlib.sha256("\x00".join(parts).encode()).hexdigest()[:16]


def perf_ledger(seed, now, consent):
    """Seven days of session history in the performance ledger (<cache>/observed/perf.json), stamped with the grant
    that the CLI just recorded, because the reader only admits records of the current grant. Invented counts."""
    history, epoch = seed["history"], {"storeEpoch": consent["storeEpoch"], "revokedGeneration": 0}
    rows, sessions = [], []
    for model in history["models"]:
        for back in range(history["days"]):
            day = (now - datetime.timedelta(days=back)).strftime("%Y-%m-%d")
            requests, tokens = model["requests"][back], model["tokens"][back]
            rows.append({"grantEpoch": epoch, "day": day, "source": model["source"], "model": model["model"], "effortStatus": "reported",
                         "effort": model["effort"], "parser": "codex-rollout/1", "eligibility": "gen-v1",
                         "observedRequests": requests, "observedOutputTokens": tokens,
                         "eligibleRequests": requests, "eligibleOutputTokens": tokens, "genMs": tokens * 12,
                         "turns": max(1, requests // 6), "turnMs": tokens * 20, "turnOutputTokens": tokens,
                         "mixedConfigTurnsExcluded": 0, "lastAt": stamp(now - datetime.timedelta(days=back, hours=1))})
    for index in range(history["sessions"]):
        model = history["models"][index % len(history["models"])]
        back = index % history["days"]
        last = (now - datetime.timedelta(days=back, hours=2)).replace(second=0, microsecond=0)
        sessions.append({"grantEpoch": epoch, "ref": short_ref("session", str(index)), "key": short_ref("key", str(index)) * 2,
                         "source": model["source"], "projectRef": short_ref("project", "alpha"), "projectLabel": "alpha",
                         "firstAt": stamp(last - datetime.timedelta(minutes=40)), "lastAt": stamp(last),
                         "days": [{"day": last.strftime("%Y-%m-%d"), "model": model["model"], "effortStatus": "reported",
                                   "effort": model["effort"], "observedRequests": 20 + index, "observedOutputTokens": 9000 + 500 * index}]})
    return {"schemaVersion": 1, "since": stamp(now - datetime.timedelta(days=history["days"] + 1)), "rows": rows, "sessions": sessions}


def stamp_micro(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def live_session_lines(now, count, cwd, model, effort="high", first=True):
    """Codex rollout lines of a turn that is still running: it starts, names its model, then keeps calling tools
    (the last line is a tool output, so the turn has not ended). Same shapes as the app-server's own live tests."""
    lines = []
    if first:
        lines.append({"timestamp": stamp_micro(now - datetime.timedelta(seconds=count * 3 + 3)), "type": "session_meta", "payload": {"cwd": cwd}})
        lines.append({"timestamp": stamp_micro(now - datetime.timedelta(seconds=count * 3 + 2)), "type": "event_msg", "payload": {"type": "task_started"}})
        lines.append({"timestamp": stamp_micro(now - datetime.timedelta(seconds=count * 3 + 1)), "type": "turn_context",
                      "payload": {"model": model, "effort": effort, "cwd": cwd}})
    for i in range(count):
        at = now - datetime.timedelta(seconds=(count - i) * 3)
        # The tool call, then its output a second later: the output restarts the turn's clock, which is what keeps it live.
        lines.append({"timestamp": stamp_micro(at), "type": "response_item", "payload": {"type": "function_call"}})
        lines.append({"timestamp": stamp_micro(at + datetime.timedelta(seconds=1)), "type": "response_item", "payload": {"type": "function_call_output"}})
    # Compact JSON: the rollout parser matches the head of each line byte for byte, as Codex writes it.
    return "".join(json.dumps(line, separators=(",", ":")) + "\n" for line in lines)


LIVE_KEY = "synthetic-walkthrough-live"


def upsert_live_record(home, epoch, subscription_ref, model, effort, started, now):
    """The running session as the performance ledger holds it (a `live` record in perf.json), written with an atomic
    rename so the app never reads half a file. The app's own observation of the rollout should produce the same
    record; the packaged app did not do so on a hosted Mac in this profile, so the walk states it too."""
    path = Path(home) / "Library/Caches/modelplan/observed/perf.json"
    ledger = json.loads(path.read_text(encoding="utf-8"))
    live = [r for r in ledger.get("live", []) if r.get("key") != LIVE_KEY]
    live.append({"grantEpoch": {"storeEpoch": epoch, "revokedGeneration": 0}, "key": LIVE_KEY, "ref": short_ref("live", LIVE_KEY),
                 "source": "codex", "model": model, "effort": effort, "speed": "", "projectRef": short_ref("project", "alpha"),
                 "projectLabel": "alpha", "subscriptionRef": subscription_ref, "startedAt": stamp(started), "lastAt": stamp(now), "running": True})
    ledger["live"] = live
    temporary = path.with_name("perf.json.walkthrough")
    temporary.write_text(json.dumps(ledger), encoding="utf-8")
    os.replace(temporary, path)


class LiveSession:
    """One Codex session that keeps running while the walk goes on: a rollout under .codex/sessions that gets
    another tool call every few seconds, so the app reads a running turn bound to the Codex account (a session
    is live for five minutes after its last record)."""
    EVERY = 8

    def __init__(self, home, seed, clock=time.time):
        self.clock = clock
        today = datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)
        folder = Path(home) / ".codex/sessions" / today.strftime("%Y/%m/%d")
        folder.mkdir(parents=True, exist_ok=True)
        self.cwd = str(Path(home) / "alpha")
        (Path(self.cwd) / ".git").mkdir(parents=True, exist_ok=True)
        self.path, self.model, self.effort = folder / "rollout-synthetic-walkthrough.jsonl", seed["session"]["model"], seed["session"]["effort"]
        self.written, self.stopping, self.thread = 0, threading.Event(), None
        self.home, self.record = home, None  # record: (store epoch, subscription ref) once the ledger entry is wanted
        self.started = datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)

    def append(self, count):
        now = datetime.datetime.fromtimestamp(self.clock(), datetime.timezone.utc)
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(live_session_lines(now, count, self.cwd, self.model, self.effort, first=self.written == 0))
        self.written += count
        if self.record is not None:
            try:
                upsert_live_record(self.home, self.record[0], self.record[1], self.model, self.effort, self.started, now)
            except (OSError, ValueError):
                pass  # The app may be rewriting the file; the next beat writes it again.

    def start(self):
        if self.thread is not None:
            return
        self.append(4)

        def keep():
            while not self.stopping.wait(self.EVERY):
                self.append(2)
        self.thread = threading.Thread(target=keep, daemon=True)
        self.thread.start()

    def stop(self):
        self.stopping.set()


def child_environment(home):
    """The CLI and the app see the synthetic home, and only the stand-in Codex runtime (the runner has none)."""
    return {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "TMPDIR": str(home / "tmp") + "/",
            "PATH": str(home / "bin") + ":/usr/bin:/bin", "LANG": "en_US.UTF-8", "MODELPLAN_CODEX": str(home / "bin/codex")}


def consent_call(host, cli, env, arguments, body=None):
    result = host.run([str(cli), "consent", *arguments, "--json"], env, stdin=None if body is None else json.dumps(body))
    if result.returncode != 0:
        raise WalkthroughError("consent %s failed" % " ".join(arguments))
    return json.loads(result.stdout)


def seed_profile(host, cli, home, seed, now):
    """Write invented readings through the files and inputs the bundled CLI already reads:

    - tool markers (`~/.claude`, `~/.codex`, ...), which the first-run page detects;
    - `consent grant` of the local-history and usage scopes, as the first-run page records them;
    - Claude Code: a marker only. Nothing can read its quota here (no login, no Keychain), so it is the unreadable subscription (G3-38);
    - Codex: a stand-in `codex` executable (MODELPLAN_CODEX) answering `account/rateLimits/read`: one window nearly
      used up and a reserve balance (the reserve card line);
    - Gemini: an expired login, a second detected tool that cannot be read;
    - declared plans in `local.json` (manual rings);
    - the performance ledger with seven days of sessions, and later a running session (`LiveSession`).
    """
    (home / "tmp").mkdir(parents=True, exist_ok=True)
    (home / "bin").mkdir(exist_ok=True)
    for marker in seed["markers"]:
        (home / marker).mkdir(parents=True, exist_ok=True)
    env = child_environment(home)
    (home / "bin/codex").write_text(codex_runtime_script(seed, now), encoding="utf-8")
    (home / "bin/codex").chmod(0o755)
    expired = int((now - datetime.timedelta(minutes=seed["gemini"]["expiredMinutesAgo"])).timestamp() * 1000)
    (home / ".gemini/oauth_creds.json").write_text(json.dumps({"access_token": "synthetic-not-a-token", "expiry_date": expired}), encoding="utf-8")
    consent_call(host, cli, env, ["init"])
    before = consent_call(host, cli, env, [])
    consent_call(host, cli, env, ["grant"], {
        "requestId": "00000000-0000-4000-8000-000000000001", "expectStoreEpoch": before["storeEpoch"],
        "expectGeneration": before["generation"], "consentTextVersion": before["consentTextVersion"],
        "allow": seed["consent"], "deny": []})
    after = consent_call(host, cli, env, [])
    config = home / ".config/modelplan"
    config.mkdir(parents=True, exist_ok=True)
    (config / "local.json").write_text(json.dumps(declared_quota(seed, now)), encoding="utf-8")
    observed = home / "Library/Caches/modelplan/observed"
    observed.mkdir(parents=True, exist_ok=True)
    (observed / "perf.json").write_text(json.dumps(perf_ledger(seed, now, after)), encoding="utf-8")
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
    # The widget is anchored by its edge and its centre along the edge; its height follows the station count,
    # which can differ right after a relaunch (a reader that is not read yet), so height is not compared here.
    same = before is not None and after is not None and all((
        abs(after[0] - before[0]) <= 2,
        abs(after[2] - before[2]) <= 2,
        abs((after[1] + after[3] / 2) - (before[1] + before[3] / 2)) <= 2,
    ))
    checks.append(outcome("restart-widget-place", same, {"before": before, "after": after}))
    if before is not None and after is not None and abs(after[3] - before[3]) > 2:
        # Same family as G3-36: a station that was there before the quit shows up late (or not yet).
        checks.append({"check": "restart-station-late", "status": "info",
                       "detail": {"heightBefore": before[3], "heightAfter": after[3]}})
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


PATH_PATTERN = re.compile(r"(?:[A-Za-z]:\\|~?/)(?:[^\s\"'<>:,;()\[\]{}]+/)*[^\s\"'<>:,;()\[\]{}]*")
UUID_PATTERN = re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b")
LONG_HEX_PATTERN = re.compile(r"\b[0-9A-Fa-f]{16,}\b")


def secret_tokens(secrets):
    """Every known user or host name, whole and split on whitespace, longest first."""
    found = set()
    for secret in secrets:
        secret = str(secret or "").strip()
        if len(secret) > 1:
            found.add(secret)
        found.update(part for part in secret.split() if len(part) > 1)
    return sorted(found, key=len, reverse=True)


def scrub_text(text, secrets=()):
    """Replace anything that names the runner: absolute paths, UUIDs, long hex ids, and known user or host names
    (the whole name and each whitespace-separated part, any script, any case)."""
    text = UUID_PATTERN.sub("<id>", str(text))
    text = PATH_PATTERN.sub("<path>", text)
    text = LONG_HEX_PATTERN.sub("<id>", text)
    for secret in secret_tokens(secrets):
        text = re.sub(re.escape(secret), "<redacted>", text, flags=re.IGNORECASE)
    return text


def scrub_value(value, secrets=()):
    """Scrub every string in a JSON value before it is serialised, so no escaping can hide a name."""
    if isinstance(value, str):
        return scrub_text(value, secrets)
    if isinstance(value, list):
        return [scrub_value(v, secrets) for v in value]
    if isinstance(value, dict):
        return {k: scrub_value(v, secrets) for k, v in value.items()}
    return value


def redact_crash_report(raw, secrets=()):
    """Reduce a macOS .ips crash report (a JSON header line, then a JSON body) to what diagnosis needs: the app
    version, the exception type and code, and the crashed thread's frames as image name, symbol and offset.
    Everything else is dropped, so paths, user and host names, ids, procPath and userID never get through; a
    regex pass then scrubs what remains. Returns None when the report cannot be parsed."""
    head, _, rest = raw.partition("\n")
    try:
        header, body = json.loads(head), json.loads(rest)
    except ValueError:
        try:
            header, body = {}, json.loads(raw)
        except ValueError:
            return None
    if not isinstance(body, dict):
        return None
    header = header if isinstance(header, dict) else {}
    images = body.get("usedImages") or []
    threads = body.get("threads") or []
    index = body.get("faultingThread")
    thread = threads[index] if isinstance(index, int) and 0 <= index < len(threads) else {}
    frames = []
    for frame in thread.get("frames") or []:
        image = images[frame["imageIndex"]] if isinstance(frame.get("imageIndex"), int) and 0 <= frame["imageIndex"] < len(images) else {}
        name = image.get("name") or Path(str(image.get("path", ""))).name
        frames.append({"image": name, "symbol": frame.get("symbol"), "symbolLocation": frame.get("symbolLocation"),
                       "imageOffset": frame.get("imageOffset")})
    exception = body.get("exception") or {}
    kept = {"appVersion": body.get("bundleInfo", {}).get("CFBundleShortVersionString") or header.get("app_version"),
            "build": body.get("bundleInfo", {}).get("CFBundleVersion") or header.get("build_version"),
            "exceptionType": exception.get("type"), "signal": exception.get("signal"),
            "exceptionCodes": exception.get("codes"), "subtype": exception.get("subtype"),
            "terminationReason": (body.get("termination") or {}).get("indicator"),
            "crashedThreadName": thread.get("name") or thread.get("queue"), "frames": frames}
    kept = scrub_value(kept, secrets)
    # Second pass on the serialised text, unescaped, in case a name only appears across fields.
    return json.loads(scrub_text(json.dumps(kept, ensure_ascii=False), secrets))


def keep_crash_reports(home, names, out):
    """Keep a redacted summary of the app's crash reports next to the manifest: without it a crash on a hosted Mac
    leaves no trace. The raw .ips is never copied, because it embeds absolute host paths, the session user name,
    procPath, userID and host identifiers that must stay out of a public artifact (see the sessionUser note in run).
    Each report becomes <name>.redacted.json, built by redact_crash_report from an allow-list of fields."""
    if not names:
        return
    target = out / "crash-reports"
    target.mkdir(exist_ok=True)
    secrets = [home.name, os.environ.get("USER", ""), os.environ.get("LOGNAME", ""), socket.gethostname(),
               socket.gethostname().split(".")[0]]  # scrub_text also splits each on whitespace
    for name in names:
        raw = (home / "Library/Logs/DiagnosticReports" / name).read_text(encoding="utf-8", errors="replace")
        summary = redact_crash_report(raw, secrets) or {"unparsed": True}
        (target / (Path(name).stem + ".redacted.json")).write_text(json.dumps(summary, indent=1, sort_keys=True, ensure_ascii=False), encoding="utf-8")


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
    walkthrough.facts = facts
    walkthrough.home = home
    fresh = fresh_profile_probe(host, walkthrough, exe, cli, Path(str(home) + "-fresh"), seed, out)
    # Public data only. Without it the cockpit has no faders, no HUD and no enlarged view.
    env = seed_profile(host, cli, home, seed, datetime.datetime.now(datetime.timezone.utc))
    synced = host.run([str(cli), "sync"], env, timeout=130)
    checks = [fresh, outcome("publication-sync", synced.returncode == 0, {"exit": synced.returncode})]
    try:
        checks.extend(walk_app(host, walkthrough, exe, cli, env, out))
    except Exception as error:  # Still write the manifest: the pictures so far are the evidence.
        checks.append(outcome("harness", False, {"error": "%s: %s" % (type(error).__name__, error)}))
    crashes = crash_reports(Path.home())
    checks.append(outcome("no-crash-report", not crashes, {"reports": crashes}))
    keep_crash_reports(Path.home(), crashes, out)
    # The session user name stays out of a public artifact even when it is only "runner".
    host_facts = {k: v for k, v in facts.items() if k != "sessionUser"}
    manifest = {"schemaVersion": 1, "profile": "synthetic", "sourceSHA": info.get("ModelPlanPublicSource"),
                "artifact": args.artifact, "host": host_facts, "steps": walkthrough.results, "checks": checks}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    (out / "SUMMARY.md").write_text(summary(manifest), encoding="utf-8")
    (out / "walkthrough-summary.json").write_text(json.dumps(machine_summary(manifest), indent=1, sort_keys=True), encoding="utf-8")
    shutil.rmtree(home, ignore_errors=True)
    shutil.rmtree(str(home) + "-fresh", ignore_errors=True)
    failed = failures(manifest)
    print("not passed: " + (", ".join(failed) or "none"), flush=True)
    return 1 if failed else 0


def machine_summary(manifest):
    """One row per scenario for a machine reader (the coordinator's auto-verify.sh): id, pass / fail / blocked, evidence.
    A step the host or the build cannot walk is "blocked" (its reason says why), never a silent pass."""
    states = {"pass": "pass", "skipped": "blocked"}
    rows = []
    for r in manifest["steps"]:
        evidence = [r[k] for k in ("file", "crop", "tree") if r.get(k)]
        if isinstance(r.get("window"), dict) and r["window"].get("file"):
            evidence.append(r["window"]["file"])
        rows.append({"id": r["step"], "status": states.get(r["status"], "fail"), "reason": r.get("reason") or "",
                     "requirement": r.get("requirement"), "evidence": evidence})
    rows += [{"id": "check:" + c["check"], "status": {"pass": "pass", "info": "pass"}.get(c["status"], "fail"),
              "reason": "", "requirement": None, "evidence": ["manifest.json"]} for c in manifest["checks"]]
    counts = {k: sum(1 for x in rows if x["status"] == k) for k in ("pass", "fail", "blocked")}
    return {"schemaVersion": 1, "sourceSHA": manifest.get("sourceSHA"), "artifact": manifest.get("artifact"),
            "counts": counts, "ok": counts["fail"] == 0, "scenarios": rows}


def failures(manifest):
    """Steps that did not pass (a host that cannot walk a step skips it) and failed checks."""
    return ([r["step"] for r in manifest["steps"] if r["status"] not in ("pass", "skipped")]
            + [c["check"] for c in manifest["checks"] if c["status"] == "fail"])


def walk_app(host, walkthrough, exe, cli, env, out):
    checks = []
    with (out / "app.log").open("w", encoding="utf-8") as log:
        process, first_window, first_reading = launch_app(host, walkthrough, exe, env, log)
        checks.append(outcome("launch", first_window is not None and process.poll() is None,
                              {"firstWindowSeconds": first_window}))
        # A fresh profile starts with the first-run page and a collapsed widget, so no ring is on screen to time here;
        # the relaunch (restart-launch) times the first reading on a settled profile.
        checks.append({"check": "reader-first-reading", "status": "info", "detail": {"seconds": first_reading}})
        walkthrough.walk_steps()
        checks.append(seed_evidence(host, cli, env, walkthrough.home, walkthrough.live))
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
    return checks


def seed_evidence(host, cli, env, home, live):
    """What the app made of the seeded session after the walk, for a reader of the manifest: the performance ledger's
    live records and counts, the rollout the thread wrote, and the consent scopes in force. Info only."""
    detail = {"rolloutLines": None, "ledger": None, "consent": None}
    try:
        if live is not None:
            detail["rolloutLines"] = len(live.path.read_text(encoding="utf-8").splitlines())
        ledger = json.loads((home / "Library/Caches/modelplan/observed/perf.json").read_text(encoding="utf-8"))
        detail["ledger"] = {"rows": len(ledger.get("rows", [])), "sessions": len(ledger.get("sessions", [])), "since": ledger.get("since"),
                            "live": [{k: r.get(k) for k in ("source", "model", "running", "lastAt", "subscriptionRef")} for r in ledger.get("live", [])]}
        state = consent_call(host, cli, env, [])
        detail["consent"] = {k: state[k] for k in ("scopes", "storeEpoch", "generation") if k in state}
    except (OSError, ValueError, WalkthroughError) as error:
        detail["error"] = "%s: %s" % (type(error).__name__, error)
    return {"check": "seed-evidence", "status": "info", "detail": detail}


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
