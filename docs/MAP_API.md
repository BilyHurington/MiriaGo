# Map foundation — API reference

Import `package:miriago/ui/map/map.dart` (relative `../../map/map.dart`).
Live demo: `lib/ui/map/map_gallery_page.dart` (route `/_lab/map`). Tests: `test/ui/map/` (see `map_test_harness.dart`).

## plan_map.dart
- `PlanMap({controller, initialCenter, initialZoom = 15, initialFitPoints, initialFitPadding, initialFitMaxZoom = 17, minZoom = 4, maxZoom, allowRotation = false, interactive = true, layers, children, onTap, onLongPress, onSecondaryTap, onMapEvent, onMapReady, obscuredInsets, attributionPadding, attributionAlignment = bottomLeft, showAttribution = true, settings, tileLayerOverride, disableTiles = false})`
  - Tiles from `configuredMapTileLayer(settings, dark: context.colors.isDark)`; max zoom from `settings.mapMaxZoom`.
  - `onTap/onLongPress/onSecondaryTap` receive `LatLng`. Right-click falls back to onLongPress.
  - `initialCenter` is centred in the uncovered area; `obscuredInsets` default from `MapPanelScope`.
  - Draw order: tiles → `layers` (polygons/circles/routes) → `children` (markers).
- `PlanMapController({MapController? mapController})`: `.mapController`, `.camera`, `.isReady`, `.obscuredInsets`, `.visibleCenter`, `.visibleRect(size)`, `moveTo(latLng, {zoom, animate, centerInVisibleArea})`, `fitPoints(points, {padding, maxZoom, animate})`, `fitBounds(bounds, …)`, `zoomBy(delta)`, `.lastPointerKind`.
- `PlanMapScope.maybeOf(ctx)`, `centerForVisiblePoint(...)`, `kDefaultMapCenter` (Kyoto), `kDefaultMapZoom`, `kMapMinZoom`.

## map_markers.dart
- `PointMarkerKind { pending, current, completed, imported, importable }`, `pointMarkerKindFor(VisitStatus)`.
- `PointMarker({kind, selected, label, color, tooltip, onTap})`, `ThumbnailMarker({kind, image, showImage, selected, color, loadLimiter, tooltip, onTap})` + `MarkerImage`, `ClusterMarker({count, onTap, opensBrowser})`, `AnchorMarker({color, name, selected, onTap})`, `LocationPuck({stale, headingTurns, tooltip})`, `NumberedStopMarker`, `DestinationMarker`, `MapNameLabel`. Most have `static marker(point:, child:, scale:)`, `sizeFor`/`alignmentFor`. `scaledMapMarker(...)`, `markerAnchorAlignment`, `kMapMarkerRing`.

## plan_marker_layer.dart
- `PlanMarkerLayer<T>({items, idOf, positionOf, kindOf, selectedId, onTap, onBrowseOverlap, labelOf, tooltipOf, colorOf, imageOf, showThumbnails, hideCompleted, overlapIds, onOverlapInvalidated, enabled, keyPrefix = 'plan-map', settings})` — old clustering / thumbnail mode / overlap browsing. Keys `'plan-map-marker-$id'`, `'plan-map-cluster-$firstId-$n'`.
- `planPointMarkerLayer({points, statusOf, groups, selectedId, onTap, onBrowseOverlap, overlapIds, onOverlapInvalidated, …})`; `planPointMarkerImage(point)`.

## group_hull_layer.dart
- `GroupHullLayer({groups, selectedGroupId, radiusMeters, visible})`
- `GroupAnchor`, `groupAnchorsFor(groups, allPoints, colors)`, `AnchorRadiusLayer({anchors, radiusMeters, highlightedGroupId})`, `AnchorMarkerLayer({anchors, selectedGroupId, onTap, scale})`, `mapGroupColor(colors, bucket, index)`, `mapGroupColorForPoint(...)`.

## box_select_layer.dart
- `BoxSelectLayer({active, controller, onChanged, onSelected, clearWhenDeactivated = true})` (in `PlanMap.children`; blocks panning while active; marker taps blocked while active).
- `BoxSelectController` (`.bounds`, `.clear()`, `.setCorners`), `boundsForScreenRect(camera, rect)`, `itemsInBounds(items, positionOf, bounds)`.

## center_pin_picker.dart
- `CenterPinPicker({onChanged, controller, initialCenter, initialZoom = 16, obscuredInsets, layers, children, pinColor, tileLayerOverride, disableTiles})` — pin at the centre of the uncovered area; reports on every move and once when ready.

## map_controls.dart
- `MapControls({mapController, onLocate, locating, locationError, onCurrentTarget, layerToggles, showZoom, leading, trailing})` — pass `mapController:` explicitly when placed in `MapPanelLayout.controls`.
- `MapControlButton`, `MapLayerToggle`, `MapLayersPopover`, `showMapLayersPopover(ctx, toggles: (ctx) => [...])`, `MapLayersButton`, `MapOverlapPager` (「重合点位 i / n」).

## route_layer.dart
- `RouteLayer({route, stops, stopNames, showDestination = true, firstActiveStop = 0, settings})`.

## map_location.dart
- `MapLocationController({tracker})`: `.position`, `.accuracyMeters`, `.error`, `.isLocating`, `.isStale`, `.isActive`, `locate()`, `configure(...)`, `disable()`.
- `MapLocationBinding({controller, enabled, continuous, onError, child})` — active only when route current, tab active, app foreground.
- `LocationPuckLayer({controller, heading, showAccuracy, scale})`.

## map_panel_layout.dart
- `MapPanelLayout({map, panel, panelHeader, inspector, controls, topOverlay, peekHeight = 160, controller, mapPadding})`
- `MapPanelController({initialSnap})`: `.snap`, `.snapTo(snap)`, `.sheetExtent`, `.usesSidePanel`; `MapPanelSnap`, `MapPanelScope`.
- Constants `kMapSidePanelWidth` 380, `kMapSidePanelShortWidth` 320, `kMapInspectorWidth` 360.
- Only a panel list using the default PrimaryScrollController drives the sheet. `peekHeight` includes handle+header but not bottom safe area.

## Limitations
- Thumbnail marker mode is page-local state (no setting), as in the old app.
- No list-hover highlight state in PlanMarkerLayer (use selectedId/tooltip).
- Pages own their texts (e.g. 「当前计划还没有点位。」) and overlap-browser state.
