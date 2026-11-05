// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { definitions } from '../../../cockpit/.tmp/compiled/generated/wire.js';
import { conforms } from '../../../cockpit/.tmp/compiled/src/schema.js';

test('cockpit query threshold follows the generated committed-setting choices', () => {
  for (const value of [undefined, 10, 15, 20, 25, 30, 40]) {
    const params = value === undefined ? {} : {redBelow: value};
    assert.equal(conforms(params, definitions.CockpitQueryParams, definitions), true);
  }
  for (const value of [null, 0, 16, 17, 26, 41, '15']) {
    assert.equal(conforms({redBelow: value}, definitions.CockpitQueryParams, definitions), false);
  }
});
