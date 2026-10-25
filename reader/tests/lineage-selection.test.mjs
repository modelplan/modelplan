import test from 'node:test';
import assert from 'node:assert/strict';
import {ClientDataReader, encodePublicJSON, publicContentHash, verifyClientDigest} from '../public-reader.mjs';

const timestamp = '2026-10-25T00:00:00Z';
const selection = {
  lineageId: 'synthetic:line', lineageStatus: 'current', defaultSelected: true,
};
// Entirely synthetic publication. Dependency objects need not be downloaded by a thin reader.
async function publication(edit = () => {}) {
  const components = Object.fromEntries(await Promise.all(
    ['methods', 'registry', 'models', 'plans', 'rules', 'news', 'calendar'].map(async kind => [
      kind, {schemaVersion: 1, hash: await publicContentHash(encodePublicJSON({synthetic: kind})), bytes: 2},
    ]),
  ));
  const component = {
    schemaVersion: 1, kind: 'client', evidence: [],
    dependencies: Object.fromEntries(['models', 'registry', 'rules', 'calendar'].map(kind => [kind, components[kind].hash])),
    data: {
      units: {ability: 'websiteAbility', cost: 'usdPerReferenceTask', time: 'taskTimeCrossModel'},
      builtAt: timestamp, aliasRevision: 'synthetic-aliases-v1',
      developers: [{id: 'synthetic', name: 'Synthetic', color: '#888888', region: null}],
      models: [{
        id: 'synthetic-current', name: 'Synthetic Current', developerId: 'synthetic',
        current: true, recommended: null,
        harnessIds: {api: [], 'claude-code': [], codex: []}, harnessEvidence: null, efforts: [],
      }],
      lineups: [], resets: [], windows: [],
    },
  };
  edit(component);
  const bytes = encodePublicJSON(component);
  components.client = {schemaVersion: 1, hash: await publicContentHash(bytes), bytes: bytes.length};
  const identity = {
    schemaVersion: 1, comparisonVersion: 'synthetic-comparison-v1',
    methods: {index: 'unified-v03-estimator-0.1.0-internal', recommendation: 'balanced-coding-absolute-v4'},
    components,
  };
  const manifest = {
    ...identity, publicationId: (await publicContentHash(encodePublicJSON(identity))).slice(0, 24), publishedAt: timestamp,
  };
  return {manifest, component};
}

test('optional selection fields preserve historical, null and partial publications', async () => {
  for (const fields of [{}, {lineageId: null, lineageStatus: null, defaultSelected: null}, {lineageId: 'synthetic:line'}, {defaultSelected: false}]) {
    const value = await publication(c => Object.assign(c.data.models[0], fields));
    await verifyClientDigest(value);
    assert.deepEqual(Object.fromEntries(Object.keys(fields).map(key => [key, value.component.data.models[0][key]])), fields);
    assert.equal('selectionRevision' in value.component.data, false);
  }
});

test('thin reader accepts each published lineage status and preserves the values verbatim', async () => {
  const value = await publication(c => {
    c.data.selectionRevision = 'synthetic-registry-v1';
    c.data.models = ['current', 'older', 'preview', 'retired'].map((status, i) => ({
      ...c.data.models[0], id: `synthetic-${status}`, name: `Synthetic ${status}`,
      ...selection, lineageStatus: status, defaultSelected: i === 0,
    }));
  });
  const paths = [];
  const mb = encodePublicJSON(value.manifest);
  const fetcher = async input => {
    const path = new URL(input).pathname;
    paths.push(path);
    if (path.endsWith('/current.json')) return new Response(JSON.stringify({
      schemaVersion: 1, publicationId: value.manifest.publicationId, manifestHash: await publicContentHash(mb),
    }));
    if (path.endsWith('/manifest.json')) return new Response(mb);
    if (path === `/publications/objects/${value.manifest.components.client.hash}.json`) return new Response(encodePublicJSON(value.component));
    throw Error(`Unexpected dependency download: ${path}`);
  };
  const result = await new ClientDataReader({baseUrl: 'https://example.test/', fetcher}).refresh();
  assert.equal(result.state, 'current', result.errorCode);
  assert.deepEqual(result.digest.component.data, value.component.data);
  assert.equal(paths.length, 3);
});

test('selection fields validate types and enum without relaxing strict model validation', async () => {
  for (const fields of [
    {lineageId: ''}, {lineageId: 4}, {lineageStatus: 'newest'}, {lineageStatus: false},
    {defaultSelected: 'true'}, {defaultSelected: 1}, {unreviewedField: true},
  ]) {
    const value = await publication(c => Object.assign(c.data.models[0], fields));
    await assert.rejects(verifyClientDigest(value), /publication_invalid_data_client/);
  }
  for (const revision of ['', 42, null]) {
    const value = await publication(c => { c.data.selectionRevision = revision; });
    await assert.rejects(verifyClientDigest(value), /publication_invalid_data_client/);
  }
});

test('selection additions retain content-hash and dependency verification', async () => {
  const value = await publication(c => Object.assign(c.data.models[0], selection));
  await verifyClientDigest(value);
  value.component.data.models[0].defaultSelected = false;
  await assert.rejects(verifyClientDigest(value), /publication_client_hash_mismatch/);
  const dependency = await publication(c => { c.dependencies.registry = '0'.repeat(64); });
  await assert.rejects(verifyClientDigest(dependency), /publication_dependency_mismatch/);
});
