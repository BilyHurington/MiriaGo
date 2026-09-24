import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/desktop/desktop_asset_data_url_cache.dart';
import 'package:miriago/desktop/desktop_asset_image.dart';

void main() {
  test('desktop asset paths are limited to safe relative assets entries', () {
    expect(
      isDesktopAssetPath('assets/imported_plan_assets/pkg/photo.jpg'),
      true,
    );
    expect(
      isDesktopAssetPath(r'assets\imported_plan_assets\pkg\photo.jpg'),
      true,
    );
    expect(isDesktopAssetPath('assets/reference_full/image.webp'), true);
    expect(
      normalizeDesktopAssetPath(r'assets\imported_plan_assets\pkg\photo.jpg'),
      'assets/imported_plan_assets/pkg/photo.jpg',
    );

    expect(isDesktopAssetPath(null), false);
    expect(isDesktopAssetPath(''), false);
    expect(isDesktopAssetPath('/assets/photo.jpg'), false);
    expect(isDesktopAssetPath('file:///tmp/photo.jpg'), false);
    expect(isDesktopAssetPath('assets/../photo.jpg'), false);
    expect(isDesktopAssetPath('assets//photo.jpg'), false);
    expect(isDesktopAssetPath(r'assets\photo.jpg'), true);
  });

  group('data URL cache', () {
    test('shares in-flight loads and never caches failures', () async {
      final cache = DesktopAssetDataUrlCache();
      var loads = 0;
      Future<String?> failing() async {
        loads++;
        throw StateError('ipc failed');
      }

      final first = cache.load('assets/a.jpg', failing);
      final second = cache.load('assets/a.jpg', failing);
      expect(identical(first, second), isTrue);
      await expectLater(first, throwsStateError);
      expect(cache.containsKey('assets/a.jpg'), isFalse);

      Future<String?> empty() async {
        loads++;
        return null;
      }

      expect(await cache.load('assets/a.jpg', empty), isNull);
      expect(cache.containsKey('assets/a.jpg'), isFalse);
      expect(
        await cache.load('assets/a.jpg', () async => 'data:ok'),
        'data:ok',
      );
      expect(await cache.load('assets/a.jpg', empty), 'data:ok');
      expect(loads, 2);
    });

    test('evicts least recently used entries by size and count', () async {
      final cache = DesktopAssetDataUrlCache(maxTotalSize: 10, maxEntries: 3);
      await cache.load('a', () async => 'aaaa');
      await cache.load('b', () async => 'bbbb');
      await cache.load('a', () async => 'unused'); // touch a
      await cache.load('c', () async => 'cccc'); // 12 > 10: evict b
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.totalSize, 8);

      await cache.load('d', () async => 'd');
      await cache.load('e', () async => 'e'); // 4 entries > 3: evict a
      expect(cache.containsKey('a'), isFalse);
      expect(cache.length, 3);

      await cache.load('huge', () async => 'x' * 11);
      expect(cache.containsKey('huge'), isFalse);
    });

    test('invalidation forces a reload after a write or delete', () async {
      final cache = DesktopAssetDataUrlCache();
      await cache.load('assets/a.jpg', () async => 'old');
      cache.invalidate('assets/a.jpg');
      expect(await cache.load('assets/a.jpg', () async => 'new'), 'new');

      final pending = cache.load('assets/b.jpg', () async => 'stale');
      cache.invalidate('assets/b.jpg');
      expect(await pending, 'stale');
      expect(cache.containsKey('assets/b.jpg'), isFalse);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.totalSize, 0);
    });
  });
}
