# SPDX-License-Identifier: MIT
"""Synthetic approved-run/artifact negative controls; no network or signing."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('credential_fetch_test', Path(__file__).with_name('fetch_credential_artifact.py'))
fetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)


class FakeGitHub:
    def __init__(self, archive):
        self.archive = archive
        self.calls = []
        self.downloads = []
        self.run = {'id': 12345, 'repository': {'full_name': 'modelplan/modelplan'},
                    'head_repository': {'full_name': 'modelplan/modelplan'}, 'head_branch': 'main',
                    'head_sha': 'a' * 40, 'event': 'push', 'status': 'completed', 'conclusion': 'success'}
        self.artifacts = {'total_count': 1, 'artifacts': [
            {'id': 77, 'name': 'approved-u7', 'expired': False, 'size_in_bytes': len(archive),
             'workflow_run': {'id': 12345}}]}

    def api(self, route):
        self.calls.append(route)
        if route == 'repos/modelplan/modelplan/actions/runs/12345':
            return copy.deepcopy(self.run)
        if route == 'repos/modelplan/modelplan/actions/runs/12345/artifacts?per_page=100':
            return copy.deepcopy(self.artifacts)
        raise AssertionError('unexpected or unpinned API request')

    def download(self, route, path):
        if route != 'repos/modelplan/modelplan/actions/artifacts/77/zip':
            raise AssertionError('wrong run-bound artifact')
        self.downloads.append(route)
        path.write_bytes(self.archive)


class CredentialArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.binary = b'synthetic fixed denial helper, not executable'
        self.sha = hashlib.sha256(self.binary).hexdigest()
        self.pin = self.root / 'approved.json'
        self.pin.write_text(json.dumps({'runID': '12345', 'artifactName': 'approved-u7', 'sha256': self.sha}))

    def archive(self, *, binary=None, descriptor=None, extra=(), omit=()):
        binary = self.binary if binary is None else binary
        descriptor = descriptor or {'schemaVersion': 1, 'sha256': self.sha, 'bytes': len(binary),
                                    'inputSHA256': 'b' * 64, 'bundleIdentifier': 'ai.modelplan.credential-agent'}
        content = {'modelplan-credential-agent': binary, 'credential-agent.json': json.dumps(descriptor).encode(),
                   'proof.json': b'{"synthetic":true}', 'SHA256SUMS': b'synthetic audit checksums',
                   'LICENSE.txt': b'Synthetic MIT fixture'}
        output = io.BytesIO()
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(output, 'w') as file:
                for name, data in content.items():
                    if name not in omit:
                        file.writestr(name, data)
                for name, data in extra:
                    file.writestr(name, data)
        return output.getvalue()

    def acquire(self, github, name='download'):
        return fetch.acquire(self.root / name, pin_path=self.pin, github=github)

    def test_exact_approved_main_run_and_artifact_are_bound(self):
        github = FakeGitHub(self.archive())
        result = self.acquire(github)
        self.assertEqual(result['approval']['runID'], '12345')
        self.assertEqual(result['approval']['artifactName'], 'approved-u7')
        self.assertEqual(result['environment']['MODELPLAN_CREDENTIAL_AGENT_SHA256'], self.sha)
        binary = Path(result['environment']['MODELPLAN_CREDENTIAL_AGENT_ARTIFACT']) / 'modelplan-credential-agent'
        self.assertEqual(binary.read_bytes(), self.binary)
        self.assertEqual(len(github.downloads), 1)

    def test_missing_approval_never_queries_or_downloads(self):
        self.pin.unlink()
        github = FakeGitHub(self.archive())
        with self.assertRaises(fetch.FetchFailure):
            self.acquire(github)
        self.assertEqual(github.calls, [])

    def test_duplicate_approval_fields_are_not_ambiguous_authority(self):
        self.pin.write_text('{"runID":"12345","runID":"99999","artifactName":"approved-u7","sha256":"' + self.sha + '"}')
        github = FakeGitHub(self.archive())
        with self.assertRaises(fetch.FetchFailure):
            self.acquire(github)
        self.assertEqual(github.calls, [])

    def test_metadata_client_pins_github_origin_despite_host_override(self):
        route = 'repos/modelplan/modelplan/actions/runs/12345'
        with patch.dict(os.environ, {'GH_HOST': 'unrelated.invalid'}), \
             patch.object(fetch.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, b'{}')) as command:
            fetch.GitHub().api(route)
        self.assertEqual(command.call_args.args[0], ['gh', 'api', '--hostname', 'github.com', route])

    def test_invalid_triples_never_query(self):
        original = json.loads(self.pin.read_text())
        for key, value in [('runID', 'latest'), ('runID', '012345'), ('artifactName', '*'), ('sha256', 'bad')]:
            self.pin.write_text(json.dumps({**original, key: value}))
            github = FakeGitHub(self.archive())
            with self.subTest(key=key, value=value), self.assertRaises(fetch.FetchFailure):
                self.acquire(github)
            self.assertEqual(github.calls, [])

    def test_fork_branch_failure_and_pr_producers_are_rejected(self):
        for index, change in enumerate([{'head_repository': {'full_name': 'someone/fork'}},
                {'head_branch': 'feature'}, {'event': 'pull_request'}, {'conclusion': 'failure'},
                {'status': 'in_progress'}, {'id': 999}, {'head_sha': 'bad'}]):
            github = FakeGitHub(self.archive()); github.run.update(change)
            with self.subTest(change=change), self.assertRaises(fetch.FetchFailure):
                self.acquire(github, 'bad-run-' + str(index))
            self.assertEqual(github.downloads, [])

    def test_missing_ambiguous_expired_and_wrong_run_artifacts_fail(self):
        for index, mutation in enumerate(['missing', 'duplicate', 'expired', 'other-run']):
            github = FakeGitHub(self.archive())
            if mutation == 'missing': github.artifacts['artifacts'] = []
            if mutation == 'duplicate': github.artifacts['artifacts'] *= 2
            if mutation == 'expired': github.artifacts['artifacts'][0]['expired'] = True
            if mutation == 'other-run': github.artifacts['artifacts'][0]['workflow_run']['id'] = 999
            with self.subTest(mutation=mutation), self.assertRaises(fetch.FetchFailure):
                self.acquire(github, 'bad-artifact-' + str(index))
            self.assertEqual(github.downloads, [])

    def test_artifact_cannot_approve_its_own_modified_binary(self):
        changed = b'modified artifact'
        own_pin = {'sha256': hashlib.sha256(changed).hexdigest(), 'bytes': len(changed)}
        with self.assertRaisesRegex(fetch.FetchFailure, 'independent-helper-pin-mismatch'):
            self.acquire(FakeGitHub(self.archive(binary=changed, descriptor=own_pin)))

    def test_descriptor_must_match_independent_digest(self):
        with self.assertRaises(fetch.FetchFailure):
            self.acquire(FakeGitHub(self.archive(descriptor={'sha256': '0' * 64, 'bytes': len(self.binary)})))

    def test_traversal_symlink_and_duplicate_members_are_rejected(self):
        link = zipfile.ZipInfo('linked')
        link.create_system = 3; link.external_attr = 0o120777 << 16
        for index, extra in enumerate([[('../escape', b'bad')], [(link, b'target')], [('modelplan-credential-agent', b'duplicate')]]):
            with self.subTest(index=index), self.assertRaises(fetch.FetchFailure):
                self.acquire(FakeGitHub(self.archive(extra=extra)), 'unsafe-' + str(index))
        self.assertFalse((self.root / 'escape').exists())

    def test_missing_required_file_and_existing_output_fail(self):
        with self.assertRaises(fetch.FetchFailure):
            self.acquire(FakeGitHub(self.archive(omit=['credential-agent.json'])), 'missing')
        (self.root / 'existing').mkdir()
        github = FakeGitHub(self.archive())
        with self.assertRaises(fetch.FetchFailure):
            self.acquire(github, 'existing')
        self.assertEqual(github.downloads, [])

    def test_cli_exports_only_verified_binding(self):
        env = self.root / 'github-env'
        args = ['fetch', '--pin', str(self.pin), '--output', str(self.root / 'cli'), '--github-env', str(env)]
        with patch.object(sys, 'argv', args), patch.object(fetch, 'GitHub', return_value=FakeGitHub(self.archive())), contextlib.redirect_stdout(io.StringIO()):
            fetch.main()
        text = env.read_text()
        self.assertIn('MODELPLAN_CREDENTIAL_AGENT_SHA256=' + self.sha, text)
        self.assertIn('MODELPLAN_CREDENTIAL_AGENT_ARTIFACT=', text)
        self.assertEqual(len(text.splitlines()), 2)


if __name__ == '__main__':
    unittest.main()
