import 'package:flutter_test/flutter_test.dart';
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
}
