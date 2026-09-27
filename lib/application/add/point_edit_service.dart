import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../data/user_reference_image_stub.dart'
    if (dart.library.io) '../../data/user_reference_image_io.dart';
import '../../desktop/desktop_asset_image.dart';
import '../../plan/coordinate_parser.dart';
import '../../plan/pending_reference_lifecycle.dart';
import '../../plan/pilgrimage_models.dart';
import '../plan_session.dart';
import 'add_dependencies.dart';
import 'work_service.dart';

export '../../data/user_reference_image_stub.dart'
    if (dart.library.io) '../../data/user_reference_image_io.dart'
    show StoredUserReferenceImage;

/// Reference label of points created by hand (old quick form).
const String kManualReferenceLabel = '手动录入';

/// Fallback centre for map picking when nothing else is known (old app).
const LatLng kPointFormFallbackCenter = LatLng(35, 135);

// ---------------------------------------------------------------------------
// Coordinates
// ---------------------------------------------------------------------------

/// Validates one coordinate field of the merged point form (DESIGN Δ3):
/// coordinates are either filled as a pair or marked 「坐标待补充」.
///
/// Strings are the old app's: 「请同时填写纬度/经度」, 「纬度/经度格式不正确」,
/// 「请填写纬度/经度」 and 「请输入有效坐标」 (the reserved pending position).
String? validateCoordinateField(
  String value, {
  required String other,
  required bool latitude,
  required bool pending,
}) {
  if (pending) return null;
  final text = value.trim();
  final otherText = other.trim();
  if (text.isEmpty) {
    if (otherText.isEmpty) return latitude ? '请填写纬度' : '请填写经度';
    return latitude ? '请同时填写纬度' : '请同时填写经度';
  }
  final parsed = parseCoordinateComponent(text, latitude: latitude);
  if (parsed == null) return latitude ? '纬度格式不正确' : '经度格式不正确';
  if (latitude) {
    final lng = parseCoordinateComponent(otherText, latitude: false);
    if (lng != null && PilgrimagePoint.isPendingPosition(LatLng(parsed, lng))) {
      return '请输入有效坐标';
    }
  }
  return null;
}

/// The position typed into the form, or null when incomplete / invalid.
LatLng? parseCoordinateInput(String latitude, String longitude) {
  final lat = parseCoordinateComponent(latitude, latitude: true);
  final lng = parseCoordinateComponent(longitude, latitude: false);
  if (lat == null || lng == null) return null;
  final position = LatLng(lat, lng);
  return PilgrimagePoint.isPendingPosition(position) ? null : position;
}

/// Formats a coordinate for the form fields (old: 6 decimals).
String formatCoordinateComponent(double value) => value.toStringAsFixed(6);

/// Average position of the plan's positioned points, or (35, 135).
LatLng planCenterFor(PilgrimagePlan plan) {
  final positioned = plan.points
      .where((point) => point.hasCoordinate)
      .toList(growable: false);
  if (positioned.isEmpty) return kPointFormFallbackCenter;
  final latitude =
      positioned.map((p) => p.position.latitude).reduce((a, b) => a + b) /
      positioned.length;
  final longitude =
      positioned.map((p) => p.position.longitude).reduce((a, b) => a + b) /
      positioned.length;
  return LatLng(latitude, longitude);
}

/// Result of reading a coordinate from the clipboard.
enum ClipboardCoordinateStatus { filled, unreadable, empty }

/// Reads a coordinate from the clipboard (old
/// `_pasteCoordinateFromClipboardInto`). The notices are the old toasts.
Future<({LatLng? position, AddNotice notice})> readClipboardCoordinate({
  Future<LatLng?> Function()? reader,
}) async {
  LatLng? coordinate;
  try {
    coordinate = await (reader ?? parseClipboardCoordinate)();
  } on Object {
    return (
      position: null,
      notice: const AddNotice(AddNoticeKind.warning, '无法读取剪贴板。'),
    );
  }
  if (coordinate == null) {
    return (
      position: null,
      notice: const AddNotice(AddNoticeKind.warning, '剪贴板中没有有效坐标。'),
    );
  }
  return (
    position: coordinate,
    notice: const AddNotice(AddNoticeKind.success, '已填入坐标。'),
  );
}

// ---------------------------------------------------------------------------
// Reference images
// ---------------------------------------------------------------------------

/// A newly picked reference image that is not saved yet.
class PendingReferenceImage {
  const PendingReferenceImage(this.stored, this.thumbnailBytes);

  final StoredUserReferenceImage stored;

  /// Snapshot of the thumbnail, so the preview survives draft cleanup.
  final Uint8List thumbnailBytes;
}

/// File operations of the reference-image lifecycle (swappable in tests).
class ReferenceImageStore {
  const ReferenceImageStore({
    this.pickPath = _pickFromGallery,
    this.store = _store,
    this.delete = deleteStoredUserReferenceImage,
    this.readThumbnail = _readThumbnail,
  });

  /// Replaces the default store in widget tests.
  @visibleForTesting
  static ReferenceImageStore? debugOverride;

  /// Opens the gallery; null when cancelled.
  final Future<String?> Function() pickPath;
  final Future<StoredUserReferenceImage?> Function(
    String sourcePath,
    String pointId,
  )
  store;
  final Future<void> Function(StoredUserReferenceImage image) delete;
  final Future<Uint8List> Function(StoredUserReferenceImage image)
  readThumbnail;

  static Future<String?> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked?.path;
  }

  static Future<StoredUserReferenceImage?> _store(
    String sourcePath,
    String pointId,
  ) => storeUserReferenceImage(sourcePath: sourcePath, pointId: pointId);

  static Future<Uint8List> _readThumbnail(
    StoredUserReferenceImage stored,
  ) async {
    if (isDesktopAssetPath(stored.thumbnailPath)) {
      final dataUrl = await loadDesktopAssetDataUrl(stored.thumbnailPath);
      if (dataUrl == null) {
        throw StateError('Reference thumbnail unavailable');
      }
      return base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
    }
    return XFile(stored.thumbnailPath).readAsBytes();
  }
}

// ---------------------------------------------------------------------------
// Form values
// ---------------------------------------------------------------------------

/// Values of the merged point form.
class PointFormValues {
  const PointFormValues({
    required this.name,
    required this.coordinatesPending,
    this.work,
    this.newWorkTitle = '',
    this.newWorkSubtitle = '',
    this.newWorkCity = '',
    this.latitude = '',
    this.longitude = '',
    this.subtitle = '',
    this.episodeLabel = '',
    this.referenceLabel = '',
    this.note = '',
  });

  /// Selected work; null → create a manual work from the `newWork*` fields.
  final PilgrimageWork? work;
  final String newWorkTitle;
  final String newWorkSubtitle;
  final String newWorkCity;
  final String name;
  final String latitude;
  final String longitude;
  final bool coordinatesPending;
  final String subtitle;
  final String episodeLabel;
  final String referenceLabel;
  final String note;

  /// Position to store: the typed pair, or the pending position.
  LatLng get position {
    if (coordinatesPending) return PilgrimagePoint.pendingPosition;
    return parseCoordinateInput(latitude, longitude) ??
        PilgrimagePoint.pendingPosition;
  }
}

/// Outcome of [PointEditSession.save].
enum PointSaveStatus {
  /// Saved; the page closes with `true`.
  saved,

  /// Nothing happened (busy, locked or already saved).
  ignored,

  /// Save failed; the user may retry.
  failed,

  /// A new point may or may not have been written: the save button is
  /// locked (old 「保存结果未确认」 behaviour).
  uncertain,
}

class PointSaveResult {
  const PointSaveResult(this.status, [this.notice]);

  final PointSaveStatus status;
  final AddNotice? notice;
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

/// Create / edit one point (old `_ManualPointFormScreenState`, merged with
/// the quick form per DESIGN Δ3). Owns the pending reference image
/// lifecycle and the uncertain-save lock.
class PointEditSession extends ChangeNotifier {
  PointEditSession({
    required this.session,
    this.editingPoint,
    ReferenceImageStore? imageStore,
    DateTime Function()? clock,
  }) : imageStore =
           imageStore ??
           ReferenceImageStore.debugOverride ??
           const ReferenceImageStore(),
       _clock = clock ?? DateTime.now {
    draftPointId = 'manual-${_clock().microsecondsSinceEpoch}';
    _pending = PendingReferenceLifecycle<PendingReferenceImage>(
      delete: (image) => this.imageStore.delete(image.stored),
      onRetain: (image) => image.stored.retain(),
    );
  }

  final PlanSession session;
  final PilgrimagePoint? editingPoint;
  final ReferenceImageStore imageStore;
  final DateTime Function() _clock;

  late final String draftPointId;
  late final PendingReferenceLifecycle<PendingReferenceImage> _pending;

  bool _didSave = false;
  bool _isExiting = false;
  bool _uncertainNewPointSave = false;
  bool _disposed = false;

  bool get isEditing => editingPoint != null;
  PendingReferenceImage? get pendingImage => _pending.current;
  bool get isSaving => _pending.isSaving;
  bool get isPicking => _pending.isBusy && !_pending.isSaving;
  bool get didSave => _didSave;
  bool get isDisposed => _disposed;

  /// Blocks input, leaving and further saves (old `_isBusy`).
  bool get isBusy => _pending.isBusy || _didSave || _isExiting;

  /// After an uncertain new-point save the save button stays disabled.
  bool get isSaveLocked => _uncertainNewPointSave;

  /// The point id used for stored reference files.
  String get pointId => editingPoint?.id ?? draftPointId;

  /// Works offered by the form: the plan's works, plus the edited point's
  /// work when it is not in the plan any more.
  List<PilgrimageWork> workOptions() {
    final works = [...session.plan.works];
    final editingWork = editingPoint?.work;
    if (editingWork != null && !works.any((w) => w.id == editingWork.id)) {
      works.add(editingWork);
    }
    return works;
  }

  /// Initially selected work (old initState).
  PilgrimageWork? initialWork() {
    final editing = editingPoint;
    final works = session.plan.works;
    if (editing == null) return works.firstOrNull;
    return works.firstWhere(
      (work) => work.id == editing.work.id,
      orElse: () => editing.work,
    );
  }

  /// Marks the page as leaving (idle pop): later callbacks are ignored but
  /// the draft image is kept until [dispose] so the pop transition can
  /// still show it.
  bool requestExit() {
    if (isBusy) return false;
    _isExiting = true;
    _notify();
    return true;
  }

  void markExiting() => _isExiting = true;

  /// Picks and stores a new reference image. Returns an error notice when
  /// reading failed, null otherwise (also when cancelled).
  Future<AddNotice?> pickReferenceImage() async {
    if (isBusy || _disposed) return null;
    final selection = _pending.select(() async {
      final path = await imageStore.pickPath();
      if (path == null || _pending.isDisposed) return null;
      final stored = await imageStore.store(path, pointId);
      if (stored == null) throw StateError('Reference image unavailable');
      try {
        // Keep the preview independent of draft-file cleanup, including
        // reads that would otherwise outlive the route's reverse transition.
        final bytes = await imageStore.readThumbnail(stored);
        return PendingReferenceImage(stored, bytes);
      } catch (_) {
        await imageStore.delete(stored);
        rethrow;
      }
    });
    _notify();
    try {
      await selection;
      return null;
    } catch (_) {
      if (_disposed) return null;
      return const AddNotice(AddNoticeKind.error, '参考图读取失败，请重新选择。');
    } finally {
      _notify();
    }
  }

  /// Removes the newly picked (unsaved) image.
  void removeReferenceImage() {
    if (isBusy || _disposed) return;
    _pending.remove();
    _notify();
  }

  /// Builds the point that [save] would write.
  PilgrimagePoint buildPoint(PointFormValues values) {
    final now = _clock();
    final editing = editingPoint;
    final work =
        values.work ??
        buildManualWork(
          title: values.newWorkTitle,
          subtitle: values.newWorkSubtitle,
          city: values.newWorkCity,
          planArea: session.plan.area,
          now: now,
        );
    final stored = _pending.current?.stored;
    final noteText = values.note.trim();
    final referenceText = values.referenceLabel.trim();
    final referenceLabel = referenceText.isEmpty
        ? kManualReferenceLabel
        : referenceText;
    if (editing == null) {
      return PilgrimagePoint(
        id: draftPointId,
        work: work,
        name: values.name.trim(),
        subtitle: values.subtitle.trim(),
        position: values.position,
        episodeLabel: values.episodeLabel.trim(),
        referenceLabel: referenceLabel,
        source: PointSource.manual,
        referenceThumbnailPath: stored?.thumbnailPath,
        referenceFullImagePath: stored?.fullImagePath,
        note: noteText.isEmpty ? null : noteText,
      );
    }
    return editing.copyWith(
      work: work,
      name: values.name.trim(),
      subtitle: values.subtitle.trim(),
      position: values.position,
      episodeLabel: values.episodeLabel.trim(),
      referenceLabel: referenceLabel,
      referenceThumbnailPath:
          stored?.thumbnailPath ?? editing.referenceThumbnailPath,
      referenceFullImagePath:
          stored?.fullImagePath ?? editing.referenceFullImagePath,
      referenceImageUrl: stored == null ? editing.referenceImageUrl : null,
      note: noteText.isEmpty ? null : noteText,
    );
  }

  /// Saves the point (old `_savePoint`): add for a new point, update when
  /// editing. Validation is the caller's job.
  Future<PointSaveResult> save(PointFormValues values) async {
    if (isBusy || _disposed || _uncertainNewPointSave) {
      return const PointSaveResult(PointSaveStatus.ignored);
    }
    if (!_pending.beginSave()) {
      return const PointSaveResult(PointSaveStatus.ignored);
    }
    _notify();

    var persistenceStarted = false;
    try {
      final point = buildPoint(values);
      _pending.beginPersistence();
      persistenceStarted = true;
      final editing = editingPoint;
      await session.mutate(
        (repository, planId) => editing == null
            ? repository.addPointToPlan(planId: planId, point: point)
            : repository.updatePointInPlan(planId: planId, point: point),
      );
      _pending.finishPersistence(succeeded: true);
      _didSave = true;
      return const PointSaveResult(PointSaveStatus.saved);
    } catch (error) {
      debugPrint('Point save failed: $error');
      _pending.finishPersistence(succeeded: false);
      if (persistenceStarted && !isEditing) {
        _uncertainNewPointSave = true;
      }
      return _uncertainNewPointSave
          ? const PointSaveResult(
              PointSaveStatus.uncertain,
              AddNotice(AddNoticeKind.error, '保存结果未确认，请返回并刷新计划，检查点位是否已添加。'),
            )
          : const PointSaveResult(
              PointSaveStatus.failed,
              AddNotice(AddNoticeKind.error, '点位保存失败，请稍后重试。'),
            );
    } finally {
      _pending.endSave();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.dispose();
    super.dispose();
  }
}
