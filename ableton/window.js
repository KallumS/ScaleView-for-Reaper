// The picture in the README: `node ableton/window.js` redraws ableton/window.png.
// E flat major chosen from the menu, and Eb G Bb D played.
require('./kit/test/picture.js')(__dirname, { bundle: 'ScaleView.js', w: 200, h: 100,
  go(d) {
    d.ctx.paint(); d.ctx.onclick(14, 59, 1, 0, 0, 0, 0, 0); d.ctx.paint(); d.ctx.ondrag(14, 59, 0); d.ctx.paint();
    d.ctx.chooseMenu(d.ctx.R.menu.items.findIndex((it) => it.label === 'Eb Major'));
    [0x90, 51, 100, 0x90, 55, 100, 0x90, 58, 100, 0x90, 62, 100].forEach((x) => d.send('msg_int', x));
    d.run(100); d.ctx.paint(); d.ctx.paint();
  } });
