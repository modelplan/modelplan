# SPDX-License-Identifier: MIT
"""Build production constructors with narrowly scoped provider/fault overlays."""
from pathlib import Path
import subprocess

from contracts import digest, encoded, write_private
from candidate import git, regular_bytes
from engine_process import build_binary, EngineFailure

CONSTRUCTOR = 'newAppServer(ctx, options)'
REPLACEMENT = 'u14ProviderServer(ctx, options)'


def build_tools(repo, destination):
    repo, destination = Path(repo).absolute(), Path(destination).absolute()
    source_sha = git(repo, 'rev-parse', 'HEAD')
    source = repo / 'cli/cmd/modelplan/app_server.go'
    original = regular_bytes(source)
    if original.count(CONSTRUCTOR.encode()) != 1:
        raise EngineFailure('constructor-contract-changed')
    patched = original.replace(CONSTRUCTOR.encode(), REPLACEMENT.encode(), 1)
    factory = regular_bytes(repo / 'tools/u14/fixture_constructor.go.txt')
    adapter_path, constructor_path = destination / 'fixture_adapter.go', destination / 'fixture_constructor.go'
    write_private(adapter_path, patched)
    write_private(constructor_path, factory)
    history = {source: (adapter_path, patched),
               repo / 'cli/cmd/modelplan/u14_fixture_constructor.go': (constructor_path, factory)}

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
    providers = {quota_source: (quota_path, quota_patched),
                 repo / 'cli/internal/quota/u14_http_provider.go': (http_path, http_factory)}

    binaries, identities = {}, {}
    for role, name, replacements in (
        ('plain', 'modelplan', {}),
        ('providers', 'modelplan-providers', providers),
        ('fixture', 'modelplan-fixture', history),
    ):
        mapping = {'Replace': {str(path): str(value[0]) for path, value in replacements.items()}}
        overlay_path = None
        if replacements:
            overlay_path = destination / (role + '-overlay.json')
            write_private(overlay_path, encoded(mapping))
        binary = destination / name
        build_binary(repo, binary, overlay_path)
        args = ['go', 'list', '-deps']
        if overlay_path:
            args += ['-overlay', str(overlay_path)]
        deps = subprocess.run([*args, './cmd/modelplan'], cwd=repo / 'cli',
                              capture_output=True, timeout=60)
        links_fixture = b'/internal/u14fixture' in deps.stdout
        if deps.returncode or links_fixture != (role == 'fixture'):
            raise EngineFailure('unexpected-fixture-dependency-' + role)
        plan = {'format': 'u14-provider-overlay-v2', 'replacements': [
            {'path': path.relative_to(repo).as_posix(), 'sha256': digest(value[1])}
            for path, value in sorted(replacements.items())]}
        identities[role] = {
            'sha256': digest(regular_bytes(binary)), 'constructorChanged': role == 'fixture',
            'constructorCallSha256': digest((REPLACEMENT if role == 'fixture' else CONSTRUCTOR).encode()),
            'adapterSha256': digest(patched if role == 'fixture' else original),
            'linksHistoryFixture': links_fixture, 'usesProductionConsentBackend': True,
            'overlay': plan, 'overlaySha256': digest(encoded(plan)),
            'goOverlaySha256': digest(encoded(mapping)) if replacements else None,
        }
        binaries[role] = binary

    validator = destination / 'validate-wire'
    result = subprocess.run(['go', 'build', '-trimpath', '-o', str(validator), './internal/u14fixture/cmd/validate'],
                            cwd=repo / 'cli', capture_output=True, timeout=180)
    if result.returncode:
        raise EngineFailure('validator-build-failed')
    if git(repo, 'rev-parse', 'HEAD') != source_sha:
        raise EngineFailure('source-changed-during-build')
    metadata = {
        'schemaVersion': 2, 'sourceSha': source_sha, 'binaries': identities,
        'proofScope': 'production shared backend; provider-only admission and labeled history/fault cases',
        'originalAdapterSha256': digest(original), 'originalConstructorSha256': digest(CONSTRUCTOR.encode()),
        'originalQuotaProviderSha256': digest(quota_original), 'fixtureConstructorSha256': digest(factory),
        'productionReaderClientSha256': digest(regular_bytes(repo / 'cli/internal/quota/reader_client.go')),
        'productionReadTransportSha256': digest(regular_bytes(repo / 'cli/internal/readers/transport.go')),
        'plainBinarySha256': identities['plain']['sha256'],
        'fixtureBinarySha256': identities['fixture']['sha256'],
        'providerOnlyBinarySha256': identities['providers']['sha256'],
        'validatorBinarySha256': digest(regular_bytes(validator)),
        'ordinaryBuildLinksFixture': False, 'timeoutPolicy': 'production defaults',
        'usesProductionConsentBackend': True, 'finalPackageProof': False,
    }
    return {**binaries, 'validator': validator, 'metadata': metadata}
