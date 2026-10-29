// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {createFieldBridge} from '../Sources/ModelPlanField/Web/field-bridge.mjs';

const generation = '11111111-1111-4111-8111-111111111111';
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const configuration = (revision = 'public-r1') => ({
  appearance: {theme:'night', locale:'en'},
  viewport: {width:800, height:500, scale:2, profile:'tall'},
  projection: {revision, models:[{id:'public-model', efforts:[{effort:'high', cost:0.5}]}]},
});
const command = (type, n, extra = {}) => ({version:1, generation, type, requestId:id(n), ...extra});
const turn = () => new Promise(resolve => setImmediate(resolve));
function setup(overrides = {}) {
  const events = [], applied = [], pauses = [], state = {disposed:0};
  const scene = {
    async apply(value, options) { applied.push([value, options]); },
    setPaused(value) { pauses.push(value); },
    async captureBarrier() {},
    dispose() { state.disposed++; },
    ...overrides,
  };
  const bridge = createFieldBridge({generation, post: value => events.push(JSON.parse(value)), scene});
  bridge.ready();
  return {bridge, events, applied, pauses, state};
}
async function configure(fixture, n = 1, value = configuration()) {
  assert.equal(fixture.bridge.receive(command('configure', n, {configuration:value, paused:false})), true);
  await turn();
}
function capture(fixture, n = 2, configurationId = 1) {
  const c = configuration();
  const captureKey = {generation, requestId:id(n), configurationId:id(configurationId),
    appearance:c.appearance, viewport:c.viewport, projectionRevision:c.projection.revision};
  return command('capture', n, {captureKey});
}

test('versioned ready/configure/settled/capture barrier, no pixel/base64 channel', async () => {
  const fixture = setup();
  fixture.bridge.ready();
  assert.equal(fixture.events.length, 1);
  await configure(fixture);
  assert.equal(fixture.events[1].type, 'settled');
  const request = capture(fixture);
  assert.equal(fixture.bridge.receive(request), true);
  assert.equal(fixture.bridge.receive(request), false);
  await turn();
  assert.equal(fixture.events[2].type, 'captureResult');
  assert.deepEqual(fixture.events[2].captureKey, request.captureKey);
  assert.equal(Object.hasOwn(fixture.events[2], 'png'), false);
  fixture.bridge.interaction('keyboard');
  fixture.bridge.interaction('heartbeat');
  assert.equal(fixture.events.filter(x => x.type === 'interaction').length, 1);
});

test('unknown/private fields, bad versions/generations/numbers and oversized input are rejected', async () => {
  const fixture = setup();
  const valid = command('configure', 1, {configuration:configuration(), paused:false});
  const cases = [
    {...valid, version:2}, {...valid, generation:id(5)}, {...valid, type:'snapshot'},
    {...valid, subscription:'private'},
    {...valid, configuration:{...configuration(), account:{id:'private'}}},
    {...valid, configuration:{...configuration(), viewport:{...configuration().viewport, scale:Infinity}}},
    {...valid, configuration:{...configuration(), projection:{...configuration().projection, sessions:[]}}},
    {...valid, configuration:{...configuration(), projection:{revision:'x'.repeat(1024*1024),models:[]}}},
  ];
  for (const value of cases) assert.equal(fixture.bridge.receive(value), false);
  assert.equal(fixture.applied.length, 0);
});

test('only one pending configuration is retained and pauses are immediate', async () => {
  let finish;
  const fixture = setup({apply: () => new Promise(resolve => { finish = resolve; })});
  assert.equal(fixture.bridge.receive(command('configure', 1, {configuration:configuration(), paused:false})), true);
  fixture.bridge.receive(command('setPublicProjection', 2, {configuration:configuration('r2'), paused:false}));
  fixture.bridge.receive(command('setAppearance', 3, {configuration:configuration('r3'), paused:true}));
  assert.equal(fixture.pauses.at(-1), true);
  finish(); await turn();
  assert.equal(fixture.events.at(-1).requestId, id(1));
  finish(); await turn();
  assert.deepEqual(fixture.events.filter(x => x.type === 'settled').map(x => x.requestId), [id(1), id(3)]);
});

test('hide/change/dispose during capture never publishes a late capture result', async () => {
  for (const reason of ['pause','projection','dispose']) {
    let finish;
    const fixture = setup({captureBarrier: () => new Promise(resolve => { finish = resolve; })});
    await configure(fixture);
    fixture.bridge.receive(capture(fixture));
    await turn();
    if (reason === 'dispose') fixture.bridge.receive(command('dispose', 3));
    else fixture.bridge.receive(command('setAppearance', 3, {
      configuration:configuration(reason === 'projection' ? 'r2' : 'public-r1'), paused:reason === 'pause'}));
    finish(); await turn();
    assert.equal(fixture.events.some(x => x.type === 'captureResult'), false);
  }
});

test('wrong configuration/theme/viewport/projection capture identities are rejected', async () => {
  const fixture = setup();
  await configure(fixture);
  for (const changed of [
    {configurationId:id(9)}, {appearance:{theme:'day',locale:'en'}},
    {viewport:{...configuration().viewport,scale:1}}, {projectionRevision:'r2'},
    {session:'private'},
  ]) {
    const request = capture(fixture);
    request.captureKey = {...request.captureKey, ...changed};
    assert.equal(fixture.bridge.receive(request), false);
  }
});

test('capture identity equality is independent of JSON object key order', async () => {
  const fixture = setup();
  await configure(fixture);
  const request = capture(fixture);
  request.captureKey.appearance = {locale:'en',theme:'night'};
  request.captureKey.viewport = {profile:'tall',scale:2,height:500,width:800};
  assert.equal(fixture.bridge.receive(request), true);
  await turn();
  assert.equal(fixture.events.at(-1).type, 'captureResult');
});

test('native close need not wait for renderer disposal or an outstanding apply', async () => {
  let finish, signal;
  const fixture = setup({
    apply: (_configuration, options) => { signal = options.signal; return new Promise(resolve => { finish = resolve; }); },
    dispose: () => new Promise(() => {}),
  });
  fixture.bridge.receive(command('configure', 1, {configuration:configuration(), paused:false}));
  assert.equal(fixture.bridge.receive(command('dispose', 2)), true);
  assert.equal(signal.aborted, true);
  assert.equal(fixture.bridge.receive(command('configure', 3, {configuration:configuration(), paused:false})), false);
  finish(); await turn();
  assert.equal(fixture.events.some(x => x.type === 'settled'), false);
});

test('renderer exceptions expose only bounded error codes', async () => {
  const fixture = setup({apply() { throw new Error('private exception/path'); }});
  await configure(fixture);
  assert.deepEqual(fixture.events.at(-1), {version:1,generation,type:'error',code:'render'});
  assert.equal(JSON.stringify(fixture.events).includes('private'), false);
});

test('visibility overrides during an unfinished apply do not queue another apply', async () => {
  let finish, applications = 0;
  const fixture = setup({apply: () => {
    applications++;
    return applications === 1 ? new Promise(resolve => { finish = resolve; }) : Promise.resolve();
  }});
  fixture.bridge.receive(command('configure', 1, {configuration:configuration(), paused:false}));
  fixture.bridge.receive(command('setAppearance', 1, {configuration:configuration(), paused:true}));
  assert.equal(fixture.pauses.at(-1), true);
  fixture.bridge.receive(command('setAppearance', 1, {configuration:configuration(), paused:false}));
  assert.equal(fixture.pauses.at(-1), false);
  finish(); await turn();
  assert.equal(applications, 1);
  assert.equal(fixture.events.filter(event => event.type === 'settled').length, 1);
  assert.equal(fixture.bridge.receive(capture(fixture)), true);
  await turn();
  assert.equal(fixture.events.at(-1).type, 'captureResult');
});

test('availability tuple preserves false and unknown without defaulting true', async () => {
  const fixture = setup();
  const value = configuration();
  value.projection.models[0].efforts[0].available = false;
  await configure(fixture, 1, value);
  assert.equal(fixture.applied[0][0].projection.models[0].efforts[0].available, false);
  const unknown = configuration(); unknown.projection.models[0].efforts[0].available = null;
  await configure(fixture, 2, unknown);
  assert.equal(fixture.applied[1][0].projection.models[0].efforts[0].available, null);
  const malformed = configuration(); malformed.projection.models[0].efforts[0].available = 'yes';
  assert.equal(fixture.bridge.receive(command('configure', 3, {configuration: malformed, paused: false})), false);
});
