import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('maps Bangumi subject type codes to labels', () {
    expect(BangumiSubjectType.fromCode(2), BangumiSubjectType.anime);
    expect(BangumiSubjectType.fromCode(4), BangumiSubjectType.game);
    expect(BangumiSubjectType.fromCode(999), isNull);
  });

  test('restores subject type from persisted work metadata', () {
    const work = PilgrimageWork(
      id: 'bangumi-5418',
      bangumiId: 5418,
      title: '魔法使之夜',
      subtitle: '魔法使いの夜',
      city: '游戏 / 2012-04-12',
      source: WorkSource.bangumi,
    );

    expect(work.displayBangumiSubjectType, BangumiSubjectType.game);
  });
}
