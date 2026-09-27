import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/go/reference_replacement.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const _point = PilgrimagePoint(
  id: 'p1',
  work: PilgrimageWork(
    id: 'w',
    title: 'w',
    subtitle: '',
    city: '',
    source: WorkSource.manual,
  ),
  name: '宇治橋',
  subtitle: '',
  position: LatLng(34.89, 135.80),
  episodeLabel: '',
  referenceLabel: 'Anitabi',
  source: PointSource.anitabi,
  referenceImageUrl: 'https://image.anitabi.cn/points/1/a.jpg',
);

const _stored = StoredUserReferenceImage(
  thumbnailPath: '/refs/thumb.jpg',
  fullImagePath: '/refs/full.jpg',
);

void main() {
  test('texts are the old ones', () {
    expect(ReferenceReplaceTexts.running, '正在替换参考图...');
    expect(ReferenceReplaceTexts.replaced, '已替换参考图');
    expect(ReferenceReplaceTexts.failed, '参考图替换失败，请稍后重试。');
    expect(ReferenceReplaceTexts.cancelled, '参考图替换已取消');
  });

  test('a stored image is saved with the remote URL cleared', () async {
    PilgrimagePoint? saved;
    final outcome = await replacePointReference(
      point: _point,
      pickedPath: '/picked.jpg',
      isStillOpen: () => true,
      save: (point) async => saved = point,
      store: ({required sourcePath, required pointId}) async {
        expect(sourcePath, '/picked.jpg');
        expect(pointId, 'p1');
        return _stored;
      },
      delete: (_) async => fail('must not delete'),
    );
    expect(outcome, ReferenceReplaceOutcome.replaced);
    expect(saved!.referenceImageUrl, isNull);
    expect(saved!.referenceThumbnailPath, '/refs/thumb.jpg');
    expect(saved!.referenceFullImagePath, '/refs/full.jpg');
  });

  test('a failed or empty store reports failure', () async {
    for (final store in <StoreUserReference>[
      ({required sourcePath, required pointId}) async => null,
      ({required sourcePath, required pointId}) async => throw StateError('x'),
    ]) {
      final outcome = await replacePointReference(
        point: _point,
        pickedPath: '/picked.jpg',
        isStillOpen: () => true,
        save: (_) async => fail('must not save'),
        store: store,
      );
      expect(outcome, ReferenceReplaceOutcome.failed);
    }
  });

  test('closing before the save drops the stored copy', () async {
    StoredUserReferenceImage? deleted;
    final outcome = await replacePointReference(
      point: _point,
      pickedPath: '/picked.jpg',
      isStillOpen: () => false,
      save: (_) async => fail('must not save'),
      store: ({required sourcePath, required pointId}) async => _stored,
      delete: (image) async => deleted = image,
    );
    expect(outcome, ReferenceReplaceOutcome.cancelled);
    expect(deleted, same(_stored));
  });

  test('a failed save keeps the stored image', () async {
    var deleted = false;
    final outcome = await replacePointReference(
      point: _point,
      pickedPath: '/picked.jpg',
      isStillOpen: () => true,
      save: (_) async => throw StateError('save'),
      store: ({required sourcePath, required pointId}) async => _stored,
      delete: (_) async => deleted = true,
    );
    expect(outcome, ReferenceReplaceOutcome.failed);
    expect(deleted, isFalse);
  });
}
