import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/data/anitabi_image_url.dart';

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
}
