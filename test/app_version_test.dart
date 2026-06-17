import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_version.dart';

void main() {
  test('formats app version with build number', () {
    expect(
      formatAppVersionLabel(version: '1.1.2', buildNumber: '13'),
      '1.1.2+13',
    );
  });

  test('formats app version without empty build number', () {
    expect(formatAppVersionLabel(version: '1.1.2', buildNumber: ''), '1.1.2');
  });
}
