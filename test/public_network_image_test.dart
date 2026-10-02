import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/widgets/public_network_image.dart';

void main() {
  test('the resized image is its own cache key, so failures evict it', () {
    final provider = publicNetworkImage('https://a.test/x.jpg', cacheWidth: 64);
    expect(provider, isA<PublicNetworkImage>());
    expect(
      provider,
      const PublicNetworkImage('https://a.test/x.jpg', cacheWidth: 64),
    );
    expect(
      provider,
      isNot(const PublicNetworkImage('https://a.test/x.jpg', cacheWidth: 128)),
    );
    expect(
      publicNetworkImage('https://a.test/x.jpg'),
      const PublicNetworkImage('https://a.test/x.jpg'),
    );
  });
}
