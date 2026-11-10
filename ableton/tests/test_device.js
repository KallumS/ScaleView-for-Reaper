/* The Max for Live device, run in Node on a pretend Max and a pretend Live.
 *   python3 ableton/kit/build.py ableton/device.json && node --test ableton/tests/ */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { load } = require('../kit/test/max.js');

const BUNDLE = path.join(__dirname, '..', 'ScaleView.js');
function device(opts) {
  const d = load(BUNDLE, Object.assign({ width: 200, height: 100 }, opts || {}));
  d.send('bang');
  d.run(100);
  d.show = () => { d.paint(); return d.texts(); };
  d.clickAt = (x, y) => { d.ctx.onclick(x, y, 1, 0, 0, 0, 0, 0); d.paint(); d.ctx.ondrag(x, y, 0); d.paint(); d.paint(); };
  d.choose = (label) => {
    const items = d.ctx.R.menu.items, i = items.findIndex((it) => it.label === label);
    assert.ok(i >= 0, label + ' in the menu');
    d.ctx.chooseMenu(i);
    d.paint();
  };
  d.play = (...notes) => notes.forEach((p) => [0x90, p, 100].forEach((b) => d.send('msg_int', b)));
  return d;
}

test('ScaleView Pro runs unchanged and draws its twelve notes', () => {
  const d = device();
  const t = d.show();
  for (const n of ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']) assert.ok(t.includes(n), n + ' in ' + t.join(' '));
  assert.ok(t.includes('No scale selected'));
  assert.strictEqual(d.ctx.R.error, null);
});

test('a click opens its scale menu, and the scale chosen is shown and spelled', () => {
  const d = device();
  d.clickAt(14, 59);
  assert.ok(d.ctx.R.menu, 'the menu is open');
  d.choose('Eb Major');
  assert.strictEqual(d.ctx.R.menu, null, 'the menu closed');
  const t = d.show();
  assert.ok(t.some((s) => /Eb Major/.test(s)), t.join(' | '));
  assert.ok(t.includes('Bb') && t.includes('Ab'), 'spelled with flats: ' + t.join(' '));
});

test('clicking away from a menu closes it with nothing chosen', () => {
  const d = device();
  d.clickAt(14, 59);
  d.ctx.chooseMenu(-1);
  d.paint();
  assert.strictEqual(d.ctx.R.menu, null);
  assert.ok(d.show().includes('No scale selected'));
});

test('the chord played into the device is named under the key', () => {
  const d = device();
  d.clickAt(14, 59);
  d.choose('C Major');
  d.play(57, 60, 64);
  d.run(100);
  const t = d.show();
  assert.ok(t.some((s) => /^Amin/.test(s) || /^Am\b/.test(s)), 'A minor named: ' + t.join(' | '));
  const bytes = d.midi();
  assert.deepStrictEqual(bytes.slice(0, 3), [0x90, 57, 100], 'MIDI passes through');
});

test('the scale is kept with the Live set', () => {
  const d = device();
  d.clickAt(14, 59);
  d.choose('D Major');
  d.ctx.save();
  const saved = d.out.filter((a) => a[0] === 1 && a[1] === 'set').pop();
  const e = load(BUNDLE, { width: 200, height: 100 });
  e.send('restore', saved[2]);
  e.send('bang');
  e.run(100);
  e.paint(); e.paint();
  assert.ok(e.texts().some((s) => /D Major/.test(s)), e.texts().join(' | '));
});
