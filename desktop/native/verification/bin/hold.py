# SPDX-License-Identifier: MIT
"""Keep a subject open for `holdSeconds`, and serve in-run probes while it is open.

`launch.py` owns a `Hold` for the whole run. When the hold has elapsed it writes the stop file and
the normal close follows, so the guardian ends `stopped` and the booking can finish. Probes run
inside the launcher, so they use the candidate's own engine with the environment the app gives it
and they always end before the product backup is restored. A later tool call asks for one with:

  hold.py --config RUN.json doctor readers --json

The output stays in `<subjectPidPath>.probes/` (mode 0600, outside the removable scratch); the
run manifest records only the command, exit status and output hash. Only PROBES can run.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from product_backup import write_json

HOLD_DONE = 'hold-complete'
HOLD_SHORT = 'subject-ended-before-hold'
PROBES = (('doctor', 'readers', '--json'),)  # sanitised and cache only, so a probe reads no provider
PROBE_SECONDS = 30.0
CLOSE_RESERVE = 60  # guardian's 30-second reserve, plus subject start and a last probe
CONTRACT = Path(__file__).resolve().parents[4] / 'schema' / 'app-cli' / 'child-environment.json'


def probe_dir(config):
    return Path(config['subjectPidPath'] + '.probes')


def check_fits(config, now):
    """Refuse a hold the lease would cut short: the stop file would end it as a failure."""
    latest = config['lease']['expiresAt'] - CLOSE_RESERVE
    if now + config['holdSeconds'] > latest:
        raise ValueError(f'holdSeconds {config["holdSeconds"]} does not fit the booking; {int(latest - now)} left')


def engine_env(env):
    """The subject environment as the app hands it to its engine (the launch contract's keys)."""
    keys = set(json.loads(CONTRACT.read_text())['allowedKeys'])
    return {key: value for key, value in env.items() if key in keys}


class Hold:
    """Non-blocking: `tick` runs in the launcher's supervision loop, which must keep polling."""
    def __init__(self, seconds, directory, helper, env):
        self.seconds, self.directory, self.helper, self.env = seconds, Path(directory), helper, env
        self.directory.mkdir(mode=0o700)
        self.started = self.end = None
        self.done = False
        self.active = None
        self.seen = set()
        self.probes = []

    def begin(self, now):
        self.started, self.end = now, now + self.seconds

    def tick(self, now):
        """True once the hold has elapsed and no probe is running."""
        if self.active is not None:
            self.collect(now)
        if self.active is None and now < self.end:
            self.next_request(now)
        if self.active is None and now >= self.end:
            self.done = True
        return self.done

    def next_request(self, now):
        for path in sorted(self.directory.glob('*.request.json')):
            name = path.name[:-len('.request.json')]
            if name in self.seen:
                continue
            self.seen.add(name)
            try:
                argv = json.loads(path.read_text())['argv']
            except (OSError, ValueError, KeyError, TypeError):
                argv = None
            if self.helper is None:
                self.finish(name, argv, now, error='probes need an app-zip subject')
            elif not isinstance(argv, list) or tuple(argv) not in PROBES:
                self.finish(name, argv, now, error='probe not allowed')
            else:
                self.launch(name, argv, now)
                if self.active is not None:
                    return

    def launch(self, name, argv, now):
        def output(suffix):
            return os.open(self.directory / (name + suffix), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        out, err = output('.stdout'), output('.stderr')
        try:
            process = subprocess.Popen([str(self.helper), *argv], stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                       env=engine_env(self.env))
            self.active = dict(name=name, argv=argv, process=process, startedAt=now)
        except OSError as error:
            self.finish(name, argv, now, error=type(error).__name__)
        finally:
            os.close(out); os.close(err)

    def collect(self, now):
        probe = self.active
        code = probe['process'].poll()
        late = code is None and now - probe['startedAt'] >= PROBE_SECONDS
        if code is None and not late:
            return
        if late:
            self.stop_active()
        self.active = None
        self.finish(probe['name'], probe['argv'], now, code=probe['process'].returncode, error='timeout' if late else None)

    def stop_active(self):
        process = self.active['process']
        process.kill()
        process.wait()

    def finish(self, name, argv, now, code=None, error=None):
        stdout = self.directory / (name + '.stdout')
        result = dict(argv=argv, exit=code, error=error, at=now, stdoutPath=str(stdout) if stdout.exists() else None,
                      stdoutSHA256=hashlib.sha256(stdout.read_bytes()).hexdigest() if stdout.exists() else None)
        temporary = self.directory / (name + '.result.tmp')
        write_json(temporary, result)
        os.replace(temporary, self.directory / (name + '.result.json'))
        self.probes.append({k: result[k] for k in ('argv', 'exit', 'error', 'stdoutSHA256')})

    def close(self, now):
        """Before the restore: a probe still running is stopped and recorded."""
        if self.active is not None:
            probe = self.active
            self.stop_active()
            self.active = None
            self.finish(probe['name'], probe['argv'], now, code=probe['process'].returncode, error='run-ended')

    def summary(self, now):
        held = 0 if self.started is None else round(now - self.started, 1)
        return dict(requestedSeconds=self.seconds, heldSeconds=held, complete=self.done, probes=self.probes)


def request(config, argv, timeout, clock=time.monotonic, sleep=time.sleep):
    """Ask the running launcher for one probe and return its result."""
    if tuple(argv) not in PROBES:
        raise ValueError('probe not allowed: ' + ' '.join(argv))
    directory = probe_dir(config)
    if not directory.is_dir():
        raise ValueError('no hold run is serving probes')
    name = f'{os.getpid()}-{time.time_ns()}'
    temporary = directory / (name + '.request.tmp')
    write_json(temporary, dict(argv=argv))
    os.replace(temporary, directory / (name + '.request.json'))
    result = directory / (name + '.result.json')
    end = clock() + timeout
    while not result.exists():
        if clock() >= end:
            raise TimeoutError('no probe result: the hold may have ended')
        sleep(0.1)
    return json.loads(result.read_text())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--timeout', type=float, default=PROBE_SECONDS + 15)
    parser.add_argument('probe', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        result = request(json.loads(args.config.read_text()), args.probe, args.timeout)
    except (OSError, ValueError) as error:
        print(json.dumps(dict(error=str(error))), file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0 if result['exit'] == 0 else 3


if __name__ == '__main__':
    sys.exit(main())
