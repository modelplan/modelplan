// SPDX-License-Identifier: MIT
// Transport adapter only. The injected scene owns rendering, camera return and context loss.
const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value);
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const keys = (value, required, optional = []) => record(value) &&
  required.every(key => Object.hasOwn(value, key)) &&
  Object.keys(value).every(key => required.includes(key) || optional.includes(key));
const text = (value, max = 256) => typeof value === 'string' && value.length > 0 && new TextEncoder().encode(value).length <= max;
const optionalText = (value, max) => value === undefined || value === null || text(value, max);
const optionalNumber = value => value === undefined || value === null || (Number.isFinite(value) && value >= 0);
const appearance = value => keys(value, ['theme', 'locale']) &&
  ['day', 'night'].includes(value.theme) && ['en', 'zh-CN'].includes(value.locale);
const viewport = value => keys(value, ['width', 'height', 'scale', 'profile']) &&
  [value.width, value.height].every(n => Number.isInteger(n) && n > 0 && n <= 4096) &&
  Number.isFinite(value.scale) && value.scale >= 0.1 && value.scale <= 4 &&
  ['tall', 'short'].includes(value.profile);
const effort = value => keys(value, ['effort'], ['label', 'ability', 'cost', 'time']) &&
  text(value.effort, 128) && optionalText(value.label) &&
  [value.ability, value.cost, value.time].every(optionalNumber);
const model = value => keys(value, ['id', 'efforts'], ['name', 'developerId', 'recommended']) &&
  text(value.id, 128) && optionalText(value.name) && optionalText(value.developerId, 128) &&
  optionalText(value.recommended, 128) && Array.isArray(value.efforts) && value.efforts.length <= 16 &&
  value.efforts.every(effort) && new Set(value.efforts.map(e => e.effort)).size === value.efforts.length;
const projection = value => keys(value, ['revision', 'models']) && text(value.revision, 128) &&
  Array.isArray(value.models) && value.models.length <= 256 && value.models.every(model) &&
  new Set(value.models.map(m => m.id)).size === value.models.length;
const configuration = value => keys(value, ['appearance', 'viewport', 'projection']) &&
  appearance(value.appearance) && viewport(value.viewport) && projection(value.projection);
const captureKey = value => keys(value, ['generation', 'requestId', 'configurationId', 'appearance', 'viewport', 'projectionRevision']) &&
  [value.generation, value.requestId, value.configurationId].every(uuid) &&
  appearance(value.appearance) && viewport(value.viewport) && text(value.projectionRevision, 128);
const equal = (a, b) => record(a) && record(b) && Object.keys(a).length === Object.keys(b).length && Object.keys(a).every(key => a[key] === b[key]);
const copy = value => JSON.parse(JSON.stringify(value));

export function createFieldBridge({generation, post, scene}) {
  if (!uuid(generation) || typeof post !== 'function' || typeof scene.apply !== 'function' ||
      typeof scene.setPaused !== 'function' || typeof scene.captureBarrier !== 'function' ||
      typeof scene.dispose !== 'function') throw new TypeError('Invalid field adapter');
  const cancellation = new AbortController();
  let disposed = false, busy = false, pending = null, active = null, wanted = null;
  let capturePending = false, capturedId = null, readySent = false;
  const emit = (type, values = {}) => post(JSON.stringify({version: 1, generation, type, ...values}));
  const fail = code => { if (!disposed) emit('error', {code}); };
  async function apply(message) {
    busy = true;
    try {
      await scene.apply(copy(message.configuration), {paused: message.paused, signal: cancellation.signal});
      if (!disposed) {
        scene.setPaused(wanted.paused);
        active = message; capturedId = null;
        emit('settled', {requestId: message.requestId});
      }
    } catch { fail('render'); }
    finally {
      busy = false;
      const next = pending; pending = null;
      if (next && !disposed) void apply(next);
    }
  }
  function receive(message) {
    if (disposed || !record(message) || message.version !== 1 || message.generation !== generation || !uuid(message.requestId)) return false;
    try { if (new TextEncoder().encode(JSON.stringify(message)).length > 1024 * 1024) return false; } catch { return false; }
    if (['configure', 'setPublicProjection', 'setAppearance'].includes(message.type)) {
      if (!keys(message, ['version', 'generation', 'requestId', 'type', 'configuration', 'paused']) ||
          !configuration(message.configuration) || typeof message.paused !== 'boolean') return false;
      // Pause immediately, even when a preceding bounded configuration render is outstanding.
      wanted = copy(message);
      try { scene.setPaused(message.paused); } catch { fail('render'); return false; }
      if (busy) pending = wanted; else void apply(wanted);
      return true;
    }
    if (message.type === 'capture') {
      if (!keys(message, ['version', 'generation', 'requestId', 'type', 'captureKey']) || !captureKey(message.captureKey) ||
          message.captureKey.generation !== generation || message.captureKey.requestId !== message.requestId ||
          busy || pending || capturePending || capturedId === message.requestId || !active || wanted.paused ||
          active.requestId !== message.captureKey.configurationId ||
          !equal(active.configuration.appearance, message.captureKey.appearance) ||
          !equal(active.configuration.viewport, message.captureKey.viewport) ||
          active.configuration.projection.revision !== message.captureKey.projectionRevision) return false;
      capturePending = true; capturedId = message.requestId;
      const source = active, identity = copy(message.captureKey);
      Promise.resolve().then(() => scene.captureBarrier()).then(() => {
        if (!disposed && active === source && wanted.requestId === source.requestId && !wanted.paused) {
          // Pixel transfer is WK takeSnapshot, not canvas/base64 or a Screen Recording API.
          emit('captureResult', {requestId: identity.requestId, captureKey: identity});
        }
      }).catch(() => fail('capture')).finally(() => { capturePending = false; });
      return true;
    }
    if (message.type === 'dispose' && keys(message, ['version', 'generation', 'requestId', 'type'])) {
      disposed = true; cancellation.abort(); pending = null; wanted = null; active = null;
      // Invocation is immediate; acknowledgement is best effort, never native-close permission.
      try { Promise.resolve(scene.dispose()).then(() => emit('disposed', {requestId: message.requestId})).catch(() => {}); } catch {}
      return true;
    }
    return false;
  }
  return {
    receive,
    ready() { if (!disposed && !readySent) { readySent = true; emit('ready'); } },
    interaction(kind) {
      if (!disposed && readySent && wanted && !wanted.paused && ['pointer', 'drag', 'keyboard', 'camera'].includes(kind)) {
        emit('interaction', {interaction: kind});
      }
    },
  };
}

export function installFieldBridge({scene, target = window}) {
  const generation = new URL(target.location.href).searchParams.get('generation');
  const bridge = createFieldBridge({generation, scene,
    post: message => target.webkit.messageHandlers.field.postMessage(message)});
  target.modelPlanFieldReceive = message => {
    const accepted = bridge.receive(message);
    if (accepted && message.type === 'dispose') {
      for (const [type, listener] of listeners) target.removeEventListener(type, listener);
      delete target.modelPlanFieldReceive;
    }
    return accepted;
  };
  const pointer = event => { if (event.isTrusted) bridge.interaction(event.type === 'pointermove' ? 'drag' : 'pointer'); };
  const drag = event => { if (event.buttons) pointer(event); };
  const keyboard = event => { if (event.isTrusted) bridge.interaction('keyboard'); };
  const listeners = [['pointerdown', pointer], ['pointermove', drag], ['keydown', keyboard]];
  for (const [type, listener] of listeners) target.addEventListener(type, listener);
  bridge.ready();
  return bridge;
}
