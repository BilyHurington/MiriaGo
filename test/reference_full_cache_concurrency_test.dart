import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/reference_full_cache_runner.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final limit in [1, 10, 30, 50, 0]) {
    test(
      'full cache honors concurrency $limit and reports mixed results',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'miriago_full_concurrency_',
        );
        final previous = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(directory.path);
        final hold = Completer<void>();
        addTearDown(() async {
          if (!hold.isCompleted) hold.complete();
          PathProviderPlatform.instance = previous;
          await directory.delete(recursive: true);
        });
        const count = 35;
        final plan = samplePilgrimagePlan.copyWith(
          points: [
            for (var i = 0; i < count; i++)
              samplePilgrimagePlan.points.first.copyWith(
                id: 'concurrent-$i',
                source: PointSource.anitabi,
                referenceImageUrl: 'https://example.com/$i.jpg',
                referenceFullImagePath: null,
                referenceThumbnailPath: null,
              ),
          ],
        );
        final repository = SamplePilgrimageRepository(plans: [plan]);
        final started = Completer<void>();
        var active = 0;
        var peak = 0;
        var requests = 0;
        final expected = limit.clamp(1, count);
        final progress = <ReferenceFullCacheProgress>[];
        final run = http.runWithClient(
          () => cacheFullReferenceImages(
            plan: plan,
            repository: repository,
            maxConcurrent: limit,
            onPlanUpdated: (_) {},
            onProgress: progress.add,
          ),
          () => MockClient((request) async {
            requests++;
            active++;
            if (active > peak) peak = active;
            if (active == expected && !started.isCompleted) started.complete();
            await hold.future;
            active--;
            return request.url.path == '/0.jpg'
                ? http.Response('failure', 500)
                : http.Response.bytes([0xFF, 0xD8, 0xFF, 0xD9], 200);
          }),
        );
        try {
          await started.future.timeout(const Duration(seconds: 5));
          expect(peak, expected);
        } finally {
          hold.complete();
        }
        final result = await run;
        expect(peak, expected);
        expect(requests, count);
        expect(progress.last.done, isTrue);
        expect(progress.last.processed, count);
        expect(progress.last.succeeded, count - 1);
        expect(progress.last.failed, 1);
        expect(
          progress.map((p) => p.processed),
          orderedEquals([0, for (var i = 1; i <= count; i++) i, count]),
        );
        expect(result.points.first.referenceFullImagePath, isNull);
        for (final point in result.points.skip(1)) {
          expect(await File(point.referenceFullImagePath!).exists(), isTrue);
        }
        expect(
          (await repository.loadActivePlan())
              .points
              .last
              .referenceFullImagePath,
          result.points.last.referenceFullImagePath,
        );
      },
    );
  }
}
