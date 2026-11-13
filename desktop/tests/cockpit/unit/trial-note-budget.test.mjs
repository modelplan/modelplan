// SPDX-License-Identifier: MIT
// CKP-FAD-18 (glm-877-1): the trial note's string-table entry stays inside its length class in both languages.
import test from 'node:test';
import assert from 'node:assert/strict';
import {checkBudgets} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

test('CKP-FAD-18 the trial note string fits its length budget', () => {
  assert.deepEqual(checkBudgets().filter(o => o.key === 'mfd.cmpTrialNote'), []);
});
