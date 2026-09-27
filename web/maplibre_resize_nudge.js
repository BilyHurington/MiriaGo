// maplibre-gl can stay blank when Flutter creates its container before the
// platform view is laid out and composited: the map loads but never repaints
// at the final size. Wrap the Map constructor so every map re-measures and
// repaints once its style has loaded and whenever its container resizes.
(function () {
  'use strict';
  var lib = window.maplibregl;
  if (!lib || !lib.Map || lib.Map.__miriagoPatched) return;
  var Original = lib.Map;
  function Patched(options) {
    var map = new Original(options);
    var kick = function () {
      try {
        map.resize();
        map.triggerRepaint();
      } catch (_) {}
    };
    map.once('load', function () {
      kick();
      setTimeout(kick, 250);
      setTimeout(kick, 1000);
    });
    map.once('idle', kick);
    if (typeof ResizeObserver === 'function') {
      try {
        new ResizeObserver(kick).observe(map.getContainer());
      } catch (_) {}
    }
    return map;
  }
  Patched.prototype = Original.prototype;
  Object.setPrototypeOf(Patched, Original);
  Patched.__miriagoPatched = true;
  lib.Map = Patched;
})();
