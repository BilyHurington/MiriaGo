import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/image_bytes.dart';
import 'package:miriago/data/reference_cache_naming.dart';

void main() {
  const url = 'https://image.anitabi.cn/points/115908/abc.jpg?plan=h360';

  test('cache names use a long hash and keep the extension', () {
    final name = referenceCacheFileName(url);
    expect(name, matches(RegExp(r'^[0-9a-f]{20}\.jpg$')));
    expect(referenceCacheFileName('https://x.test/a'), endsWith('.jpg'));
    expect(referenceCacheFileName('https://x.test/a.webp'), endsWith('.webp'));
  });

  test('matches current names exactly and legacy names by old key', () {
    final legacyKey = legacyReferenceCacheKey(url);
    expect(
      referenceCachePathMatchesUrl(
        '/c/reference_full/${referenceCacheFileName(url)}',
        url,
      ),
      isTrue,
    );
    expect(referenceCachePathMatchesUrl('/c/$legacyKey.jpg', url), isTrue);
    expect(
      referenceCachePathMatchesUrl('/c/old-point_$legacyKey.jpg', url),
      isTrue,
    );
    expect(
      referenceCachePathMatchesUrl('/c/$legacyKey.jpg.123.part', url),
      isFalse,
    );
    expect(
      referenceCachePathMatchesUrl(
        '/c/${referenceCacheFileName('https://other.test/b.jpg')}',
        url,
      ),
      isFalse,
    );
  });

  test('detects images cut short before their end marker', () {
    expect(
      looksCompleteImageBytes([0xFF, 0xD8, 0xFF, 0xDA, 0, 1, 0xFF, 0xD9]),
      isTrue,
    );
    // Data appended after the image (motion photos) is fine.
    expect(
      looksCompleteImageBytes([
        0xFF, 0xD8, 0xFF, 0xDA, 1, 0xFF, 0xD9, //
        ...List.filled(100000, 7),
      ]),
      isTrue,
    );
    expect(looksCompleteImageBytes([0xFF, 0xD8, 0xFF, 0xDA, 1, 2, 3]), isFalse);
    expect(
      looksCompleteImageBytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]),
      isFalse,
    );
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    expect(
      looksCompleteImageBytes([
        ...png,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4E,
        0x44,
        1,
        2,
        3,
        4,
      ]),
      isTrue,
    );
    expect(looksCompleteImageBytes([...png, 0, 0, 0, 13]), isFalse);
    final webpHeader = [
      0x52,
      0x49,
      0x46,
      0x46,
      8,
      0,
      0,
      0,
      0x57,
      0x45,
      0x42,
      0x50,
    ];
    expect(looksCompleteImageBytes([...webpHeader, 0, 0, 0, 0]), isTrue);
    expect(looksCompleteImageBytes([...webpHeader, 0, 0]), isFalse);
  });

  test('legacy matching never claims current-scheme names', () {
    final other = referenceCacheFileName('https://other.test/b.jpg');
    expect(isLegacyReferenceCacheName(other, url), isFalse);
    expect(
      isLegacyReferenceCacheName('x${legacyReferenceCacheKey(url)}.jpg', url),
      isFalse,
    );
  });
}
