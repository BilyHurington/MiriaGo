import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/main.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

class _FailingSettingsRepository extends SamplePilgrimageRepository {
  var failSaves = true;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    if (failSaves) {
      throw StateError('disk full');
    }
    await super.saveAppSettings(settings);
  }
}

void main() {
  testWidgets('a failed settings save is reported and rolled back', (
    tester,
  ) async {
    final repository = _FailingSettingsRepository();
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    Switch backupSwitch() => tester.widget<Switch>(
      find.descendant(
        of: find
            .ancestor(of: find.text('照片备份'), matching: find.byType(Row))
            .first,
        matching: find.byType(Switch),
      ),
    );
    expect(backupSwitch().value, isTrue);

    backupSwitch().onChanged!(false);
    await tester.pumpAndSettle();
    expect(find.text('设置保存失败'), findsOneWidget);
    expect(backupSwitch().value, isTrue);
    expect(
      (await repository.loadAppSettings()).saveVisitPhotoToGallery,
      isTrue,
    );

    repository.failSaves = false;
    backupSwitch().onChanged!(false);
    await tester.pumpAndSettle();
    expect(backupSwitch().value, isFalse);
    expect(
      (await repository.loadAppSettings()).saveVisitPhotoToGallery,
      isFalse,
    );
  });
}
