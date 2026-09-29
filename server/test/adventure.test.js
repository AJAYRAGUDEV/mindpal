import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { sanitise } from '../src/adventure/variation.js';

/**
 * What the server will and will not pass on from the model.
 *
 * The app validates the finished adventure itself, so this layer is not the
 * last line of defence — but it is the one that decides whether to spend
 * another Gemini call, so it has to be right about what "usable" means.
 */
describe('sanitising generated adventure text', () => {
  const slots = ['title', 'intro', 'char.ammal.name', 'clue.clue_basket.text'];

  it('keeps the slots that were asked for', () => {
    const { text, rejected } = sanitise(
      {
        title: 'The Festival Pot',
        intro: 'It is the morning of the harvest festival.',
      },
      slots,
    );

    assert.equal(text.title, 'The Festival Pot');
    assert.equal(text.intro, 'It is the morning of the harvest festival.');
    assert.deepEqual(rejected, []);
  });

  it('drops a key the app never offered', () => {
    // The model inventing its own slot is the ordinary case this guards: the
    // app can only place text into slots it asked for, so anything else is
    // noise at best.
    const { text, rejected } = sanitise(
      { title: 'Fine', market: { startingCoins: 500 } },
      slots,
    );

    assert.equal(text.title, 'Fine');
    assert.equal(text.market, undefined);
    assert.equal(rejected.length, 1);
    assert.match(rejected[0], /not a slot/);
  });

  it('refuses a rule dressed up as text', () => {
    // Even if a slot name looked mechanical, a non-string value never passes.
    const { text, rejected } = sanitise(
      { title: { setFlags: ['cheat'] }, intro: 42 },
      slots,
    );

    assert.deepEqual(text, {});
    assert.equal(rejected.length, 2);
    assert.ok(rejected.every((line) => /not text/.test(line)));
  });

  it('drops empty and whitespace-only values', () => {
    // An empty value would leave a character silent or a label blank.
    const { text, rejected } = sanitise({ title: '   ', intro: '' }, slots);

    assert.deepEqual(text, {});
    assert.equal(rejected.length, 2);
    assert.ok(rejected.every((line) => /empty/.test(line)));
  });

  it('drops a value long enough to break the layout', () => {
    const { text, rejected } = sanitise(
      { title: 'x'.repeat(601), intro: 'x'.repeat(600) },
      slots,
    );

    assert.equal(text.title, undefined);
    assert.equal(text.intro.length, 600, 'exactly at the limit is allowed');
    assert.match(rejected[0], /too long/);
  });

  it('trims what it keeps', () => {
    const { text } = sanitise({ title: '  The Pot  ' }, slots);
    assert.equal(text.title, 'The Pot');
  });

  it('survives nonsense without throwing', () => {
    // A model that returns a list, a string or nothing at all must not take
    // the endpoint down with it.
    for (const raw of [null, undefined, 'a string', [1, 2, 3], 7]) {
      const { text } = sanitise(raw, slots);
      assert.deepEqual(text, {}, `for ${JSON.stringify(raw)}`);
    }
  });

  it('drops a value that leaks an internal id', () => {
    // The prompt asks for ordinary names and the model usually obliges.
    // "Usually" is not good enough when the alternative is a player reading
    // "he will tell you that palm_sugar will do nicely instead".
    const { text, rejected } = sanitise(
      {
        title: 'Fine',
        intro: 'He will suggest palm_sugar instead.',
      },
      slots,
      ['jaggery', 'palm_sugar', 'clay_pot'],
    );

    assert.equal(text.title, 'Fine');
    assert.equal(text.intro, undefined, 'the leaked id is dropped');
    assert.match(rejected[0], /internal id "palm_sugar"/);
  });

  it('does not reject an ordinary word that happens to be an id', () => {
    // "jaggery" has no underscore and is a real English word, so it must not
    // be treated as an internal id — glossing gur as jaggery is correct.
    const { text, rejected } = sanitise(
      { intro: 'Dark cane jaggery, in a round cake.' },
      slots,
      ['jaggery', 'palm_sugar'],
    );

    assert.equal(text.intro, 'Dark cane jaggery, in a round cake.');
    assert.deepEqual(rejected, []);
  });

  it('works with no forbidden list at all', () => {
    const { text } = sanitise({ title: 'Still fine' }, slots);
    assert.equal(text.title, 'Still fine');
  });

  it('accepts a full house', () => {
    const full = Object.fromEntries(slots.map((slot) => [slot, 'Some words.']));
    const { text, rejected } = sanitise(full, slots);

    assert.equal(Object.keys(text).length, slots.length);
    assert.deepEqual(rejected, []);
  });
});
