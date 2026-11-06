// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { definitions } from '../../../cockpit/.tmp/compiled/generated/wire.js';
import { conforms } from '../../../cockpit/.tmp/compiled/src/schema.js';
import { capture } from '../fixture.mjs';

test('cockpit details reject malformed nested data and opaque references', () => {
  const valid = capture();
  assert.equal(conforms(valid, definitions.CockpitData, definitions), true);
  for (const mutate of [
    d => { d.details.version = 2; },
    d => { d.details.subscriptions[0].subscriptionRef = 'bad-reference'; },
    d => { delete d.details.sessions[0].lastObservedAt; },
    d => { d.details.sessions[0].sessionRef = 'bad-reference'; },
    d => { d.details.sessions[0].subscriptionRef = 'bad-reference'; },
    d => { delete d.details.subscriptions[0].credits.observedAt; },
    d => { d.details.subscriptions[0].resetCounts[0].count = 'bad'; },
  ]) {
    const data = structuredClone(valid);
    mutate(data);
    assert.equal(conforms(data, definitions.CockpitData, definitions), false);
  }
});

test('publication is optional but explicit null is rejected', () => {
  const data = capture();
  delete data.details.publication;
  assert.equal(conforms(data, definitions.CockpitData, definitions), true, 'absent');
  data.details.publication = null;
  assert.equal(conforms(data, definitions.CockpitData, definitions), false, 'null');
  data.details.publication = { contractVersion: 1, publicationId: '0123456789abcdef01234567', publishedAt: '2026-10-24T12:00:00Z', source: 'client', truncated: false, models: [] };
  assert.equal(conforms(data, definitions.CockpitData, definitions), true, 'valid');
});
