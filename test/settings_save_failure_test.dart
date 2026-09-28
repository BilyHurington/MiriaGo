import 'dart:async';

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

class _GatedSettingsRepository extends SamplePilgrimageRepository {
  final pending = <Completer<void>>[];

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    final gate = Completer<void>();
    pending.add(gate);
    await gate.future;
    await super.saveAppSettings(settings);
  }
}

Switch _switchFor(WidgetTester tester, String title) => tester.widget<Switch>(
  find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  ),
);

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

  testWidgets('several failed saves in a row show the stored settings', (
    tester,
  ) async {
    final repository = _GatedSettingsRepository();
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    _switchFor(tester, '照片备份').onChanged!(false);
    await tester.pump();
    _switchFor(tester, '自动保存对比图').onChanged!(true);
    await tester.pump();
    expect(repository.pending, hasLength(2));

    for (final gate in repository.pending) {
      gate.completeError(StateError('disk full'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(_switchFor(tester, '照片备份').value, isTrue);
    expect(_switchFor(tester, '自动保存对比图').value, isFalse);
  });
}
