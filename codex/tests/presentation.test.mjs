import test from 'node:test';
import assert from 'node:assert/strict';
import { requestPanelMode } from '../ui/presentation.js';

test('expand and return use the host display-mode protocol, without changing comparison data', async () => {
  const context = Object.freeze({ displayMode: 'inline', availableDisplayModes: ['inline', 'fullscreen'] });
  let call;
  const result = await requestPanelMode(async (method, params) => { call = { method, params }; return { mode: params.mode }; }, context);
  assert.deepEqual(call, { method: 'ui/request-display-mode', params: { mode: 'fullscreen' } });
  assert.deepEqual(result, { status: 'changed', mode: 'fullscreen' });
  assert.equal(context.displayMode, 'inline');
  assert.deepEqual(await requestPanelMode(async (_method, params) => ({ mode: params.mode }), { displayMode: result.mode }), { status: 'changed', mode: 'inline' });
});

test('unsupported, refused and failed host requests never claim a panel was opened', async () => {
  assert.deepEqual(await requestPanelMode(() => { throw Error('must not call'); }, { availableDisplayModes: ['inline'] }), { status: 'unsupported', mode: 'inline' });
  assert.deepEqual(await requestPanelMode(async () => ({ mode: 'inline' })), { status: 'unsupported', mode: 'inline' });
  await assert.rejects(requestPanelMode(async () => { throw Error('Host refused'); }), /Host refused/);
  await assert.rejects(requestPanelMode(async () => ({})), /Invalid host display mode/);
});
