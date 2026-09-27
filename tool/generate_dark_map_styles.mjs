import { readFileSync, writeFileSync } from 'node:fs';

// Pinned upstream snapshots keep palette changes independent of upstream releases.
// Run from the repository root; only generated paint properties are changed.
const palettes = {
  liberty: {
    land: '#22262A', residential: '#2C3034', green: '#30483A',
    water: '#263F50', ice: '#425663', sand: '#454339', special: '#403640',
    building: '#393D42', outline: '#50565D', road: '#737980',
    major: '#929080', motorway: '#B39C78', rail: '#929AA2', casing: '#41474D',
    label: '#D8DBDD', muted: '#BCC5CB', waterLabel: '#A8CBDF',
  },
  bright: {
    land: '#242529', residential: '#302E34', green: '#32493B',
    water: '#294857', ice: '#435962', sand: '#494435', special: '#483745',
    building: '#3C3B42', outline: '#56545D', road: '#7B7C83',
    major: '#B3A982', motorway: '#C39A85', rail: '#9CA4B6', casing: '#49464E',
    label: '#E0DDE3', muted: '#C8BFD0', waterLabel: '#ABCDD9',
  },
  positron: {
    land: '#252729', residential: '#2B2D2F', green: '#303A35',
    water: '#2E3D44', ice: '#444B50', sand: '#3B3B38', special: '#37383C',
    building: '#34373A', outline: '#484D51', road: '#71767A',
    major: '#878D92', motorway: '#979EA3', rail: '#747F86', casing: '#454B50',
    label: '#D6D9DA', muted: '#BFC6CA', waterLabel: '#B4C6CE',
  },
  fiord: {
    land: '#252F32', residential: '#2D373A', green: '#344A41',
    water: '#223F4B', ice: '#425B60', sand: '#434A40', special: '#3C4148',
    building: '#364145', outline: '#4F6064', road: '#788B8E',
    major: '#8CA4A8', motorway: '#9DB5B8', rail: '#79999D', casing: '#42565B',
    label: '#D5E1DF', muted: '#BACEC8', waterLabel: '#A6CCD8',
  },
  dark: {
    land: '#202225', residential: '#292C30', green: '#2D3F35',
    water: '#253C48', ice: '#404C54', sand: '#3F3D34', special: '#3D343D',
    building: '#33363A', outline: '#4B5055', road: '#737A80',
    major: '#858D94', motorway: '#969EA5', rail: '#77848C', casing: '#41474D',
    label: '#CFD2D3', muted: '#BBC4C9', waterLabel: '#ABC9D8',
  },
};

function paintRole(id, property, p) {
  if (property.includes('halo-color')) return p.land;
  if (property === 'text-color' || property === 'icon-color') {
    return /water/.test(id) ? p.waterLabel : /poi|path|other/.test(id) ? p.muted : p.label;
  }
  if (property.includes('outline-color')) return p.outline;
  if (/background/.test(id)) return p.land;
  if (/water|ferry/.test(id)) return p.water;
  if (/building/.test(id)) return p.building;
  if (/park|wood|grass|cemetery|pitch|track$/.test(id) && !/road|tunnel|bridge/.test(id)) return p.green;
  if (/ice|glacier/.test(id)) return p.ice;
  if (/sand/.test(id)) return p.sand;
  if (/hospital|school|commercial|industrial/.test(id)) return p.special;
  if (/residential|suburb/.test(id)) return p.residential;
  if (/boundary/.test(id)) return p.outline;
  if (/casing|dashline/.test(id)) return p.casing;
  if (/rail|cable/.test(id)) return p.rail;
  if (/motorway/.test(id)) return p.motorway;
  if (/primary|secondary|tertiary|trunk|major|link/.test(id)) return p.major;
  if (/road|highway|bridge|tunnel|aeroway/.test(id)) return p.road;
  return p.residential;
}

function recolor(value, color) {
  if (Array.isArray(value)) return value.map(v => recolor(v, color));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, recolor(v, color)]));
  }
  if (typeof value !== 'string' || !/^(#[\da-f]{3,8}$|rgba?\(|hsla?\()/i.test(value)) return value;
  // Keep transparent stops transparent; do not recolor zoom inputs or match labels.
  const alpha = /^(rgba|hsla)\(/i.test(value)
    ? Number(value.slice(value.lastIndexOf(',') + 1, -1))
    : value.startsWith('#') && value.length === 9 ? parseInt(value.slice(7), 16) / 255 : 1;
  if (alpha === 1) return color;
  const rgb = [1, 3, 5].map(i => parseInt(color.slice(i, i + 2), 16));
  return `rgba(${rgb.join(',')},${alpha})`;
}

for (const [name, palette] of Object.entries(palettes)) {
  const style = JSON.parse(readFileSync(`tool/map_styles/${name}.json`, 'utf8'));
  style.name = `MiriaGo ${name} dark`;
  style.metadata = {
    'miriago:upstream': `https://tiles.openfreemap.org/styles/${name}`,
    'miriago:snapshot': '2026-09-08',
    'miriago:changes': 'Per-style dark paint; unchanged source, layout, filters and geometry. Reduced raster/pattern brightness.',
  };
  for (const layer of style.layers) {
    const paint = layer.paint ?? {};
    for (const property of Object.keys(paint)) {
      if (property.endsWith('-color')) {
        paint[property] = recolor(paint[property], paintRole(layer.id, property, palette));
      }
    }
    if (layer.type === 'symbol' && layer.layout?.['text-field'] && !/shield/.test(layer.id)) {
      paint['text-halo-color'] = palette.land;
      paint['text-halo-width'] = Math.max(1, typeof paint['text-halo-width'] === 'number' ? paint['text-halo-width'] : 1);
    }
    if (layer.type === 'raster') {
      paint['raster-brightness-max'] = 0.18;
      paint['raster-saturation'] = -0.85;
    }
    if (paint['fill-pattern']) {
      paint['fill-opacity'] = 0.10;
    }
    layer.paint = paint;
  }
  const file = name === 'dark' ? 'readable_dark' : `${name}_dark`;
  writeFileSync(`assets/maps/${file}.json`, `${JSON.stringify(style, null, 2)}\n`);
}
