// Verified publication through the canonical public reader: every
// object is hash-checked before use, and the last good one is cached for offline use.
import {
  ClientDataReader,
  verifyClientDigest,
} from "@modelplan/public-reader";
import type { Platform } from "./platform.ts";
import { BASE, project, type Digest, type Publication } from "./published.ts";

const CACHE_KEY = "publication";
const TTL = 10 * 60 * 1000;

export function createPublication(
  platform: Platform,
  now: () => number = Date.now,
) {
  let checkedAt: number | null = null,
    lastError: string | null = null,
    pending: Promise<Publication | null> | null = null;
  const reader = new ClientDataReader<Digest>({
    baseUrl: BASE,
    fetcher: (input, init) =>
      platform.fetch(input instanceof Request ? input.url : String(input), {
        headers: Object.fromEntries(new Headers(init?.headers).entries()),
        signal: init?.signal ?? undefined,
      }),
  });
  async function loadCached() {
    if (reader.current) return;
    try {
      const c = await platform.cache.get<{ digest: Digest; checkedAt: number }>(
        CACHE_KEY,
      );
      if (c?.digest) {
        await verifyClientDigest(c.digest);
        reader.current = c.digest;
        checkedAt = c.checkedAt ?? null;
      }
    } catch {
      /* The shared verifier rejects an invalid cache. */
    }
  }
  async function read(force: boolean): Promise<Publication | null> {
    await loadCached();
    if (
      !force &&
      reader.current &&
      checkedAt != null &&
      now() - checkedAt < TTL
    )
      return project(reader.current, checkedAt, lastError, now());
    const r = await reader.refresh();
    lastError = r.errorCode;
    if (!r.errorCode) {
      checkedAt = now();
      await platform.cache
        .set(CACHE_KEY, { digest: r.digest, checkedAt })
        .catch(() => {});
    }
    return r.digest ? project(r.digest, checkedAt, lastError, now()) : null;
  }
  return (force = false): Promise<Publication | null> => {
    if (!pending)
      pending = read(force)
        .catch(() => null)
        .finally(() => {
          pending = null;
        });
    return pending;
  };
}
