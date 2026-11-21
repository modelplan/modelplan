import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {encodePublicJSON, publicContentHash, verifyClientDigest} from '../public-reader.mjs';

// A real client-v1.6 projection from the production producer, trimmed to the Anthropic and OpenAI rows.
const example = readFileSync(new URL('../../testdata/client-v1.6/example.json', import.meta.url), 'utf8');
const timestamp = '2026-11-19T00:00:00Z';

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
    ...identity, publicationId: (await publicContentHash(encodePublicJSON(identity))).slice(0, 24), publishedAt: timestamp,
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
const model = (d, id) => d.models.find(m => m.id === id);
const pendingId = 'astra-6.2';

test('the production client-v1.6 example verifies and stays under the client raw cap', async () => {
  const value = await publication();
  await verifyClientDigest(value);
  const d = value.component.data;
  assert.equal(d.projectionVersion, 'client-v1.6');
  assert.equal(d.priceUnit, 'usd-per-1m-tokens');
  assert.deepEqual(model(d, pendingId).efforts, []);
  assert.equal(model(d, pendingId).recommended, null);
  assert.equal(value.manifest.components.client.bytes <= 250_000, true);
});

test('below client-v1.6 every v1.6 field is rejected', async () => {
  const older = d => { d.projectionVersion = 'client-v1.5'; };
  const strip = d => {
    older(d);
    delete d.priceUnit; delete d.usageTrend;
    for (const m of d.models) { delete m.small; delete m.price; delete m.evaluation; }
    for (const t of d.speedTiers) delete t.apiPriceMultiplier;
  };
  await verifyClientDigest(await publication(strip));
  const cases = {
    priceUnit: d => { d.priceUnit = 'usd-per-1m-tokens'; d.models[0].price = JSON.parse(example).models[0].price; },
    usageTrend: d => { d.usageTrend = {source: 'openrouter-paid-daily', asOf: '2026-11-18', days: 1, ranks: {}}; },
    small: d => { d.models[0].small = false; },
    price: d => { d.priceUnit = 'usd-per-1m-tokens'; d.models[0].price = JSON.parse(example).models[0].price; },
    evaluation: d => { d.models[0].evaluation = 'pending'; },
    apiPriceMultiplier: d => { d.speedTiers[0].apiPriceMultiplier = 2; },
  };
  for (const [field, add] of Object.entries(cases))
    await rejects(d => { strip(d); add(d); }, 'invalid_client_v16_projection').catch(e => { throw Error(`${field}: ${e.message}`); });
});

test('priceUnit is present exactly when some model has a price', async () => {
  await rejects(d => { delete d.priceUnit; }, 'invalid_client_price_unit');
  await rejects(d => { for (const m of d.models) delete m.price; }, 'invalid_client_price_unit');
  const value = await publication(d => { delete d.priceUnit; for (const m of d.models) delete m.price; });
  await verifyClientDigest(value);
});

test('model prices are strict: positive input and output, non-null cache rates, known source, calendar asOf', async () => {
  const id = 'opus';
  for (const edit of [
    p => { p.input = 0; }, p => { p.output = -1; }, p => { p.cacheRead = null; }, p => { p.cacheWrite = -0.1; },
    p => { p.source = 'openrouter'; }, p => { p.asOf = '2026-11-19T00:00:00Z'; }, p => { p.asOf = '2026-02-30'; },
    p => { p.extra = 1; }, p => { p.longContext = {aboveInputTokens: 0, input: 1, output: 1}; },
    p => { p.longContext = {aboveInputTokens: 1.5, input: 1, output: 1}; },
    p => { p.longContext = {aboveInputTokens: 200000, input: 1, output: 1, cacheRead: null}; },
  ]) await assert.rejects(async () => verifyClientDigest(await publication(d => edit(model(d, id).price))));
  await verifyClientDigest(await publication(d => { delete model(d, id).price.cacheRead; delete model(d, id).price.cacheWrite; }));
});

test('usageTrend keys are published models, every array covers the days, and it fits 8192 bytes', async () => {
  await rejects(d => { d.usageTrend.ranks['not-a-model'] = Array(d.usageTrend.days).fill(null); }, 'invalid_client_usage_trend');
  await rejects(d => { d.usageTrend.ranks[Object.keys(d.usageTrend.ranks)[0]].pop(); }, 'invalid_client_usage_trend');
  await rejects(d => {
    d.usageTrend.days = 90;
    for (const m of d.models) d.usageTrend.ranks[m.id] = Array(90).fill(1000000);
  }, 'invalid_client_usage_trend');
  for (const edit of [
    t => { t.days = 0; }, t => { t.days = 91; }, t => { t.source = 'openrouter'; }, t => { t.asOf = '18 Nov 2026'; },
    t => { t.ranks[Object.keys(t.ranks)[0]][0] = 0; }, t => { t.extra = true; },
  ]) await assert.rejects(async () => verifyClientDigest(await publication(d => edit(d.usageTrend))));
});

test('pending rows carry no efforts, no recommendation and no lineup place', async () => {
  const opus = JSON.parse(example).models.find(m => m.id === 'opus');
  for (const edit of [
    m => { m.efforts = opus.efforts; },
    m => { m.efforts = opus.efforts; m.recommended = opus.recommended; },
    m => { m.recommendationBasis = 'balanced'; },
    m => { delete m.recommendationBasis; },
    m => { m.defaultSelected = true; },
  ]) await rejects(d => edit(model(d, pendingId)), 'invalid_client_pending_model');
  const inLineup = member => d => {
    const l = d.lineups.find(x => x.developerId === 'openai');
    l.members.push({id: pendingId, status: 'incomplete', tags: [], dominatedBy: null});
    if (member === 'frontier') l.frontier.push(pendingId);
    if (member === 'baseline') l.baseline = pendingId;
  };
  for (const where of ['members', 'frontier', 'baseline']) await rejects(inLineup(where), 'invalid_client_pending_model');
});

test('a speed tier apiPriceMultiplier is a finite number above 1', async () => {
  for (const v of [1, 0.5, 0, '2', null]) await assert.rejects(async () => verifyClientDigest(await publication(d => { d.speedTiers[0].apiPriceMultiplier = v; })));
  await verifyClientDigest(await publication(d => { d.speedTiers[0].apiPriceMultiplier = 1.5; }));
});

test('the strict reader rejects a null longContext and a pending row without a present empty efforts array', async () => {
  await assert.rejects(async () => verifyClientDigest(await publication(d => { model(d, 'astra').price.longContext = null; })));
  await assert.rejects(async () => verifyClientDigest(await publication(d => { delete model(d, pendingId).efforts; })));
  await assert.rejects(async () => verifyClientDigest(await publication(d => { model(d, pendingId).efforts = null; })));
  await verifyClientDigest(await publication(d => { model(d, pendingId).efforts = []; }));
});
