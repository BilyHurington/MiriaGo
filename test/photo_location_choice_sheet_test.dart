import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/camera_reference/photo_location_choice_sheet.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  testWidgets(
    'photo location sheet keeps recommend badge without preselecting',
    (tester) async {
      PhotoLocationStrategy? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      selected =
                          await showModalBottomSheet<PhotoLocationStrategy>(
                            context: context,
                            builder: (_) => const PhotoLocationChoiceSheet(),
                          );
                    },
                    child: const Text('询问定位'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('询问定位'));
      await tester.pumpAndSettle();

      expect(find.text('是否在巡礼照片中记录定位？'), findsOneWidget);
      expect(find.text('以后可以在“拍摄设置”中修改。'), findsOneWidget);
      expect(find.text('不会使用点位坐标代替实际定位。'), findsOneWidget);
      expect(find.text('确认记录时获取定位'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.textContaining('（推荐）'), findsNothing);

      final confirmTile = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('photo-location-choice-confirm')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(confirmTile.color, AppColors.surface);

      await tester.tap(
        find.byKey(const ValueKey('photo-location-choice-recent')),
      );
      await tester.pumpAndSettle();

      expect(selected, PhotoLocationStrategy.useRecentLocation);
    },
  );
}
