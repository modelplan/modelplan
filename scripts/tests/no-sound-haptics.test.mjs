// SPDX-License-Identifier: MIT
// MOT-2.3-12: the app makes no sound and no haptic feedback. Native sources must not reach the system sound,
// audio, speech or haptic APIs, and the cockpit web page must not create audio or vibrate. A static scan of the
// shipped sources is the only seam for an absence, so the scanner is itself checked against known offenders.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../..', import.meta.url));

const NATIVE = /\b(NSSound|NSBeep|NSHapticFeedbackManager|NSHapticFeedbackPerformer|CHHapticEngine|CHHapticPattern|AVAudioEngine|AVAudioPlayer|AVAudioSession|AVAudioPlayerNode|AVPlayer|AVQueuePlayer|AVSpeechSynthesizer|AudioServicesPlaySystemSound|AudioServicesPlayAlertSound|AudioToolbox|SystemSoundID|NSUserNotification\.defaultSoundName|UNNotificationSound|\.sound\s*=)/;
const WEB = /\b(?:new\s+Audio\s*\(|AudioContext|webkitAudioContext|SpeechSynthesisUtterance|speechSynthesis|navigator\.vibrate)|<audio\b/;
const strip = text => text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');

function files(dir, extensions) {
  const found = [];
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name === '.build' || name === '.tmp' || name === '.git') continue;
    const path = join(dir, name), info = statSync(path);
    if (info.isDirectory()) found.push(...files(path, extensions));
    else if (extensions.some(e => name.endsWith(e))) found.push(path);
  }
  return found;
}
const offenders = (paths, pattern) => paths.flatMap(path => strip(readFileSync(path, 'utf8')).split('\n').flatMap((line, i) => pattern.test(line) ? [`${relative(root, path)}:${i + 1}: ${line.trim()}`] : []));

test('MOT-2.3-12 the scanner recognises every sound, speech and haptic entry point', () => {
  for (const sample of ['NSSound.beep()', 'NSSound(named: "Tink")?.play()', 'NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)', 'AudioServicesPlaySystemSound(1104)', 'let p = AVAudioPlayer()', 'content.sound = .default', 'import AudioToolbox'])
    assert.match(sample, NATIVE, sample);
  for (const sample of ['new Audio("a.mp3").play()', 'new AudioContext()', 'navigator.vibrate(10)', '<audio src="x">'])
    assert.match(sample, WEB, sample);
  // Comments and strings about the rule are not offenders; code is.
  assert.equal(strip('// NSSound is never used\nlet x = 1\n/* AVAudioPlayer */').includes('NSSound'), false);
});

test('MOT-2.3-12 no native source of the app or the Swift client plays a sound or a haptic', () => {
  const native = [...files(join(root, 'desktop/native'), ['.swift']), ...files(join(root, 'clients/swift'), ['.swift'])];
  assert.ok(native.length > 100, `scanned ${native.length} Swift files`);
  assert.deepEqual(offenders(native, NATIVE), []);
});

test('MOT-2.3-12 the cockpit web page creates no audio and does not vibrate', () => {
  const web = ['desktop/cockpit/src', 'desktop/cockpit/prototype', 'desktop/cockpit/web', 'desktop/cockpit/study'].flatMap(dir => files(join(root, dir), ['.ts', '.js', '.mjs', '.html']));
  assert.ok(web.length > 20, `scanned ${web.length} web files`);
  assert.deepEqual(offenders(web, WEB), []);
});
