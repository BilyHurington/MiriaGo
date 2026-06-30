import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/anitabi_image_url.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('removes Anitabi thumbnail plan from image URL', () {
    const thumbnailUrl =
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160';

    expect(
      anitabiFullResolutionImageUrl(thumbnailUrl),
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg',
    );
  });

  test('keeps non-Anitabi image URL untouched', () {
    const imageUrl = 'https://example.com/reference.jpg?plan=h160';

    expect(anitabiFullResolutionImageUrl(imageUrl), imageUrl);
  });

  test('builds Anitabi thumbnail URL from full image URL', () {
    const imageUrl =
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg';

    expect(
      anitabiThumbnailImageUrl(imageUrl),
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160',
    );
  });

  test('normalizes existing Anitabi thumbnail URL before rebuilding thumbnail', () {
    const thumbnailUrl =
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=w300';

    expect(
      anitabiThumbnailImageUrl(thumbnailUrl),
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160',
    );
  });

  test('keeps non-Anitabi thumbnail URL untouched', () {
    const imageUrl = 'https://example.com/reference.jpg?plan=h160';

    expect(anitabiThumbnailImageUrl(imageUrl), imageUrl);
  });

  test('recognizes mirror host when building full and thumbnail URLs', () {
    const mirrorThumbnail =
        'https://img-tc.anitabi.cn/points/115908/id.jpg?plan=w300';

    expect(
      anitabiFullResolutionImageUrl(mirrorThumbnail),
      'https://img-tc.anitabi.cn/points/115908/id.jpg',
    );
    expect(
      anitabiThumbnailImageUrl(mirrorThumbnail),
      'https://img-tc.anitabi.cn/points/115908/id.jpg?plan=h160',
    );
  });

  test('canonicalizes mirror URLs to official image host for storage', () {
    const mirrorUrl = 'https://img-tc.anitabi.cn/points/115908/id.jpg';

    expect(
      canonicalAnitabiImageUrl(mirrorUrl),
      'https://image.anitabi.cn/points/115908/id.jpg',
    );
  });

  test('resolves Anitabi image source only at runtime', () {
    const canonicalUrl = 'https://image.anitabi.cn/points/115908/id.jpg';

    expect(
      resolveAnitabiImageUrl(canonicalUrl, source: AnitabiImageSource.mirror),
      'https://img-tc.anitabi.cn/points/115908/id.jpg',
    );
    expect(candidateAnitabiImageUrls(canonicalUrl), [
      'https://image.anitabi.cn/points/115908/id.jpg',
      'https://img-tc.anitabi.cn/points/115908/id.jpg',
    ]);
  });
}
