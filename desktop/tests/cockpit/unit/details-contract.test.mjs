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
