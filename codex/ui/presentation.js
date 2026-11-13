// Presentation is owned by the host. A request is not proof that it expanded.
export async function requestPanelMode(request, context = {}) {
  const current = context.displayMode ?? 'inline';
  const target = current === 'fullscreen' ? 'inline' : 'fullscreen';
  if (Array.isArray(context.availableDisplayModes) && !context.availableDisplayModes.includes(target))
    return { status: 'unsupported', mode: current };
  const result = await request('ui/request-display-mode', { mode: target });
  if (!['inline', 'fullscreen', 'pip'].includes(result?.mode)) throw Error('Invalid host display mode');
  return { status: result.mode === target ? 'changed' : 'unsupported', mode: result.mode };
}
