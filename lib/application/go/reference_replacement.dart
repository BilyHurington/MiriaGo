import '../../data/user_reference_image_stub.dart'
    if (dart.library.io) '../../data/user_reference_image_io.dart';
import '../../plan/pilgrimage_models.dart';

export '../../data/user_reference_image_stub.dart'
    if (dart.library.io) '../../data/user_reference_image_io.dart'
    show StoredUserReferenceImage;

/// Result of [replacePointReference].
enum ReferenceReplaceOutcome {
  /// Stored and saved: toast 「已替换参考图」.
  replaced,

  /// Storing or saving failed: toast 「参考图替换失败，请稍后重试。」.
  failed,

  /// The detail closed before the save: the copy was dropped, toast
  /// 「参考图替换已取消」.
  cancelled,
}

/// Toast texts of the flow (old `PointDetailSheet._replaceReferenceImage`).
abstract final class ReferenceReplaceTexts {
  static const running = '正在替换参考图...';
  static const replaced = '已替换参考图';
  static const failed = '参考图替换失败，请稍后重试。';
  static const cancelled = '参考图替换已取消';

  static String forOutcome(ReferenceReplaceOutcome outcome) =>
      switch (outcome) {
        ReferenceReplaceOutcome.replaced => replaced,
        ReferenceReplaceOutcome.failed => failed,
        ReferenceReplaceOutcome.cancelled => cancelled,
      };
}

typedef StoreUserReference =
    Future<StoredUserReferenceImage?> Function({
      required String sourcePath,
      required String pointId,
    });
typedef DeleteUserReference =
    Future<void> Function(StoredUserReferenceImage image);

/// The point with [image] as its reference (remote URL cleared), as the old
/// callers passed to `updatePoint`.
PilgrimagePoint pointWithUserReference(
  PilgrimagePoint point,
  StoredUserReferenceImage image,
) => point.copyWith(
  referenceImageUrl: null,
  referenceThumbnailPath: image.thumbnailPath,
  referenceFullImagePath: image.fullImagePath,
);

/// Stores the picked image at [pickedPath] as [point]'s reference and saves
/// it with [save]. Ported line by line from the old sheet:
/// - a failed store → [ReferenceReplaceOutcome.failed];
/// - [isStillOpen] false after storing (the detail closed before anything
///   was committed) → the copy is deleted, [ReferenceReplaceOutcome.cancelled];
/// - a failed save keeps the stored image (the save may have committed
///   before the error surfaced) → [ReferenceReplaceOutcome.failed].
Future<ReferenceReplaceOutcome> replacePointReference({
  required PilgrimagePoint point,
  required String pickedPath,
  required bool Function() isStillOpen,
  required Future<void> Function(PilgrimagePoint updated) save,
  StoreUserReference store = storeUserReferenceImage,
  DeleteUserReference delete = deleteStoredUserReferenceImage,
}) async {
  StoredUserReferenceImage? stored;
  try {
    stored = await store(sourcePath: pickedPath, pointId: point.id);
  } catch (_) {
    return ReferenceReplaceOutcome.failed;
  }
  if (stored == null) return ReferenceReplaceOutcome.failed;
  if (!isStillOpen()) {
    try {
      await delete(stored);
    } catch (_) {
      // Best effort: an orphaned copy is reclaimed by the storage sweep.
    }
    return ReferenceReplaceOutcome.cancelled;
  }
  try {
    await save(pointWithUserReference(point, stored));
  } catch (_) {
    return ReferenceReplaceOutcome.failed;
  }
  try {
    // Desktop: finalise the staged copy now that the plan references it
    // (no-op on native platforms).
    await stored.retain();
  } catch (_) {
    // The saved paths stay valid; finalising is retried by later writes.
  }
  return ReferenceReplaceOutcome.replaced;
}
