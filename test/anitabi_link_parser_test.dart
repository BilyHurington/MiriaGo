import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/anitabi_link_parser.dart';

void main() {
  test('parses Anitabi point links with bangumi and point IDs', () {
    final link = parseAnitabiImportLink(
      'https://www.anitabi.cn/map?bangumiId=8290&pid=qdmnf6iqj&z=16',
    );

    expect(link, isNotNull);
    expect(link!.bangumiId, 8290);
    expect(link.pointId, 'qdmnf6iqj');
  });

  test('parses Anitabi bangumi-only links', () {
    final link = parseAnitabiImportLink('bangumiId=428735&c=139,35');

    expect(link, isNotNull);
    expect(link!.bangumiId, 428735);
    expect(link.pointId, isNull);
  });

  test('keeps point-only links invalid for direct import scope', () {
    final link = parseAnitabiImportLink(
      'https://www.anitabi.cn/map?pid=qdmnf6iqj',
    );

    expect(link, isNotNull);
    expect(link!.bangumiId, isNull);
    expect(link.pointId, 'qdmnf6iqj');
  });

  test('rejects unrelated text', () {
    expect(parseAnitabiImportLink('qdmnf6iqj'), isNull);
    expect(parseAnitabiImportLink('hello world'), isNull);
  });
}
