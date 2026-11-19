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
// WebP (D207 launch-field rocket atlases): RIFF/WEBP container with one image, no metadata chunks.
export function webpSize(bytes) {
  assert.ok(bytes.length >= 30 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP', 'WebP signature');
  assert.equal(bytes.readUInt32LE(4) + 8, bytes.length, 'WebP length');
  let offset = 12, size, image = false;
  while (offset < bytes.length) {
    assert.ok(offset + 8 <= bytes.length, 'truncated WebP chunk');
    const type = bytes.toString('ascii', offset, offset + 4), length = bytes.readUInt32LE(offset + 4), body = offset + 8;
    assert.ok(body + length <= bytes.length, 'truncated WebP data');
    assert.ok(!['EXIF', 'XMP ', 'ICCP'].includes(type), 'unreviewed WebP metadata');
    if (type === 'VP8X') {
      assert.equal(offset, 12, 'WebP VP8X position');
      assert.equal(bytes[body] & 0x2c, 0, 'unreviewed WebP metadata flag');
      size = { width: 1 + bytes.readUIntLE(body + 4, 3), height: 1 + bytes.readUIntLE(body + 7, 3) };
    } else if (type === 'VP8L' || type === 'VP8 ') {
      assert.ok(!image, 'one WebP image'); image = true;
      let own;
      if (type === 'VP8L') {
        assert.equal(bytes[body], 0x2f, 'VP8L signature');
        const bits = bytes.readUInt32LE(body + 1);
        own = { width: 1 + (bits & 0x3fff), height: 1 + ((bits >>> 14) & 0x3fff) };
      } else {
        assert.ok(bytes[body + 3] === 0x9d && bytes[body + 4] === 0x01 && bytes[body + 5] === 0x2a, 'VP8 start code');
        own = { width: bytes.readUInt16LE(body + 6) & 0x3fff, height: bytes.readUInt16LE(body + 8) & 0x3fff };
      }
      if (size) assert.deepEqual(own, size, 'WebP canvas'); else size = own;
    } else assert.ok(['ALPH'].includes(type), 'unreviewed WebP chunk ' + type);
    offset = body + length + (length & 1);
  }
  assert.ok(size && image && offset === bytes.length && size.width > 0 && size.height > 0, 'incomplete WebP');
  return size;
}
