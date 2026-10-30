// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
export const privateText = /sourceRoot|sourceHashes|designCommit|designHead|design-handoffs|clients\/official-visuals|guanbear|modelplans\.ai|\/home\/|\/tmp\/|\/mnt\/shared/i;
export function keys(value, allowed, required = allowed) {
  assert.ok(value && typeof value === 'object' && !Array.isArray(value), 'manifest object required');
  assert.ok(Object.keys(value).every(k => allowed.includes(k)), 'unapproved manifest field');
  assert.ok(required.every(k => Object.hasOwn(value, k)), 'missing manifest field');
}
export function pngSize(bytes) {
  assert.ok(bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), 'PNG signature');
  let offset = 8, size, data = false, ended = false;
  while (offset < bytes.length) {
    assert.ok(offset + 12 <= bytes.length, 'truncated PNG chunk');
    const length = bytes.readUInt32BE(offset), type = bytes.toString('ascii', offset + 4, offset + 8);
    assert.ok(offset + length + 12 <= bytes.length, 'truncated PNG data');
    assert.ok(!['tEXt', 'zTXt', 'iTXt', 'eXIf'].includes(type), 'unreviewed PNG metadata');
    if (offset === 8) {
      assert.ok(type === 'IHDR' && length === 13, 'PNG IHDR');
      size = { width: bytes.readUInt32BE(offset + 8), height: bytes.readUInt32BE(offset + 12) };
      assert.ok(size.width > 0 && size.height > 0, 'PNG dimensions');
    }
    if (type === 'IDAT') data = true;
    offset += length + 12;
    if (type === 'IEND') { assert.equal(length, 0, 'PNG IEND'); ended = true; break; }
  }
  assert.ok(size && data && ended && offset === bytes.length, 'incomplete PNG');
  return size;
}
