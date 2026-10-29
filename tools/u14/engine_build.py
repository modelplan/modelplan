# SPDX-License-Identifier: MIT
"""Build ordinary CLI and constructor-only fixture overlay; record identities."""
from pathlib import Path
import subprocess

from contracts import digest, encoded, write_private
from candidate import git, regular_bytes
from engine_process import build_binary, EngineFailure

CONSTRUCTOR = 'newAppServer(ctx, options)'
REPLACEMENT = 'u14ProviderServer(ctx, options)'


def build_tools(repo, destination):
    repo, destination = Path(repo).absolute(), Path(destination).absolute()
    source = repo / 'cli/cmd/modelplan/app_server.go'
    original = regular_bytes(source)
    if original.count(CONSTRUCTOR.encode()) != 1:
        raise EngineFailure('constructor-contract-changed')
    patched = original.replace(CONSTRUCTOR.encode(), REPLACEMENT.encode(), 1)
    factory = regular_bytes(repo / 'tools/u14/fixture_constructor.go.txt')
    adapter_path = destination / 'fixture_adapter.go'
    constructor_path = destination / 'fixture_constructor.go'
    write_private(adapter_path, patched)
    write_private(constructor_path, factory)
    overlay = {'Replace': {str(source): str(adapter_path),
                          str(repo / 'cli/cmd/modelplan/u14_fixture_constructor.go'): str(constructor_path)}}
    quota_source = repo / 'cli/internal/quota/quota_native.go'
    quota_original = regular_bytes(quota_source)
    client = b'var nativeClient = &http.Client{Timeout: nativeTimeout}'
    if quota_original.count(client) != 1:
        raise EngineFailure('http-provider-constructor-changed')
    quota_patched = quota_original.replace(client, b'var nativeClient = u14HTTPClient()', 1)
    http_factory = regular_bytes(repo / 'tools/u14/recording_http.go.txt')
    quota_path, http_path = destination / 'quota_provider.go', destination / 'http_provider.go'
    write_private(quota_path, quota_patched)
    write_private(http_path, http_factory)
    overlay['Replace'].update({str(quota_source): str(quota_path),
                               str(repo / 'cli/internal/quota/u14_http_provider.go'): str(http_path)})
    overlay_path = destination / 'go-overlay.json'
    write_private(overlay_path, encoded(overlay))
    plain, fixture, validator = [destination / name for name in ('modelplan', 'modelplan-fixture', 'validate-wire')]
    build_binary(repo, plain)
    build_binary(repo, fixture, overlay_path)
    result = subprocess.run(['go', 'build', '-trimpath', '-o', str(validator), './internal/u14fixture/cmd/validate'],
                            cwd=repo / 'cli', capture_output=True, timeout=180)
    if result.returncode:
        raise EngineFailure('validator-build-failed')
    deps = subprocess.run(['go', 'list', '-deps', './cmd/modelplan'], cwd=repo / 'cli',
                          capture_output=True, timeout=60)
    if deps.returncode or b'/internal/u14fixture' in deps.stdout:
        raise EngineFailure('fixture-linked-in-ordinary-build')
    plan = {'format': 'u14-constructor-overlay-v1', 'replacements': [
        {'path': 'cli/cmd/modelplan/app_server.go', 'sha256': digest(patched)},
        {'path': 'cli/cmd/modelplan/u14_fixture_constructor.go', 'sha256': digest(factory)},
        {'path': 'cli/internal/quota/quota_native.go', 'sha256': digest(quota_patched)},
        {'path': 'cli/internal/quota/u14_http_provider.go', 'sha256': digest(http_factory)}]}
    metadata = {'schemaVersion': 1, 'sourceSha': git(repo, 'rev-parse', 'HEAD'),
                'proofScope': 'production shared backend; recording providers and admission-churn fault',
                'overlay': plan, 'overlaySha256': digest(encoded(plan)),
                'goOverlaySha256': digest(regular_bytes(overlay_path)),
                'originalAdapterSha256': digest(original),
                'originalConstructorSha256': digest(CONSTRUCTOR.encode()),
                'originalQuotaProviderSha256': digest(quota_original),
                'fixtureConstructorSha256': digest(factory),
                'plainBinarySha256': digest(regular_bytes(plain)),
                'fixtureBinarySha256': digest(regular_bytes(fixture)),
                'validatorBinarySha256': digest(regular_bytes(validator)),
                'ordinaryBuildLinksFixture': False, 'timeoutPolicy': 'production defaults',
                'usesProductionConsentBackend': True, 'finalPackageProof': False}
    return {'plain': plain, 'fixture': fixture, 'validator': validator, 'metadata': metadata}
