import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {encodePublicJSON, publicContentHash, verifyClientDigest} from '../public-reader.mjs';

// client-v1.7 (modelplans #781, design A'): efforts[].ability becomes the cross-model abilityIndex and every effort
// also carries abilityWithinModel, the within-model chain that step differences read. Built from the v1.6 example.
const example = readFileSync(new URL('../../testdata/client-v1.6/example.json', import.meta.url), 'utf8');

async function publication(edit = () => {}) {
  const components = Object.fromEntries(await Promise.all(
    ['methods', 'registry', 'models', 'plans', 'rules', 'news', 'calendar'].map(async kind => [
      kind, {schemaVersion: 1, hash: await publicContentHash(encodePublicJSON({synthetic: kind})), bytes: 2},
    ]),
  ));
  const component = {
    schemaVersion: 1, kind: 'client', evidence: [],
    dependencies: Object.fromEntries(['models', 'registry', 'rules', 'calendar'].map(kind => [kind, components[kind].hash])),
    data: JSON.parse(example),
  };
  edit(component.data);
  const bytes = encodePublicJSON(component);
  components.client = {schemaVersion: 1, hash: await publicContentHash(bytes), bytes: bytes.length};
  const identity = {
    schemaVersion: 1, comparisonVersion: 'synthetic-comparison-v1',
    methods: {index: 'unified-v03-estimator-0.1.0-internal', recommendation: 'balanced-coding-absolute-v4'},
    components,
  };
  const manifest = {
    ...identity, publicationId: (await publicContentHash(encodePublicJSON(identity))).slice(0, 24), publishedAt: '2026-11-21T00:00:00Z',
  };
  return {manifest, component};
}
const rejects = async (edit, code) => {
  const value = await publication(edit);
  await assert.rejects(() => verifyClientDigest(value), error => {
    assert.ok(error.validationIssues?.some(issue => issue.message === code), JSON.stringify(error.validationIssues ?? error.message));
    return true;
  });
};
const efforts = d => d.models.flatMap(m => m.efforts);
// The v1.6 ability was the chain: keep it as abilityWithinModel and publish a cross-model value as ability.
const v17 = d => {
  d.projectionVersion = 'client-v1.7';
  for (const e of efforts(d)) {
    e.abilityWithinModel = e.abilityBasis === 'abilityWithinModel' ? e.ability : null;
    if (e.abilityBasis === 'abilityWithinModel') {
      e.abilityBasis = 'abilityIndex';
      if (e.ability !== null) e.ability += 0.5;
    }
  }
};

test('a client-v1.7 digest verifies with abilityIndex abilities and the chain on every effort', async () => {
  const value = await publication(v17);
  await verifyClientDigest(value);
  const d = value.component.data;
  assert.ok(efforts(d).length > 0 && efforts(d).every(e => e.abilityWithinModel !== undefined));
  assert.ok(efforts(d).some(e => e.abilityBasis === 'abilityIndex'));
  // A missing bridge is null, not absent.
  await verifyClientDigest(await publication(d => { v17(d); efforts(d)[0].abilityWithinModel = null; }));
});

test('below client-v1.7 neither the abilityIndex basis nor the chain field is accepted', async () => {
  await verifyClientDigest(await publication());
  await rejects(d => { efforts(d)[0].abilityBasis = 'abilityIndex'; }, 'invalid_client_v17_projection');
  await rejects(d => { efforts(d)[0].abilityWithinModel = efforts(d)[0].ability; }, 'invalid_client_v17_projection');
});

test('from client-v1.7 every effort carries the chain and none is on the chain basis', async () => {
  await rejects(d => { v17(d); delete efforts(d)[0].abilityWithinModel; }, 'invalid_client_v17_projection');
  await rejects(d => { v17(d); efforts(d)[0].abilityBasis = 'abilityWithinModel'; }, 'invalid_client_v17_projection');
  for (const v of ['1', Number.NaN, true])
    await assert.rejects(async () => verifyClientDigest(await publication(d => { v17(d); efforts(d)[0].abilityWithinModel = v; })));
  await assert.rejects(async () => verifyClientDigest(await publication(d => { v17(d); efforts(d)[0].abilityBasis = 'chain'; })));
});
