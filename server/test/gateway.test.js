import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { RateLimiter, TtlCache } from '../src/cache.js';
import { redact } from '../src/config.js';
import { validateAiRequest } from '../src/validate.js';

describe('request validation', () => {
  const valid = {
    task: 'memory_assistant',
    language: 'en',
    context: [{ kind: 'person', name: 'Rahul', relationship: 'Son' }],
    userInput: 'Who is Rahul?',
  };

  it('accepts a well-formed request', () => {
    const result = validateAiRequest(valid);
    assert.equal(result.ok, true);
    assert.equal(result.value.task, 'memory_assistant');
  });

  it('rejects an unknown task', () => {
    const result = validateAiRequest({ ...valid, task: 'diagnose_dementia' });
    assert.equal(result.ok, false);
  });

  it('rejects a missing language', () => {
    const result = validateAiRequest({ ...valid, language: '' });
    assert.equal(result.ok, false);
  });

  it('rejects a memory question with no user input', () => {
    const result = validateAiRequest({ ...valid, userInput: '   ' });
    assert.equal(result.ok, false);
  });

  it('refuses an oversized context', () => {
    // A request carrying the whole address book never reaches Gemini.
    const result = validateAiRequest({
      ...valid,
      context: Array.from({ length: 20 }, () => ({ name: 'X' })),
    });
    assert.equal(result.ok, false);
    assert.match(result.error, /at most/);
  });

  it('rejects a body that is not an object', () => {
    assert.equal(validateAiRequest(null).ok, false);
    assert.equal(validateAiRequest('hello').ok, false);
  });

  it('clamps count and optionCount instead of failing', () => {
    const result = validateAiRequest({
      ...valid,
      task: 'game_questions',
      count: 999,
      optionCount: 0,
    });
    assert.equal(result.ok, true);
    assert.equal(result.value.count, 8);
    assert.equal(result.value.optionCount, 2);
  });

  it('falls back to defaults for missing counts', () => {
    const result = validateAiRequest({ ...valid, task: 'game_questions' });
    assert.equal(result.value.count, 5);
    assert.equal(result.value.optionCount, 3);
  });
});

describe('key redaction', () => {
  it('removes anything key-shaped from text', () => {
    const leaked = 'error: key AIzaSyC1234567890abcdefGHIJ was rejected';
    const safe = redact(leaked);

    assert.ok(!safe.includes('AIzaSyC1234567890abcdefGHIJ'));
    assert.match(safe, /REDACTED_KEY/);
  });

  it('leaves ordinary text alone', () => {
    assert.equal(redact('The AI service is busy.'), 'The AI service is busy.');
  });

  it('passes non-strings through untouched', () => {
    assert.equal(redact(undefined), undefined);
  });
});

describe('TtlCache', () => {
  it('returns a stored value', () => {
    const cache = new TtlCache();
    cache.set('a', { text: 'Rahul is your son.' });
    assert.deepEqual(cache.get('a'), { text: 'Rahul is your son.' });
  });

  it('forgets a value once it expires', async () => {
    const cache = new TtlCache({ ttlMs: 10 });
    cache.set('a', 1);
    await new Promise((resolve) => setTimeout(resolve, 25));
    assert.equal(cache.get('a'), undefined);
  });

  it('drops the oldest entry when full', () => {
    const cache = new TtlCache({ maxEntries: 2 });
    cache.set('a', 1);
    cache.set('b', 2);
    cache.set('c', 3);

    assert.equal(cache.get('a'), undefined);
    assert.equal(cache.get('c'), 3);
    assert.equal(cache.size, 2);
  });

  it('hashes the request rather than storing it in the clear', () => {
    const key = TtlCache.keyFor({ userInput: 'Who is Rahul?' });

    assert.equal(key.length, 64);
    assert.ok(!key.includes('Rahul'));
  });

  it('gives the same key for the same request', () => {
    const request = { task: 'memory_assistant', userInput: 'Who is Rahul?' };
    assert.equal(TtlCache.keyFor(request), TtlCache.keyFor(request));
  });
});

describe('RateLimiter', () => {
  it('allows up to the limit and then refuses', () => {
    const limiter = new RateLimiter({ maxPerMinute: 3 });

    assert.equal(limiter.tryConsume(), true);
    assert.equal(limiter.tryConsume(), true);
    assert.equal(limiter.tryConsume(), true);
    assert.equal(limiter.tryConsume(), false);
  });

  it('opens up again in the next window', () => {
    const limiter = new RateLimiter({ maxPerMinute: 1 });
    const start = Date.now();

    assert.equal(limiter.tryConsume(start), true);
    assert.equal(limiter.tryConsume(start + 1000), false);
    assert.equal(limiter.tryConsume(start + 61_000), true);
  });
});
