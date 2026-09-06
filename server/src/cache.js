import { createHash } from 'node:crypto';

/**
 * A tiny in-memory cache with a time limit.
 *
 * Purpose: the free tier has request limits, and asking the same question
 * twice in a demo should not cost two calls. Nothing here is persisted — the
 * cache dies with the process, which also means personal context is never
 * written to disk by this gateway.
 */
export class TtlCache {
  constructor({ ttlMs = 10 * 60 * 1000, maxEntries = 200 } = {}) {
    this.ttlMs = ttlMs;
    this.maxEntries = maxEntries;
    this.entries = new Map();
  }

  /**
   * The key is a hash, not the request itself, so personal details are not
   * sitting in memory as readable map keys.
   */
  static keyFor(request) {
    return createHash('sha256').update(JSON.stringify(request)).digest('hex');
  }

  get(key) {
    const entry = this.entries.get(key);
    if (entry === undefined) return undefined;

    if (Date.now() > entry.expiresAt) {
      this.entries.delete(key);
      return undefined;
    }

    // Re-inserting moves it to the end, so the oldest key is always first.
    this.entries.delete(key);
    this.entries.set(key, entry);
    return entry.value;
  }

  set(key, value) {
    if (this.entries.size >= this.maxEntries) {
      const oldest = this.entries.keys().next().value;
      if (oldest !== undefined) this.entries.delete(oldest);
    }
    this.entries.set(key, { value, expiresAt: Date.now() + this.ttlMs });
  }

  get size() {
    return this.entries.size;
  }
}

/**
 * A fixed-window request limiter.
 *
 * Deliberately simple: this gateway runs on one machine for one family during
 * development. A distributed limiter would be more code than the thing it
 * protects.
 */
export class RateLimiter {
  constructor({ maxPerMinute = 20 } = {}) {
    this.maxPerMinute = maxPerMinute;
    this.windowStart = Date.now();
    this.count = 0;
  }

  /** True when the request is allowed. */
  tryConsume(now = Date.now()) {
    if (now - this.windowStart >= 60_000) {
      this.windowStart = now;
      this.count = 0;
    }
    if (this.count >= this.maxPerMinute) return false;
    this.count += 1;
    return true;
  }
}
